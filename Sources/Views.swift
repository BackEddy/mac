// Force TM — interface
import SwiftUI
import AppKit

// MARK: - Componentes

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }
}

struct Stat: View {
    let label: String, value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.callout, design: .rounded).weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

func md(_ s: String) -> Text { Text(LocalizedStringKey(s)) }

@MainActor let cachedAppIcon: NSImage = NSApplication.shared.applicationIconImage

@MainActor func appIcon(_ size: CGFloat) -> some View {
    Image(nsImage: cachedAppIcon).resizable().frame(width: size, height: size)
}

enum ActiveSheet: String, Identifiable {
    case consent, snapshots, whatsapp, caches, stop
    var id: String { rawValue }
}

enum MainTab: String { case backup, cleanup, history }

// MARK: - Janela principal

struct ContentView: View {
    @EnvironmentObject var m: Model
    @Environment(\.openWindow) private var openWindow
    @State private var tab: MainTab = .backup
    @State private var sheet: ActiveSheet?
    @State private var confirmText = ""
    @State private var consentChecked = false

    var confirmed: Bool { confirmText == L("confirmWord") || (currentLang == "es" && confirmText == "SI") }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if let w = m.staleWarning { banner(w) }
            if let r = m.result { resultCard(r) }
            if let c = m.sleepCountdown { sleepBanner(c) }
            Picker("", selection: $tab) {
                Text("Backup").tag(MainTab.backup)
                Text(L("tabCleanup")).tag(MainTab.cleanup)
                Text(L("history")).tag(MainTab.history)
            }
            .pickerStyle(.segmented).labelsHidden()
            switch tab {
            case .backup: backupTab
            case .cleanup: cleanupTab
            case .history: historyTab
            }
            footer
        }
        .padding(20)
        .frame(width: 600)
        .id(m.lang)
        .onAppear { if !m.consent { sheet = .consent } }
        .overlay { if let s = sheet { modalOverlay(s) } }
    }

    /// Painel modal desenhado dentro da janela (evita as folhas do sistema, que travavam)
    func modalOverlay(_ s: ActiveSheet) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .contentShape(Rectangle())
                .onTapGesture {}
            Group {
                switch s {
                case .consent: consentSheet
                case .snapshots: snapshotsSheet
                case .whatsapp: whatsappSheet
                case .caches: cachesSheet
                case .stop: stopSheet
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
        }
    }

    var stopSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            warningTitle("stopTitle")
            Text(L("stopMsg")).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("cancel")) { sheet = nil }.keyboardShortcut(.cancelAction)
                Button(L("stopConfirm"), role: .destructive) { sheet = nil; m.stopBackup() }
            }
        }
        .padding(20).frame(width: 420)
    }

    // MARK: Cabeçalho, avisos, rodapé

    var header: some View {
        HStack(spacing: 12) {
            appIcon(44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Force TM").font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    if m.status.running { ProgressView().controlSize(.mini) }
                    Text(m.status.running ? phaseName(m.status.phase) : L("idle"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { openWindow(id: "help") } label: { Image(systemName: "questionmark.circle").font(.title3) }
                .buttonStyle(.borderless).help(L("helpMenu"))
            if m.status.running {
                Button(L("stop"), role: .destructive) { sheet = .stop }
            } else {
                Button { m.startBackup() } label: { Label(L("backupNow"), systemImage: "arrow.up.circle.fill") }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(m.working)
            }
        }
    }

    func sleepBanner(_ c: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.fill").foregroundStyle(Color.indigo)
            Text(Lf("sleepCountdown", c)).font(.callout.weight(.semibold)).monospacedDigit()
            Spacer()
            Button(L("sleepNowBtn")) { m.sleepNow() }
            Button(L("cancel")) { m.cancelSleep() }.keyboardShortcut(.cancelAction)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.18)))
    }

    func banner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.orange)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.15)))
    }

    var footer: some View {
        HStack(spacing: 6) {
            Text(L("createdBy")).foregroundStyle(.secondary)
            Text("·").foregroundStyle(.secondary)
            Link("eddyantonini.com.br", destination: URL(string: "https://eddyantonini.com.br")!)
            Spacer()
            Button { openWindow(id: "support") } label: { Label(L("supportBtn"), systemImage: "heart.fill") }
                .buttonStyle(.borderless).foregroundStyle(Color.pink)
                .padding(.trailing, 8)
            Picker(L("language"), selection: $m.lang) {
                Text(L("langAuto")).tag("auto")
                Text("Português").tag("pt")
                Text("English").tag("en")
                Text("Español").tag("es")
            }
            .pickerStyle(.menu).frame(width: 160)
        }
        .font(.caption)
    }

    func resultCard(_ r: ResultInfo) -> some View {
        let icon = r.kind == .success ? "checkmark.seal.fill" : r.kind == .failure ? "xmark.octagon.fill" : "info.circle.fill"
        let color = r.kind == .success ? Color.green : r.kind == .failure ? Color.red : Color.blue
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon).font(.title2).foregroundStyle(color)
                    Text(r.title).font(.headline)
                    Spacer()
                    Button { m.result = nil } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
                }
                if !r.detail.isEmpty { Text(r.detail).font(.callout).fixedSize(horizontal: false, vertical: true) }
                if !r.errors.isEmpty {
                    ScrollView {
                        Text(r.errors.joined(separator: "\n"))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }
                    .frame(maxHeight: 110)
                }
            }
        }
    }

    // MARK: Aba Backup

    var backupTab: some View {
        VStack(spacing: 14) {
            progressCard
            HStack(alignment: .top, spacing: 14) { serverCard; macCard }
            powerCard
            turboCard
        }
    }

    var progressCard: some View {
        Card {
            if m.status.running {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        if let p = m.status.percent {
                            Text(pct(p)).font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                        } else {
                            // fases sem porcentagem (preparando, limpando backups antigos…)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phaseName(m.status.phase)).font(.system(size: 24, weight: .bold, design: .rounded))
                                TimelineView(.periodic(from: .now, by: 15)) { _ in
                                    Text(Lf("phaseElapsed", elapsedText(since: m.phaseStart)) + " — " + L("mayTakeAWhile"))
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Button { m.displaySleepNow() } label: { Label(L("screenOff"), systemImage: "display") }
                            .help(L("screenOffHelp"))
                    }
                    if let p = m.status.percent {
                        ProgressView(value: p).progressViewStyle(.linear)
                    } else {
                        ProgressView().progressViewStyle(.linear)
                    }
                    if m.status.bytes != nil || m.status.timeRemaining != nil {
                        HStack {
                            Stat(label: L("sent"), value: gb(m.status.bytes))
                            Stat(label: L("analyzed"), value: gb(m.status.totalBytes))
                            Stat(label: L("speed"), value: mbps(m.speed))
                            Stat(label: L("remaining"), value: hms(m.status.timeRemaining))
                        }
                    }
                    if m.destKind == "Network", let wifi = m.net.wifi {
                        HStack(spacing: 6) {
                            Image(systemName: wifi ? "wifi" : "cable.connector").foregroundStyle(.secondary)
                            Text("\(L("network")): \(wifi ? L("netWifi") : L("netCable"))\(m.net.iface.map { " (\($0))" } ?? "")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if m.showNetHint { Text(L("netHint")).font(.caption).foregroundStyle(Color.orange) }
                    }

                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.circle").foregroundStyle(.secondary)
                    Text(L("idleHint")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var serverCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Label(L("server"), systemImage: "externaldrive.connected.to.line.below").font(.headline)
                if m.needsFDA {
                    md(L("fdaNeeded")).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Button(L("openSettings")) { m.openFDASettings() }
                    Text(L("fdaHint")).font(.caption).foregroundStyle(.secondary)
                } else if let last = m.backups.last {
                    let d = daysAgo(last) ?? 99
                    Text(Lf("nBackups", m.backups.count)).font(.callout)
                    Text(Lf("lastBackup", pretty(last))).font(.callout)
                    Text(agoText(d)).font(.callout.weight(.semibold))
                        .foregroundStyle(d <= 1 ? Color.green : d <= 6 ? Color.orange : Color.red)
                    if !m.serverLive { Text(L("lastKnown")).font(.caption).foregroundStyle(.secondary) }
                } else {
                    Text(L("noData")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if m.status.running && !m.backupsError.isEmpty {
                        Text(m.backupsError).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
        }
    }

    var macCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Label(L("thisMac"), systemImage: "laptopcomputer").font(.headline)
                Text(Lf("nSnapshots", m.snapshots.count)).font(.callout)
                Text(Lf("free", gb(m.free))).font(.callout)
                Button(L("deleteSnapshotsBtn")) { confirmText = ""; sheet = .snapshots }
                    .disabled(m.snapshots.isEmpty || m.status.running)
                    .padding(.top, 2)
            }
        }
    }

    var powerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(L("powerTitle"), systemImage: "bolt.fill").font(.headline)
                    Spacer()
                    sourceBadge
                }
                if m.status.running {
                    Label(L("powerRunning"), systemImage: "cup.and.saucer.fill")
                        .font(.callout).foregroundStyle(Color.accentColor).fixedSize(horizontal: false, vertical: true)
                    if m.source.batteryPercent != nil {
                        Label(L("lidWarn"), systemImage: "laptopcomputer")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if !m.source.onAC && (m.source.batteryPercent ?? 100) < 20 {
                        Label(L("lowBattery"), systemImage: "battery.25percent")
                            .font(.callout).foregroundStyle(Color.orange).fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Label(L("powerIdle"), systemImage: "moon.zzz")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Toggle(L("sleepWhenDone"), isOn: $m.sleepWhenDone)
                    .toggleStyle(.checkbox).font(.callout).padding(.top, 2)
                    .help(L("sleepWhenDoneHelp"))
            }
        }
    }

    var sourceBadge: some View {
        let s = m.source
        let icon = s.onAC ? (s.batteryPercent == nil ? "powerplug.fill" : "battery.100percent.bolt") : batteryIcon(s.batteryPercent ?? 0)
        let text = s.onAC ? L("onAC") + (s.batteryPercent.map { " · \($0)%" } ?? "")
                          : Lf("onBattery", "\(s.batteryPercent ?? 0)%")
        return Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill((s.onAC ? Color.green : Color.orange).opacity(0.18)))
            .foregroundStyle(s.onAC ? Color.green : Color.orange)
    }

    func batteryIcon(_ p: Int) -> String {
        p > 75 ? "battery.100percent" : p > 50 ? "battery.75percent" : p > 25 ? "battery.50percent" : p > 10 ? "battery.25percent" : "battery.0percent"
    }

    var turboCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(L("turbo"), systemImage: "hare.fill").font(.headline)
                    Spacer()
                    Button(m.turbo ? L("turboDisable") : L("turboEnable")) { m.setTurbo(!m.turbo) }
                }
                Text(m.turbo ? L("turboOn") : L("turboOff")).font(.callout)
                    .foregroundStyle(m.turbo ? Color.accentColor : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("turboNote")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Aba Limpeza

    var cleanupTab: some View {
        VStack(spacing: 14) { waCard; cacheCard }
    }

    var waCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(L("waTitle"), systemImage: "photo.on.rectangle.angled").font(.headline)
                    Spacer()
                    Button { m.scanWA() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).help(L("refresh")).disabled(m.waScanning || m.waWorking)
                }
                if m.waScanning || m.waWorking {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L("scanning")).font(.callout).foregroundStyle(.secondary) }
                } else if !m.wa.found {
                    Text(L("waNotFound")).font(.callout).foregroundStyle(.secondary)
                } else {
                    Text(Lf("waUsing", gb(m.wa.bytes), m.wa.count)).font(.callout)
                    HStack {
                        Text(L("waOlderThan")).font(.callout)
                        Picker("", selection: $m.waDays) {
                            Text(L("waAll")).tag(0)
                            ForEach([7, 30, 90, 180], id: \.self) { d in Text(Lf("nDays", d)).tag(d) }
                        }
                        .labelsHidden().frame(width: 120)
                        Spacer()
                        Button(L("waCleanBtn")) { confirmText = ""; sheet = .whatsapp }.disabled(m.wa.selCount == 0)
                    }
                    Text(m.wa.selCount == 0 ? L("waNothing") : Lf("waWillDelete", m.wa.selCount, gb(m.wa.selBytes)))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    var cacheCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(L("cacheTitle"), systemImage: "archivebox").font(.headline)
                    Spacer()
                    Button { m.scanCaches() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).help(L("refresh")).disabled(m.cacheScanning || m.cacheWorking)
                }
                if m.cacheScanning || m.cacheWorking {
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text(L("scanning")).font(.callout).foregroundStyle(.secondary) }
                } else if m.caches.isEmpty {
                    Text(L("cacheNone")).font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(m.caches) { c in
                        Toggle(isOn: Binding(
                            get: { m.cacheSel.contains(c.id) },
                            set: { on in if on { m.cacheSel.insert(c.id) } else { m.cacheSel.remove(c.id) } }
                        )) {
                            HStack {
                                Text(L(c.id)).font(.callout)
                                Spacer()
                                Text(gb(c.bytes)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                    HStack {
                        Text(Lf("cacheSelected", gb(m.cacheSelBytes))).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("cacheCleanBtn")) { confirmText = ""; sheet = .caches }.disabled(m.cacheSel.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: Aba Histórico

    var historyTab: some View {
        Card {
            if m.history.isEmpty {
                Text(L("historyEmpty")).font(.callout).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(m.history) { e in
                            let h = historyDisplay(e.kind)
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: h.icon).foregroundStyle(h.color).frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(h.text).font(.callout)
                                    Text(dateText(e.date)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 360)
            }
        }
    }

    func historyDisplay(_ k: HistoryKind) -> (icon: String, color: Color, text: String) {
        switch k {
        case .backupOK(let stamp, let sent, _):
            return ("checkmark.seal.fill", .green, Lf("hBackupOK", gb(sent)) + " · " + pretty(stamp))
        case .backupFail:
            return ("xmark.octagon.fill", .red, L("hBackupFail"))
        case .stopped:
            return ("stop.circle.fill", .blue, L("hStopped"))
        case .startFail:
            return ("xmark.octagon.fill", .red, L("hStartFail"))
        case .snapshots(let count):
            return ("camera.on.rectangle.fill", .orange, Lf("hSnapshots", count))
        case .whatsapp(let files, let bytes):
            return ("photo.on.rectangle.angled", .orange, Lf("hWhatsApp", files, gb(bytes)))
        case .cache(let bytes):
            return ("archivebox.fill", .orange, Lf("hCache", gb(bytes)))
        }
    }

    // MARK: Folhas (sheets)

    var consentSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                appIcon(48)
                Text(L("consentTitle")).font(.title2.weight(.semibold))
            }
            md(L("consentBody")).font(.callout).fixedSize(horizontal: false, vertical: true)
            Toggle(L("consentCheck"), isOn: $consentChecked).toggleStyle(.checkbox)
            HStack {
                Button(L("quit")) { NSApp.terminate(nil) }
                Spacer()
                Button(L("continue")) { m.acceptConsent(); sheet = nil }
                    .buttonStyle(.borderedProminent).disabled(!consentChecked)
            }
        }
        .padding(24).frame(width: 460)
    }

    func confirmBlock(_ action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(Lf("typeToConfirm", L("confirmWord")), text: $confirmText).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(L("cancel")) { sheet = nil }.keyboardShortcut(.cancelAction)
                Button(L("delete"), role: .destructive) { sheet = nil; action() }.disabled(!confirmed)
            }
        }
    }

    func warningTitle(_ key: String) -> some View {
        Label(L(key), systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(Color.orange)
    }

    func redNote(_ text: String) -> some View {
        Text(text).font(.callout.weight(.semibold)).foregroundStyle(Color.red).fixedSize(horizontal: false, vertical: true)
    }

    var snapshotsSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            warningTitle("delSnapTitle")
            Text(Lf("delSnapMsg", m.snapshots.count)).font(.callout).fixedSize(horizontal: false, vertical: true)
            if !m.hasRecentBackup { redNote(L("delSnapNoRecent")) }
            confirmBlock { m.deleteSnapshots() }
        }
        .padding(20).frame(width: 440)
    }

    var whatsappSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            warningTitle("waConfirmTitle")
            Text(Lf("waConfirmMsg", m.wa.selCount, gb(m.wa.selBytes))).font(.callout).fixedSize(horizontal: false, vertical: true)
            redNote(L("waWarnPhone"))
            confirmBlock { m.cleanWA() }
        }
        .padding(20).frame(width: 440)
    }

    var cachesSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            warningTitle("cacheConfirmTitle")
            Text(Lf("cacheConfirmMsg", gb(m.cacheSelBytes))).font(.callout).fixedSize(horizontal: false, vertical: true)
            if m.cacheSelHasBrowser { redNote(L("cacheWarnBrowsers")) }
            confirmBlock { m.cleanCaches() }
        }
        .padding(20).frame(width: 440)
    }
}

