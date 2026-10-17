// Backeddy — aba Servidor: situação do Backeddy Server da casa e alertas (reconhecer = parar o bipe)
import SwiftUI
import AppKit
import Security

// MARK: - Senha nas Chaves do macOS

enum Keychain {
    static let service = "br.com.backeddy.mac.server"

    static func save(_ password: String, account: String) {
        delete(account: account)
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                  kSecAttrAccount: account, kSecValueData: Data(password.utf8)]
        SecItemAdd(q as CFDictionary, nil)
    }
    static func load(account: String) -> String? {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                                  kSecAttrAccount: account, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func delete(account: String) {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
        SecItemDelete(q as CFDictionary)
    }
}

// MARK: - Modelo

struct ServerAlert: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let text: String
    enum CodingKeys: String, CodingKey { case id = "ID", text = "Text" }   // o servidor manda {"ID", "Text"}
}

private struct StatusResponse: Decodable {
    let name: String
    let alerts: [ServerAlert]?
    let status: String
}

@MainActor
final class ServerModel: ObservableObject {
    static let shared = ServerModel()
    enum State: Equatable { case idle, ok, unreachable, wrongPassword }

    @Published private(set) var host: String? = UserDefaults.standard.string(forKey: "serverHost")
    @Published private(set) var name: String = UserDefaults.standard.string(forKey: "serverName") ?? ""
    @Published var state: State = .idle
    @Published var alerts: [ServerAlert] = []
    @Published var statusText = ""
    @Published var updated: Date?
    @Published var busy = false
    private var timer: Timer?
    private var notified: Set<String> = []

    var configured: Bool { host != nil }

    /// Chamado pelo "Configurar com o Backeddy Server" depois que a senha confere
    func remember(host: String, name: String, password: String) {
        if let old = self.host, old != host { Keychain.delete(account: old) }
        UserDefaults.standard.set(host, forKey: "serverHost")
        UserDefaults.standard.set(name, forKey: "serverName")
        Keychain.save(password, account: host)
        self.host = host; self.name = name
        refresh()
    }

    func forget() {
        if let h = host { Keychain.delete(account: h) }
        UserDefaults.standard.removeObject(forKey: "serverHost")
        UserDefaults.standard.removeObject(forKey: "serverName")
        host = nil; name = ""; alerts = []; statusText = ""; updated = nil; state = .idle; notified = []
    }

    /// A cada minuto, mesmo com a janela fechada (o ícone da barra de menus avisa)
    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in ServerModel.shared.refresh() }
        }
        refresh()
    }

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest? {
        guard let h = host, let pw = Keychain.load(account: h), let url = URL(string: "http://\(h)\(path)") else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 15
        r.setValue("Basic " + Data("backeddy:\(pw)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    func refresh() {
        guard let req = request("/api/status") else { if configured { state = .wrongPassword }; return }
        Task {
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 401 { state = .wrongPassword; return }
                guard code == 200 else { state = .unreachable; return }
                let s = try JSONDecoder().decode(StatusResponse.self, from: data)
                statusText = s.status.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.name.isEmpty, s.name != name { name = s.name; UserDefaults.standard.set(s.name, forKey: "serverName") }
                let list = s.alerts ?? []
                // avisa uma vez por alerta novo (o servidor bipa a cada minuto até alguém reconhecer)
                for a in list where !notified.contains(a.id) { notify("\(name) ⚠️", a.text, sound: "Basso") }
                notified = Set(list.map(\.id))
                alerts = list
                updated = Date(); state = .ok
            } catch {
                state = .unreachable
            }
        }
    }

    /// Para o bipe e lembra de novo em `days` dias se o problema continuar
    func ack(days: Int) {
        guard let req = request("/api/ack", method: "POST", body: ["Days": days]) else { return }
        busy = true
        Task {
            defer { busy = false }
            _ = try? await URLSession.shared.data(for: req)
            refresh()
        }
    }

    func openPanel() {
        if let h = host, let u = URL(string: "http://\(h)") { NSWorkspace.shared.open(u) }
    }
}

// MARK: - Aba

struct AckButtons: View {
    @ObservedObject var s = ServerModel.shared
    var body: some View {
        HStack(spacing: 8) {
            Button(L("srvAck1")) { s.ack(days: 1) }
            Button(L("srvAck3")) { s.ack(days: 3) }
            Button(L("srvAck7")) { s.ack(days: 7) }
        }
        .disabled(s.busy)
    }
}

