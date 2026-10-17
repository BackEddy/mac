// Backeddy — configurar o Time Machine para fazer backup num Backeddy Server da rede, sem os Ajustes do Sistema
import SwiftUI
import AppKit

struct FoundServer: Identifiable, Equatable, Sendable {
    var id: String { host }
    let name: String    // "Backup da Casa"
    let host: String    // "backup-da-casa.local"
}

/// Procura Backeddy Servers na rede (Bonjour _backeddy._tcp, anunciado pelo próprio servidor)
final class ServerBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var pending: [NetService] = []
    var onFound: (FoundServer) -> Void = { _ in }
    var onLost: (String) -> Void = { _ in }

    func start() {
        browser.delegate = self
        browser.searchForServices(ofType: "_backeddy._tcp.", inDomain: "local.")
    }
    func stop() { browser.stop(); pending.forEach { $0.stop() }; pending = [] }

    func netServiceBrowser(_ b: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        pending.append(service)
        service.delegate = self
        service.resolve(withTimeout: 10)
    }
    func netServiceBrowser(_ b: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        onLost(service.name)
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard var host = sender.hostName else { return }
        if host.hasSuffix(".") { host.removeLast() }
        onFound(FoundServer(name: sender.name, host: host))
    }
}

/// Destinos de backup que o Time Machine já usa
func tmDestinations() -> [[String: Any]] {
    let r = sh("/usr/bin/tmutil", ["destinationinfo", "-X"])
    guard let data = r.out.data(using: .utf8),
          let obj = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [] }
    return obj["Destinations"] as? [[String: Any]] ?? []
}

@MainActor
final class TMSetupModel: ObservableObject {
    enum Phase: Equatable { case search, password, existing, working, done, failed(String) }
    @Published var phase: Phase = .search
    @Published var servers: [FoundServer] = []
    @Published var selected: FoundServer?
    @Published var password = ""
    @Published var checking = false
    @Published var passwordError: String?
    @Published var otherDestinations: [String] = []
    @Published var searchedLong = false
    private var browser: ServerBrowser?

    func start() {
        phase = .search; servers = []; selected = nil; password = ""; passwordError = nil; searchedLong = false
        let b = ServerBrowser()
        b.onFound = { [weak self] s in
            DispatchQueue.main.async {
                guard let self else { return }
                if !self.servers.contains(s) { self.servers.append(s) }
                if self.selected == nil, self.servers.count == 1 { self.selected = s }
            }
        }
        b.onLost = { [weak self] name in
            DispatchQueue.main.async { self?.servers.removeAll { $0.name == name } }
        }
        b.start(); browser = b
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.searchedLong = true }
    }
    func stop() { browser?.stop(); browser = nil }

    /// Confere a senha no próprio servidor (o painel usa a mesma senha do Time Machine)
    func checkPassword() {
        guard let s = selected, !password.isEmpty else { return }
        checking = true; passwordError = nil
        Task {
            defer { checking = false }
            var req = URLRequest(url: URL(string: "http://\(s.host)/api/login")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["password": password])
            req.timeoutInterval = 15
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
                case 200..<300:
                    ServerModel.shared.remember(host: s.host, name: s.name, password: password)
                    afterPassword()
                case 401: passwordError = L("tmWrongPassword")
                case 429: passwordError = L("tmTooMany")
                case let c: passwordError = Lf("tmServerError", "\(c)")
                }
            } catch {
                passwordError = L("tmUnreachable")
            }
        }
    }

    private func afterPassword() {
        guard let s = selected else { return }
        let slug = s.host.replacingOccurrences(of: ".local", with: "")
        Task {
            let dests = await Task.detached { tmDestinations() }.value
            func describe(_ d: [String: Any]) -> String { (d["Name"] as? String) ?? (d["URL"] as? String) ?? "?" }
            // já configurado com este servidor?
            if dests.contains(where: { d in d.values.contains { ($0 as? String)?.localizedCaseInsensitiveContains(slug) == true } }) {
                configure(replace: false, alreadyThere: true); return
            }
            otherDestinations = dests.map(describe)
            if otherDestinations.isEmpty { configure(replace: true) } else { phase = .existing }
        }
    }

    /// Aponta o Time Machine para o servidor, liga o backup automático e começa o primeiro backup
    func configure(replace: Bool, alreadyThere: Bool = false) {
        guard let s = selected else { return }
        if alreadyThere { phase = .done; return }
        phase = .working
        // a senha vai dentro do endereço, codificada: nada de aspas ou espaços para o shell interpretar
        let enc = password.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? password
        let url = "smb://backeddy:\(enc)@\(s.host)/TimeMachine"
        let cmd = "/usr/bin/tmutil setdestination \(replace ? "" : "-a ")'\(url)' && /usr/bin/tmutil enable && /usr/bin/tmutil startbackup"
        // dá tempo de a tela mostrar "Configurando…" antes da janela de senha do macOS
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            switch runAdmin(cmd) {
            case .ok: password = ""; phase = .done
            case .cancelled: phase = otherDestinations.isEmpty ? .password : .existing
            case .failed(let msg):
                let clean = msg.replacingOccurrences(of: enc, with: "•••")
                let low = clean.lowercased()
                phase = .failed(low.contains("full disk access") || low.contains("acesso total") || low.contains("not permitted")
                                ? L("tmNeedFDA") + "\n\n" + clean : clean)
            }
        }
    }
}