// MARK: - Barra de menus

struct MenuBarLabel: View {
    @ObservedObject var m: Model
    var body: some View {
        if m.status.running {
            HStack(spacing: 3) {
                Image(systemName: "bolt.circle.fill")
                Text(String(format: "%.0f%%", (m.status.percent ?? 0) * 100))
            }
        } else {
            Image(systemName: m.staleWarning != nil ? "exclamationmark.triangle" : "bolt.circle")
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject var m: Model
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                appIcon(30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Force TM").font(.headline)
                    Text(m.menuStatusText).font(.caption).foregroundStyle(.secondary)
                }
            }
            if m.status.running {
                ProgressView(value: m.status.percent ?? 0)
                HStack {
                    Text(gb(m.status.bytes))
                    Spacer()
                    Text(mbps(m.speed))
                    Text("·")
                    Text(hms(m.status.timeRemaining))
                }
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            Divider()
            if !m.status.running {
                Button { m.startBackup() } label: { Label(L("backupNow"), systemImage: "arrow.up.circle") }.disabled(m.working)
            } else {
                Button { m.displaySleepNow() } label: { Label(L("screenOff"), systemImage: "display") }
            }
            Button { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) } label: {
                Label(L("openApp"), systemImage: "macwindow")
            }
            Button { NSApp.terminate(nil) } label: { Label(L("quitApp"), systemImage: "power") }
        }
        .buttonStyle(.borderless)
        .padding(14)
        .frame(width: 290)
        .id(m.lang)
    }
}

