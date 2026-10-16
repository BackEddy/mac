// Force TM — ponto de entrada
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

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L("about")) { showAbout() }
        }
        CommandGroup(replacing: .help) {
            Button(L("helpMenu")) { openWindow(id: "help") }.keyboardShortcut("?", modifiers: .command)
            Divider()
            Button(L("supportBtn")) { openWindow(id: "support") }
            Button("GitHub") { NSWorkspace.shared.open(repoURL) }
        }
    }
}

@main
struct ForceTMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = Model()
    @AppStorage("menuBar") private var showMenuBar = true

    var body: some Scene {
        Window("Force TM", id: "main") {
            ContentView().environmentObject(model)
        }
        .windowResizability(.contentSize)
        .commands { AppCommands() }

        Window("Force TM — \(L("helpTitle"))", id: "help") {
            HelpView().environmentObject(model)
        }
        .windowResizability(.contentSize)

        Window(L("supportTitle"), id: "support") {
            SupportView().environmentObject(model)
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
