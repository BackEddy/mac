// Force TM — estado e ações
import SwiftUI
import AppKit
import IOKit.pwr_mgt
import ServiceManagement

enum ResultKind { case success, failure, info }

struct ResultInfo: Identifiable {
    let id = UUID()
    let kind: ResultKind
    let title: String
    let detail: String
    var errors: [String] = []
}

@MainActor
final class Model: ObservableObject {
    // Backup
    @Published var status = TMStatus()
    @Published var backups: [String] = UserDefaults.standard.stringArray(forKey: "backups") ?? []
    @Published var serverLive = false
    @Published var needsFDA = false
    @Published var backupsError = ""
    @Published var speed: Double?
    @Published var working = false
    @Published var result: ResultInfo?
    @Published var destKind = ""
    @Published var net = NetInfo()

    // Este Mac
    @Published var snapshots: [String] = []
    @Published var free: Int64 = 0
    @Published var turbo = false
    @Published var source = PowerSource()
    @Published var phaseStart = Date()
    @Published var sleepCountdown: Int?
    @Published var sleepWhenDone: Bool = UserDefaults.standard.bool(forKey: "sleepWhenDone") {
        didSet { guard sleepWhenDone != oldValue else { return }; UserDefaults.standard.set(sleepWhenDone, forKey: "sleepWhenDone") }
    }

    // Limpeza
    @Published var wa = WAScan()
    @Published var waScanning = false
    @Published var waWorking = false
    @Published var waDays: Int = UserDefaults.standard.object(forKey: "waDays") as? Int ?? 30 {
        didSet { guard waDays != oldValue else { return }; UserDefaults.standard.set(waDays, forKey: "waDays"); scanWA() }
    }
    @Published var caches: [CacheItem] = []
    @Published var cacheSel: Set<String> = []
    @Published var cacheScanning = false
    @Published var cacheWorking = false

    // Histórico e ajustes
    @Published var history: [HistoryEntry] = loadHistory()
    @Published var consent = UserDefaults.standard.bool(forKey: "consent_v1")
    @Published var lang: String = UserDefaults.standard.string(forKey: "lang") ?? "auto" {
        didSet {
            guard lang != oldValue else { return }
            UserDefaults.standard.set(lang, forKey: "lang"); currentLang = resolveLang()
        }
    }
    @Published var reminderDays: Int = UserDefaults.standard.object(forKey: "reminderDays") as? Int ?? 7 {
        didSet { guard reminderDays != oldValue else { return }; UserDefaults.standard.set(reminderDays, forKey: "reminderDays") }
    }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var before: [String]?
    private var startDate: Date?
    private var wasRunning = false
    private var userStopped = false
    private var lastBytes: Double?
    private var lastTime: Date?
    private var lastSent: Double?
    private var assertion: IOPMAssertionID = 0
    private var awake = false
    private var phaseKey = ""

    init() {
        // Cada leitura roda em paralelo: um comando lento não atrasa o resto
        Task { await loop() }
        Task {
            let r = await Task.detached { readBackups() }.value
            needsFDA = r.noAccess
            if !r.list.isEmpty { save(r.list) }
        }
        Task { destKind = await Task.detached { readDestinationKind() }.value }
        Task { scanWA(); scanCaches() }
    }

    // MARK: Derivados

    var lastDays: Int? { backups.last.flatMap(daysAgo) }
    var staleWarning: String? {
        guard let d = lastDays, d >= 7 else { return nil }
        return Lf("staleWarn", agoText(d))
    }
    var hasRecentBackup: Bool { (lastDays ?? 99) <= 1 }
    var cacheSelBytes: Int64 { caches.filter { cacheSel.contains($0.id) }.reduce(0) { $0 + $1.bytes } }
    var cacheSelHasBrowser: Bool { caches.contains { cacheSel.contains($0.id) && $0.browser } }
    var showNetHint: Bool { status.running && net.wifi == true && destKind == "Network" && (speed ?? 1e9) < 10_000_000 }
    var menuStatusText: String {
        if status.running { return "\(phaseName(status.phase)) · \(pct(status.percent))" }
        if let d = lastDays { return (d >= 7 ? L("statusStale") : L("statusOK")) + " · " + Lf("lastBackup", agoText(d)) }
        return L("idle")
    }