// MARK: - Ajuda

struct HelpView: View {
    @EnvironmentObject var m: Model
    let sections = (1...12).map { "h\($0)" }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    appIcon(48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Force TM — \(L("helpTitle"))").font(.title2.weight(.semibold))
                        HStack(spacing: 4) {
                            Text(L("createdBy"))
                            Link("eddyantonini.com.br", destination: URL(string: "https://eddyantonini.com.br")!)
                        }
                        .font(.caption)
                    }
                }
                ForEach(sections, id: \.self) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L(s + "t")).font(.headline)
                        md(L(s + "b")).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 580, height: 660)
        .id(m.lang)
    }
}

// MARK: - Ajustes

struct SettingsView: View {
    @EnvironmentObject var m: Model
    @AppStorage("menuBar") private var showMenuBar = true
    var body: some View {
        Form {
            Section {
                Toggle(L("settingsMenuBar"), isOn: $showMenuBar)
                Text(L("settingsMenuBarNote")).font(.caption).foregroundStyle(.secondary)
                Toggle(L("settingsLogin"), isOn: Binding(get: { m.launchAtLogin }, set: { m.setLaunchAtLogin($0) }))
            }
            Section {
                Picker(L("settingsReminder"), selection: $m.reminderDays) {
                    Text(L("never")).tag(0)
                    ForEach([3, 7, 14, 30], id: \.self) { d in Text(Lf("nDays", d)).tag(d) }
                }
                Text(L("settingsReminderNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Picker(L("language"), selection: $m.lang) {
                    Text(L("langAuto")).tag("auto")
                    Text("Português").tag("pt")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .id(m.lang)
    }
}