struct TMSetupView: View {
    @StateObject private var t = TMSetupModel()
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath").font(.system(size: 30)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("tmTitle")).font(.title3.weight(.semibold))
                    Text(L("tmSubtitle")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            switch t.phase {
            case .search: searchStep
            case .password: passwordStep
            case .existing: existingStep
            case .working:
                HStack(spacing: 10) { ProgressView().controlSize(.small); Text(L("tmWorking")).font(.callout) }
                    .padding(.vertical, 10)
            case .done: doneStep
            case .failed(let msg): failedStep(msg)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear { t.start() }
        .onDisappear { t.stop() }
    }

    var searchStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("tmChoose")).font(.headline)
            if t.servers.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(t.searchedLong ? L("tmNotFound") : L("tmSearching")).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 14)
            } else {
                ForEach(t.servers) { s in
                    let sel = t.selected == s
                    Button { t.selected = s } label: {
                        HStack(spacing: 10) {
                            Image(systemName: sel ? "largecircle.fill.circle" : "circle").foregroundStyle(sel ? Color.accentColor : .secondary)
                            Image(systemName: "server.rack").font(.title3)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.name).font(.callout.weight(.medium))
                                Text(s.host).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(sel ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(sel ? Color.accentColor : Color.primary.opacity(0.08)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button(L("pdContinue")) { t.phase = .password }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(t.selected == nil)
            }
        }
    }

    var passwordStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Lf("tmPasswordTitle", t.selected?.name ?? "")).font(.headline)
            Text(L("tmPasswordHint")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            SecureField(L("tmPassword"), text: $t.password).textFieldStyle(.roundedBorder).onSubmit { t.checkPassword() }
            if let e = t.passwordError {
                Label(e, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(Color.orange)
            }
            HStack {
                if t.checking { ProgressView().controlSize(.small) }
                Spacer()
                Button(L("pdBack")) { t.phase = .search }.keyboardShortcut(.cancelAction)
                Button(L("pdContinue")) { t.checkPassword() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(t.password.isEmpty || t.checking)
            }
        }
    }

    var existingStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("tmExistingTitle")).font(.headline)
            Text(Lf("tmExistingMsg", t.otherDestinations.joined(separator: ", "), t.selected?.name ?? ""))
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("tmReplace")) { t.configure(replace: true) }
                Button(L("tmUseBoth")) { t.configure(replace: false) }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
    }

    var doneStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(Lf("tmDoneTitle", t.selected?.name ?? ""), systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Color.green)
            Text(L("tmDoneMsg")).font(.callout).fixedSize(horizontal: false, vertical: true)
            Button(L("tmEncrypt")) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Time-Machine-Settings.extension")!)
            }
            .buttonStyle(.link).font(.callout)
            HStack {
                Spacer()
                Button(L("pdClose")) { dismissWindow(id: "tmsetup") }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
    }

    func failedStep(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("pdFailed"), systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(Color.orange)
            Text(msg).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("openSettings")) {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
                Spacer()
                Button(L("pdBack")) { t.phase = .password }
            }
        }
    }
}