struct ServerTabView: View {
    @ObservedObject var s = ServerModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 14) {
            if !s.configured {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L("srvTitle"), systemImage: "server.rack").font(.headline)
                        Text(L("srvNotConfigured")).font(.callout).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button(L("srvConnect")) { openWindow(id: "tmsetup") }.buttonStyle(.borderedProminent)
                            Button(L("srvNoServer")) { openWindow(id: "pendrive") }
                        }
                    }
                }
            } else {
                if !s.alerts.isEmpty { alertsCard }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(s.name.isEmpty ? L("srvTitle") : s.name, systemImage: "server.rack").font(.headline)
                            Spacer()
                            stateBadge
                        }
                        Text(s.host ?? "").font(.caption).foregroundStyle(.secondary)
                        if !s.statusText.isEmpty {
                            ScrollView {
                                Text(s.statusText).font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                            }
                            .frame(maxHeight: 260)
                        }
                        if s.state == .wrongPassword {
                            Button(L("srvReconnect")) { openWindow(id: "tmsetup") }
                        }
                    }
                }
                HStack {
                    Button { s.openPanel() } label: { Label(L("srvPanel"), systemImage: "safari") }
                    Button { s.refresh() } label: { Label(L("srvRefresh"), systemImage: "arrow.clockwise") }
                    Spacer()
                    Button(L("srvForget"), role: .destructive) { s.forget() }.buttonStyle(.borderless).font(.caption)
                }
            }
        }
        .onAppear { s.refresh() }
    }

    var alertsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("srvBeeping"), systemImage: "speaker.wave.3.fill").font(.headline).foregroundStyle(Color.red)
            ForEach(s.alerts) { a in Text("• " + a.text).font(.callout).fixedSize(horizontal: false, vertical: true) }
            Text(L("srvAckHint")).font(.caption).foregroundStyle(.secondary)
            AckButtons()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.12)))
    }

    @ViewBuilder var stateBadge: some View {
        switch s.state {
        case .ok:
            Text(s.updated.map { Lf("srvUpdated", $0.formatted(date: .omitted, time: .shortened)) } ?? "")
                .font(.caption).foregroundStyle(.secondary)
        case .unreachable:
            Label(L("srvUnreachable"), systemImage: "wifi.slash").font(.caption).foregroundStyle(Color.orange)
        case .wrongPassword:
            Label(L("srvWrongPassword"), systemImage: "key.slash").font(.caption).foregroundStyle(Color.orange)
        case .idle:
            ProgressView().controlSize(.small)
        }
    }
}

let SServer: [String: [String: String]] = [
    "srvTab": ["pt": "Servidor", "en": "Server", "es": "Servidor"],
    "srvTitle": ["pt": "Backeddy Server", "en": "Backeddy Server", "es": "Backeddy Server"],
    "srvNotConfigured": ["pt": "Conecte o servidor de backup da casa para ver a situação dele aqui e parar o bipe quando houver um alerta.",
                         "en": "Connect your home backup server to see its status here and stop the beeping when there's an alert.",
                         "es": "Conecta el servidor de backup de casa para ver su estado aquí y detener el pitido cuando haya una alerta."],
    "srvConnect": ["pt": "Conectar ao Backeddy Server…", "en": "Connect to Backeddy Server…", "es": "Conectar a Backeddy Server…"],
    "srvNoServer": ["pt": "Ainda não tenho: criar o pendrive…", "en": "Don't have one yet: create the USB drive…", "es": "Aún no tengo: crear el pendrive…"],
    "srvBeeping": ["pt": "O servidor está bipando", "en": "The server is beeping", "es": "El servidor está pitando"],
    "srvAckHint": ["pt": "Reconhecer para o bipe. Se o problema continuar, o servidor lembra de novo:",
                   "en": "Acknowledging stops the beeping. If the problem persists, the server reminds you again:",
                   "es": "Reconocer detiene el pitido. Si el problema sigue, el servidor vuelve a avisar:"],
    "srvAck1": ["pt": "Amanhã", "en": "Tomorrow", "es": "Mañana"],
    "srvAck3": ["pt": "Em 3 dias", "en": "In 3 days", "es": "En 3 días"],
    "srvAck7": ["pt": "Em 7 dias", "en": "In 7 days", "es": "En 7 días"],
    "srvUpdated": ["pt": "Atualizado às %@", "en": "Updated at %@", "es": "Actualizado a las %@"],
    "srvUnreachable": ["pt": "Sem contato (fora de casa ou servidor desligado?)", "en": "No contact (away from home or server off?)",
                       "es": "Sin contacto (¿fuera de casa o servidor apagado?)"],
    "srvWrongPassword": ["pt": "A senha mudou", "en": "The password changed", "es": "La contraseña cambió"],
    "srvReconnect": ["pt": "Conectar de novo…", "en": "Reconnect…", "es": "Volver a conectar…"],
    "srvPanel": ["pt": "Abrir o painel", "en": "Open Panel", "es": "Abrir el panel"],
    "srvRefresh": ["pt": "Atualizar", "en": "Refresh", "es": "Actualizar"],
    "srvForget": ["pt": "Esquecer este servidor", "en": "Forget This Server", "es": "Olvidar este servidor"],
    "srvMenuAlert": ["pt": "%@ está bipando", "en": "%@ is beeping", "es": "%@ está pitando"],
]
