// Backeddy — ponto de entrada
// Criado por Eddy Antonini — https://eddyantonini.com.br
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Com o ícone na barra de menus, fechar a janela não encerra o app
        !(UserDefaults.standard.object(forKey: "menuBar") as? Bool ?? true)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in ServerModel.shared.start() }
    }
}

func showAbout() {
    let credits = NSMutableAttributedString(string: L("createdBy") + "\n")
    credits.append(NSAttributedString(string: "eddyantonini.com.br",
                                      attributes: [.link: URL(string: "https://eddyantonini.com.br")!]))
    let para = NSMutableParagraphStyle(); para.alignment = .center
    credits.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: credits.length))
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    NSApp.activate(ignoringOtherApps: true)
}


/// Traz histórico, log e ajustes da época em que o app se chamava Force TM.
func migrateFromForceTM() {
    let fm = FileManager.default
    let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let oldDir = support.appendingPathComponent("Force TM"), newDir = support.appendingPathComponent("Backeddy")
    if fm.fileExists(atPath: oldDir.path) && !fm.fileExists(atPath: newDir.path) { try? fm.moveItem(at: oldDir, to: newDir) }
    let oldLog = home.appendingPathComponent("Library/Logs/force-tm.log")
    let newLog = home.appendingPathComponent("Library/Logs/backeddy.log")
    if fm.fileExists(atPath: oldLog.path) && !fm.fileExists(atPath: newLog.path) { try? fm.moveItem(at: oldLog, to: newLog) }
    let d = UserDefaults.standard
    if !d.bool(forKey: "migratedFromForceTM"), let old = UserDefaults(suiteName: "br.com.eddyantonini.forcetm") {
        for (k, v) in old.dictionaryRepresentation()
        where !k.hasPrefix("NS") && !k.hasPrefix("Apple") && !k.hasPrefix("com.apple") && d.object(forKey: k) == nil {
            d.set(v, forKey: k)
        }
        d.set(true, forKey: "migratedFromForceTM")
    }
}

struct AppCommands: Commands {
    let model: Model
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L("about")) { showAbout() }
        }
        CommandGroup(after: .newItem) {
            Button(L("tmMenu")) { openWindow(id: "tmsetup") }
            Button(L("pdMenu")) { openWindow(id: "pendrive") }
        }
        CommandGroup(replacing: .help) {
            Button(L("helpMenu")) { openWindow(id: "help") }.keyboardShortcut("?", modifiers: .command)
            Button(L("copyDiag")) { model.copyDiagnostics() }
            Divider()
            Button(L("supportBtn")) { openWindow(id: "support") }
            Button("GitHub") { NSWorkspace.shared.open(repoURL) }
        }
    }
}

@main
struct BackeddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = Model()
    @AppStorage("menuBar") private var showMenuBar = true

    init() { migrateFromForceTM() }

    var body: some Scene {
        Window("Backeddy", id: "main") {
            ContentView().environmentObject(model)
        }
        .windowResizability(.contentSize)
        .commands { AppCommands(model: model) }

        Window("Backeddy — \(L("helpTitle"))", id: "help") {
            HelpView().environmentObject(model)
        }
        .windowResizability(.contentSize)

        Window(L("supportTitle"), id: "support") {
            SupportView().environmentObject(model)
        }
        .windowResizability(.contentSize)

        Window(L("tmTitle"), id: "tmsetup") {
            TMSetupView()
        }
        .windowResizability(.contentSize)

        Window(L("pdTitle"), id: "pendrive") {
            PendriveView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView().environmentObject(model)
        }

        MenuBarExtra(isInserted: $showMenuBar) {
            MenuBarView().environmentObject(model)
        } label: {
            MenuBarLabel(m: model)
        }
        .menuBarExtraStyle(.window)
    }
}