    /// Só avisa a interface quando o valor realmente muda (evita redesenhos à toa)
    private func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<Model, T>, _ v: T) {
        if self[keyPath: kp] != v { self[keyPath: kp] = v }
    }

    func acceptConsent() { consent = true; UserDefaults.standard.set(true, forKey: "consent_v1") }

    // MARK: Ciclo

    private func loop() async {
        while true {
            await tick()
            try? await Task.sleep(for: .seconds(status.running ? 3 : 15))
        }
    }

    func tick() async {
        let s = await Task.detached { readStatus() }.value

        if s.running, let b = s.bytes {
            let now = Date()
            if let lb = lastBytes, let lt = lastTime, now > lt {
                let inst = max(0, (b - lb) / now.timeIntervalSince(lt))
                set(\.speed, speed.map { $0 * 0.8 + inst * 0.2 } ?? inst)
            }
            lastBytes = b; lastTime = now; lastSent = b
        } else if s.running {
            // fase sem transferência (preparando, limpando…): sem velocidade
            set(\.speed, nil); lastBytes = nil; lastTime = nil
        }

        if s.running && s.phase != phaseKey {
            phaseKey = s.phase
            phaseStart = Date()
        }

        if s.running {
            if !wasRunning {
                if startDate == nil { startDate = Date().addingTimeInterval(-60) }
                keepAwake(true)
                if result != nil { result = nil }
            }
            if before?.isEmpty ?? true {
                let r = await Task.detached { readBackups() }.value
                set(\.needsFDA, r.noAccess); set(\.backupsError, r.error)
                if !r.list.isEmpty { before = r.list; save(r.list) }
            }
            let new_net = await Task.detached { readNetwork() }.value
            set(\.net, new_net)
            if destKind.isEmpty {
                let k = await Task.detached { readDestinationKind() }.value
                set(\.destKind, k)
            }
        } else if wasRunning {
            set(\.status, s)
            keepAwake(false)
            await finish()
        }

        wasRunning = s.running
        set(\.status, s)
        if !s.running { set(\.speed, nil); lastBytes = nil; lastTime = nil }
        let new_snapshots = await Task.detached { listLocalSnapshots() }.value
        set(\.snapshots, new_snapshots)
        set(\.free, freeBytes())
        let new_turbo = await Task.detached { turboIsOn() }.value
        set(\.turbo, new_turbo)
        let new_source = await Task.detached { readPowerSource() }.value
        set(\.source, new_source)
        checkReminder()
    }

    private func save(_ list: [String]) {
        set(\.backups, list); set(\.serverLive, true)
        UserDefaults.standard.set(list, forKey: "backups")
    }

    private func addHistory(_ k: HistoryKind, log: String) {
        history.insert(HistoryEntry(date: Date(), kind: k), at: 0)
        if history.count > 200 { history.removeLast(history.count - 200) }
        saveHistory(history)
        appendLog(log)
    }

    private func checkReminder() {
        guard reminderDays > 0, !status.running, let d = lastDays, d >= reminderDays else { return }
        let today = String(stampFmt.string(from: Date()).prefix(10))
        if UserDefaults.standard.string(forKey: "lastReminder") == today { return }
        UserDefaults.standard.set(today, forKey: "lastReminder")
        notify(L("reminderTitle"), Lf("reminderBody", agoText(d)), sound: "Ping")
    }

    func openFDASettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Mostra o resultado de uma ação feita com senha de administrador
    private func handleAdmin(_ r: AdminResult, successTitle: String, successDetail: String = "") -> Bool {
        switch r {
        case .ok:
            result = ResultInfo(kind: .success, title: successTitle, detail: successDetail)
            return true
        case .cancelled:
            result = ResultInfo(kind: .info, title: L("opCancelled"), detail: L("opCancelledDetail"))
        case .failed(let msg):
            result = ResultInfo(kind: .failure, title: L("opFailed"), detail: msg)
        }
        return false
    }

    // MARK: Backup

    func startBackup() {
        working = true; result = nil; userStopped = false
        Task {
            let r0 = await Task.detached { readBackups() }.value
            needsFDA = r0.noAccess
            if !r0.list.isEmpty { before = r0.list; save(r0.list) } else { before = nil }
            startDate = Date().addingTimeInterval(-30)
            let r = await Task.detached { sh("/usr/bin/tmutil", ["startbackup"]) }.value
            working = false
            if r.code != 0 {
                result = ResultInfo(kind: .failure, title: L("startFail"), detail: L("startFailDetail"))
                addHistory(.startFail, log: "ERROR: could not start backup")
                startDate = nil
            }
            try? await Task.sleep(for: .seconds(3))
            await tick()
        }
    }

    func stopBackup() {
        userStopped = true
        Task { _ = await Task.detached { sh("/usr/bin/tmutil", ["stopbackup"]) }.value; await tick() }
    }

    private func finish() async {
        var after: [String] = []
        for _ in 0..<6 {
            after = await Task.detached { readBackups().list }.value
            if !after.isEmpty { break }
            try? await Task.sleep(for: .seconds(5))
        }
        let prev = Set(before ?? backups)
        let day = String(stampFmt.string(from: startDate ?? Date()).prefix(10))
        let new = after.filter { !prev.contains($0) && $0 >= day }
        if !after.isEmpty { save(after) }

        if let latest = new.last {
            result = ResultInfo(kind: .success, title: L("resultOK"),
                                detail: Lf("resultOKDetail", pretty(latest), gb(lastSent), after.count))
            addHistory(.backupOK(stamp: latest, sent: lastSent, count: after.count),
                       log: "OK: backup \(latest), \(gb(lastSent)) sent, \(after.count) backups at destination")
            notify("Force TM ✅", Lf("notifOK", pretty(latest)), sound: "Glass")
        } else if userStopped {
            result = ResultInfo(kind: .info, title: L("stoppedTitle"), detail: L("stoppedDetail"))
            addHistory(.stopped, log: "STOPPED: backup stopped by user")
        } else {
            let since = startDate ?? Date().addingTimeInterval(-3600)
            let errs = await Task.detached { recentErrors(since: since) }.value
            let last = (after.isEmpty ? backups : after).last
            var detail = after.isEmpty ? L("failNoRead") : L("failNoNew")
            if let last { detail += " " + Lf("lastGood", pretty(last), agoText(daysAgo(last))) }
            result = ResultInfo(kind: .failure, title: L("resultFail"), detail: detail, errors: errs)
            addHistory(.backupFail(lastGood: last), log: "ERROR: no new backup; last good: \(last ?? "unknown")")
            notify("Force TM ❌", L("resultFail"), sound: "Basso")
        }
        let stoppedByUser = userStopped
        before = nil; startDate = nil; lastSent = nil; userStopped = false; phaseKey = ""
        if sleepWhenDone && !stoppedByUser { startSleepCountdown() }
    }

    // MARK: Dormir ao terminar

    private func startSleepCountdown() {
        sleepCountdown = 30
        Task {
            while let c = sleepCountdown, c > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard let c2 = sleepCountdown else { return }
                sleepCountdown = c2 - 1
            }
            if sleepCountdown == 0 { sleepNow() }
        }
    }

    func cancelSleep() { sleepCountdown = nil }

    func sleepNow() {
        sleepCountdown = nil
        appendLog("SLEEP: Mac put to sleep after backup")
        Task.detached { sh("/usr/bin/pmset", ["sleepnow"], timeout: 10) }
    }

    // MARK: Snapshots, turbo, energia

    func deleteSnapshots() {
        let n = snapshots.count
        if handleAdmin(runAdmin("/usr/bin/tmutil thinlocalsnapshots / 999999999999 4"),
                       successTitle: L("snapDeleted"), successDetail: Lf("snapDeletedDetail", n)) {
            addHistory(.snapshots(count: n), log: "SNAPSHOTS: \(n) local snapshots deleted")
        }
        Task { await tick() }
    }

    func setTurbo(_ on: Bool) {
        _ = handleAdmin(runAdmin(on ? turboOnCommand : turboOffCommand),
                        successTitle: on ? L("turboEnabled") : L("turboDisabled"))
        appendLog(on ? "TURBO: on" : "TURBO: off")
        Task { await tick() }
    }

    /// Apaga a tela sem pôr o Mac para dormir (o backup continua)
    func displaySleepNow() {
        Task.detached { sh("/usr/bin/pmset", ["displaysleepnow"], timeout: 10) }
    }

    // MARK: WhatsApp

    func scanWA() {
        waScanning = true
        let d = waDays
        Task {
            wa = await Task.detached { waScan(days: d) }.value
            waScanning = false
        }
    }

    func cleanWA() {
        waWorking = true
        let d = waDays
        Task {
            let running = waBundleIDs.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            let reopen = running.compactMap { $0.bundleIdentifier }
            for app in running { _ = app.terminate() }
            func stillRunning() -> Bool { waBundleIDs.contains { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty } }
            for _ in 0..<30 {
                if !stillRunning() { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
            if stillRunning() {
                result = ResultInfo(kind: .failure, title: L("waTitle"), detail: L("waQuitFail"))
                waWorking = false
                return
            }
            let r = await Task.detached { waClean(days: d) }.value
            addHistory(.whatsapp(files: r.count, bytes: r.bytes),
                       log: "WHATSAPP: \(r.count) files (\(gb(r.bytes))) deleted, older than \(d) days")
            result = ResultInfo(kind: .success, title: L("waTitle"), detail: Lf("waDone", r.count, gb(r.bytes)))
            for id in Set(reopen) { sh("/usr/bin/open", ["-g", "-b", id]) }
            waWorking = false
            scanWA()
            free = freeBytes()
        }
    }

    // MARK: Caches

    func scanCaches() {
        cacheScanning = true
        Task {
            caches = await Task.detached { Force_TM_scanCaches() }.value
            cacheSel = cacheSel.filter { id in caches.contains { $0.id == id } }
            cacheScanning = false
        }
    }

    func cleanCaches() {
        let items = caches.filter { cacheSel.contains($0.id) }
        cacheWorking = true
        Task {
            let freed = await Task.detached { deleteCaches(items) }.value
            addHistory(.cache(bytes: freed), log: "CACHE: \(gb(freed)) deleted (\(items.map(\.id).joined(separator: ", ")))")
            result = ResultInfo(kind: .success, title: L("cacheTitle"), detail: Lf("cacheDone", gb(freed)))
            cacheSel = []
            cacheWorking = false
            scanCaches()
            free = freeBytes()
        }
    }

    // MARK: Ajustes

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            result = ResultInfo(kind: .failure, title: L("opFailed"), detail: Lf("loginFail", error.localizedDescription))
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func keepAwake(_ on: Bool) {
        if on && !awake {
            awake = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                "Force TM: Time Machine backup in progress" as CFString,
                                                &assertion) == kIOReturnSuccess
        } else if !on && awake {
            IOPMAssertionRelease(assertion); awake = false
        }
    }
}

/// Apelido para chamar a função global de dentro do modelo (que tem um método com o mesmo nome)
func Force_TM_scanCaches() -> [CacheItem] { scanCaches() }