let STMSetup: [String: [String: String]] = [
    "tmMenu": ["pt": "Configurar o Time Machine com o Backeddy Server…", "en": "Set Up Time Machine with Backeddy Server…",
               "es": "Configurar Time Machine con Backeddy Server…"],
    "tmButton": ["pt": "Configurar com o Backeddy Server…", "en": "Set up with Backeddy Server…", "es": "Configurar con Backeddy Server…"],
    "tmTitle": ["pt": "Fazer backup no Backeddy Server", "en": "Back up to Backeddy Server", "es": "Hacer backup en Backeddy Server"],
    "tmSubtitle": ["pt": "O Backeddy configura o Time Machine para você. Não precisa mexer nos Ajustes do Sistema.",
                   "en": "Backeddy sets up Time Machine for you. No need to touch System Settings.",
                   "es": "Backeddy configura Time Machine por ti. No hace falta tocar los Ajustes del Sistema."],
    "tmChoose": ["pt": "Escolha o servidor", "en": "Choose the server", "es": "Elige el servidor"],
    "tmSearching": ["pt": "Procurando o Backeddy Server na rede…", "en": "Looking for Backeddy Server on the network…",
                    "es": "Buscando Backeddy Server en la red…"],
    "tmNotFound": ["pt": "Ainda não achei. Confira se o servidor está ligado e se este Mac está na mesma rede (mesmo Wi-Fi ou roteador).",
                   "en": "Not found yet. Check that the server is on and that this Mac is on the same network (same Wi-Fi or router).",
                   "es": "Aún no lo encuentro. Comprueba que el servidor esté encendido y que este Mac esté en la misma red (mismo Wi-Fi o router)."],
    "tmPasswordTitle": ["pt": "Senha do %@", "en": "Password for %@", "es": "Contraseña de %@"],
    "tmPasswordHint": ["pt": "A senha que você escolheu ao instalar o servidor.", "en": "The password you chose when installing the server.",
                       "es": "La contraseña que elegiste al instalar el servidor."],
    "tmPassword": ["pt": "Senha", "en": "Password", "es": "Contraseña"],
    "tmWrongPassword": ["pt": "Senha errada. Tente de novo.", "en": "Wrong password. Try again.", "es": "Contraseña incorrecta. Inténtalo de nuevo."],
    "tmTooMany": ["pt": "Muitas tentativas. Espere 10 minutos.", "en": "Too many attempts. Wait 10 minutes.", "es": "Demasiados intentos. Espera 10 minutos."],
    "tmServerError": ["pt": "O servidor respondeu com erro (%@).", "en": "The server returned an error (%@).", "es": "El servidor respondió con un error (%@)."],
    "tmUnreachable": ["pt": "Não consegui falar com o servidor. Ele está ligado?", "en": "Couldn't reach the server. Is it on?",
                      "es": "No pude comunicarme con el servidor. ¿Está encendido?"],
    "tmExistingTitle": ["pt": "Este Mac já faz backup em outro lugar", "en": "This Mac already backs up somewhere else",
                        "es": "Este Mac ya hace backup en otro lugar"],
    "tmExistingMsg": ["pt": "Hoje o Time Machine usa: %@.\n\nDá para usar os dois (o Time Machine alterna entre eles: mais seguro) ou trocar tudo pelo %@.",
                      "en": "Time Machine currently uses: %@.\n\nYou can use both (Time Machine alternates between them: safer) or replace everything with %@.",
                      "es": "Hoy Time Machine usa: %@.\n\nPuedes usar los dos (Time Machine alterna entre ellos: más seguro) o cambiarlo todo por %@."],
    "tmUseBoth": ["pt": "Usar os dois (recomendado)", "en": "Use Both (Recommended)", "es": "Usar los dos (recomendado)"],
    "tmReplace": ["pt": "Trocar pelo Backeddy", "en": "Replace with Backeddy", "es": "Cambiar por Backeddy"],
    "tmWorking": ["pt": "Configurando o Time Machine… (o Mac vai pedir a senha de administrador)",
                  "en": "Setting up Time Machine… (your Mac will ask for the administrator password)",
                  "es": "Configurando Time Machine… (el Mac pedirá la contraseña de administrador)"],
    "tmDoneTitle": ["pt": "Pronto! Este Mac faz backup no %@", "en": "Done! This Mac backs up to %@", "es": "¡Listo! Este Mac hace backup en %@"],
    "tmDoneMsg": ["pt": "O primeiro backup já começou. Ele demora (horas, se o Mac estiver cheio); pode usar o Mac normalmente. Depois, o Time Machine faz backup sozinho, de hora em hora, sempre que o Mac estiver na rede de casa.",
                  "en": "The first backup has started. It takes a while (hours if your Mac is full); you can keep using your Mac. After that, Time Machine backs up on its own every hour whenever your Mac is on your home network.",
                  "es": "El primer backup ya empezó. Tarda (horas, si el Mac está lleno); puedes usar el Mac con normalidad. Después, Time Machine hace backup solo, cada hora, siempre que el Mac esté en la red de casa."],
    "tmEncrypt": ["pt": "Quero criptografar os backups (abre os Ajustes do Time Machine)", "en": "I want to encrypt the backups (opens Time Machine settings)",
                  "es": "Quiero cifrar los backups (abre los Ajustes de Time Machine)"],
    "tmNeedFDA": ["pt": "O macOS não deixou mudar o Time Machine. Dê ao Backeddy o Acesso Total ao Disco (Ajustes do Sistema › Privacidade e Segurança) e tente de novo.",
                  "en": "macOS didn't allow changing Time Machine. Give Backeddy Full Disk Access (System Settings › Privacy & Security) and try again.",
                  "es": "macOS no permitió cambiar Time Machine. Da a Backeddy Acceso total al disco (Ajustes del Sistema › Privacidad y seguridad) y vuelve a intentarlo."],
]
