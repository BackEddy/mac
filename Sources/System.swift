// Force TM — acesso ao sistema (Time Machine, energia, rede, WhatsApp, caches, histórico)
import Foundation
import AppKit

// MARK: - Shell

@discardableResult
func sh(_ path: String, _ args: [String], mergeErr: Bool = false, timeout: Double = 30) -> (out: String, code: Int32) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    if mergeErr { p.standardError = pipe } else { p.standardError = FileHandle.nullDevice }
    do { try p.run() } catch { return ("", -1) }
    // Nunca deixa um comando travar o app: encerra se passar do tempo
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if p.isRunning { p.terminate() } }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (String(decoding: data, as: UTF8.self), p.terminationStatus)
}

enum AdminResult { case ok, cancelled, failed(String) }

/// Roda um comando como administrador; o próprio macOS pede a senha. Chamar na thread principal.
func runAdmin(_ command: String) -> AdminResult {
    let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    var err: NSDictionary?
    NSAppleScript(source: "do shell script \"\(escaped)\" with administrator privileges")?.executeAndReturnError(&err)
    if let err {
        let n = (err[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
        if n == -128 { return .cancelled }
        return .failed(err[NSAppleScript.errorMessage] as? String ?? "error \(n)")
    }
    return .ok
}

func matches(_ text: String, _ pattern: String) -> [String] {
    guard let re = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return [] }
    let ns = text as NSString
    return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
}

func num(_ v: Any?) -> Double? {
    if let n = v as? NSNumber { return n.doubleValue }
    if let s = v as? String { return Double(s) }
    return nil
}

// MARK: - Time Machine

struct TMStatus: Sendable, Equatable {
    var running = false
    var phase = ""
    var percent: Double?
    var bytes: Double?
    var totalBytes: Double?
    var timeRemaining: Double?
    var mountPoint: String?
}

func readStatus() -> TMStatus {
    let r = sh("/usr/bin/tmutil", ["status", "-X"])
    guard let data = r.out.data(using: .utf8),
          let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
          let d = obj as? [String: Any] else { return TMStatus() }
    var s = TMStatus()
    s.running = (num(d["Running"]) ?? 0) == 1
    s.phase = d["BackupPhase"] as? String ?? ""
    s.mountPoint = d["DestinationMountPoint"] as? String
    let prog = d["Progress"] as? [String: Any] ?? [:]
    if let raw = num(prog["Percent"]) ?? num(d["Percent"]), raw >= 0 {
        var f = num(d["FractionOfProgressBar"]) ?? 1
        if f <= 0 || f > 1 { f = 1 }
        s.percent = min(1, (1 - f) + f * raw)   // mesma conta do menu do macOS
    }
    s.bytes = num(prog["bytes"])
    s.totalBytes = num(prog["totalBytes"])
    s.timeRemaining = num(prog["TimeRemaining"])
    return s
}

struct BackupsRead: Sendable {
    var list: [String] = []
    var noAccess = false
    var error = ""
}

func readBackups() -> BackupsRead {
    let out = sh("/usr/bin/tmutil", ["listbackups"], mergeErr: true, timeout: 25).out
    var r = BackupsRead()
    r.list = Array(Set(matches(out, "(\\d{4}-\\d{2}-\\d{2}-\\d{6})\\.backup$"))).sorted()
    if r.list.isEmpty {
        r.error = out.split(separator: "\n").first.map(String.init) ?? ""
        let l = out.lowercased()
        r.noAccess = l.contains("full disk access") || l.contains("acesso total")
    }
    return r
}

func listLocalSnapshots() -> [String] {
    let out = sh("/usr/bin/tmutil", ["listlocalsnapshotdates", "/"]).out
    return matches(out, "^(\\d{4}-\\d{2}-\\d{2}-\\d{6})").sorted()
}

func freeBytes() -> Int64 {
    let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
    let v = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: keys)
    if let n = v?.volumeAvailableCapacity, n > 0 { return Int64(n) }
    return v?.volumeAvailableCapacityForImportantUsage ?? 0
}

func recentErrors(since: Date, timeout: Double = 30) -> [String] {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX")
    let out = sh("/usr/bin/log", ["show", "--predicate", "subsystem == \"com.apple.TimeMachine\"",
                                  "--start", f.string(from: since), "--style", "compact"], timeout: timeout).out
    let keys = ["error", "fail", "cancel", "unable"]
    let lines = out.split(separator: "\n").map(String.init).filter { l in keys.contains { l.lowercased().contains($0) } }
    return Array(lines.suffix(8))
}

/// "Network" ou "Local" (disco conectado)
func readDestinationKind() -> String {
    let out = sh("/usr/bin/tmutil", ["destinationinfo"]).out
    for line in out.split(separator: "\n") {
        let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, parts[0] == "Kind" { return parts[1] }
    }
    return ""
}

// MARK: - Modo turbo

func turboIsOn() -> Bool {
    sh("/usr/sbin/sysctl", ["-n", "debug.lowpri_throttle_enabled"]).out
        .trimmingCharacters(in: .whitespacesAndNewlines) == "0"
}
/// Desliga o limite e deixa um processo que religa sozinho quando o backup terminar.
let turboOnCommand = "/usr/sbin/sysctl debug.lowpri_throttle_enabled=0; nohup /bin/sh -c 'sleep 120; while /usr/bin/tmutil status | /usr/bin/grep -q \"Running = 1\"; do sleep 30; done; /usr/sbin/sysctl debug.lowpri_throttle_enabled=1' >/dev/null 2>&1 &"
let turboOffCommand = "/usr/sbin/sysctl debug.lowpri_throttle_enabled=1"

// MARK: - Energia


struct PowerSource: Sendable, Equatable {
    var onAC = true
    var batteryPercent: Int?      // nil em Macs sem bateria
    var charging = false
}

func readPowerSource() -> PowerSource {
    let out = sh("/usr/bin/pmset", ["-g", "batt"], timeout: 10).out
    var s = PowerSource()
    s.onAC = !out.contains("'Battery Power'")
    if let p = matches(out, "(\\d+)%").first { s.batteryPercent = Int(p) }
    let l = out.lowercased()
    s.charging = l.contains("; charging") || l.contains("charged")
    return s
}

// MARK: - Rede

struct NetInfo: Sendable, Equatable {
    var iface: String?
    var wifi: Bool?
}

func readNetwork() -> NetInfo {
    let out = sh("/sbin/route", ["-n", "get", "default"]).out
    guard let iface = matches(out, "interface:\\s*(\\S+)").first else { return NetInfo() }
    let hw = sh("/usr/sbin/networksetup", ["-listallhardwareports"]).out
    var port = ""
    var wifi: Bool?
    for raw in hw.split(separator: "\n") {
        let line = String(raw)
        if line.hasPrefix("Hardware Port:") {
            port = line.replacingOccurrences(of: "Hardware Port:", with: "").trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("Device:"),
                  line.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces) == iface {
            let p = port.lowercased()
            wifi = p.contains("wi-fi") || p.contains("airport") || p.contains("wlan")
        }
    }
    return NetInfo(iface: iface, wifi: wifi)
}

/// Bytes enviados pela interface (contador de 32 bits do sistema; o chamador trata a virada)
func interfaceOutBytes(_ name: String) -> UInt64? {
    var ifap: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifap) == 0, let first = ifap else { return nil }
    defer { freeifaddrs(ifap) }
    var p: UnsafeMutablePointer<ifaddrs>? = first
    while let cur = p {
        let ifa = cur.pointee
        if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
           String(cString: ifa.ifa_name) == name, let data = ifa.ifa_data {
            return UInt64(data.assumingMemoryBound(to: if_data.self).pointee.ifi_obytes)
        }
        p = ifa.ifa_next
    }
    return nil
}

/// Espaço livre no destino montado (em bytes), via df
func destinationFree(_ mountPoint: String) -> Int64? {
    let out = sh("/bin/df", ["-k", mountPoint], timeout: 10).out
    let lines = out.split(separator: "\n")
    guard lines.count >= 2 else { return nil }
    let f = lines[1].split(whereSeparator: { $0 == " " || $0 == "\t" })
    guard f.count >= 4, let kb = Int64(f[3]) else { return nil }
    return kb * 1024
}

/// Texto de diagnóstico para suporte / issues no GitHub (sem senhas; usuário do destino mascarado)
func collectDiagnostics(appVersion: String, backups: [String], noAccess: Bool) -> String {
    func section(_ title: String, _ body: String) -> String {
        "### \(title)\n```\n\(body.trimmingCharacters(in: .whitespacesAndNewlines))\n```\n"
    }
    let model = sh("/usr/sbin/sysctl", ["-n", "hw.model"], timeout: 5).out
    var dest = sh("/usr/bin/tmutil", ["destinationinfo"], timeout: 15).out
    if let re = try? NSRegularExpression(pattern: "//[^@/\\s]+@") {
        dest = re.stringByReplacingMatches(in: dest, range: NSRange(dest.startIndex..., in: dest), withTemplate: "//***@")
    }
    let snaps = listLocalSnapshots()
    let errs = recentErrors(since: Date().addingTimeInterval(-1800), timeout: 15)
    var s = "## Force TM diagnostics\n\n"
    s += "- Force TM: \(appVersion)\n"
    s += "- macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
    s += "- Model: \(model.trimmingCharacters(in: .whitespacesAndNewlines))\n"
    s += "- Destination backups: \(backups.count) (latest: \(backups.last ?? "unknown"))\(noAccess ? " — no Full Disk Access" : "")\n"
    s += "- Local snapshots: \(snaps.count)\n"
    s += "- Free on this Mac: \(gb(freeBytes()))\n"
    s += "- Turbo: \(turboIsOn() ? "on" : "off")\n\n"
    s += section("tmutil status", sh("/usr/bin/tmutil", ["status"], timeout: 15).out)
    s += section("tmutil destinationinfo", dest)
    s += section("pmset -g batt", sh("/usr/bin/pmset", ["-g", "batt"], timeout: 5).out)
    s += section("Time Machine errors (last 30 min)", errs.isEmpty ? "(none)" : errs.joined(separator: "\n"))
    return s
}

func isNewer(_ a: String, than b: String) -> Bool {
    let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
    for i in 0..<max(x.count, y.count) {
        let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
        if l != r { return l > r }
    }
    return false
}

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

// MARK: - Varredura de arquivos

private let sizeKeys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey]

func eachFile(_ root: URL, _ body: (URL, Int64, Date) -> Void) {
    guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: sizeKeys) else { return }
    for case let u as URL in en {
        guard let v = try? u.resourceValues(forKeys: Set(sizeKeys)), v.isRegularFile == true else { continue }
        body(u, Int64(v.totalFileAllocatedSize ?? v.fileSize ?? 0), v.contentModificationDate ?? .distantPast)
    }
}

func dirSize(_ root: URL) -> Int64 {
    var total: Int64 = 0
    eachFile(root) { _, size, _ in total += size }
    return total
}

func removeEmptyDirs(under root: URL) {
    guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return }
    var dirs: [URL] = []
    for case let u as URL in en where (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { dirs.append(u) }
    for d in dirs.sorted(by: { $0.path.count > $1.path.count }) {
        if (try? FileManager.default.contentsOfDirectory(atPath: d.path).isEmpty) == true { try? FileManager.default.removeItem(at: d) }
    }
}

let home = FileManager.default.homeDirectoryForCurrentUser

// MARK: - WhatsApp (genérico: detecta as pastas de mídia do usuário atual)

let waBundleIDs = ["net.whatsapp.WhatsApp", "desktop.WhatsApp"]
let waMediaCandidates = [
    "Library/Group Containers/group.net.whatsapp.WhatsApp.shared/Message/Media",          // app nativo atual
    "Library/Containers/desktop.WhatsApp/Data/Library/Application Support/WhatsApp/Cache", // versão antiga (Electron, App Store)
    "Library/Application Support/WhatsApp/Cache",                                          // versão antiga (Electron, site)
]

func waRoots() -> [URL] {
    waMediaCandidates.map { home.appendingPathComponent($0) }.filter {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir) && isDir.boolValue
    }
}

struct WAScan: Sendable {
    var found = false
    var bytes: Int64 = 0
    var count = 0
    var selBytes: Int64 = 0
    var selCount = 0
}

func waScan(days: Int) -> WAScan {
    let roots = waRoots()
    var s = WAScan()
    s.found = !roots.isEmpty
    let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
    for root in roots {
        eachFile(root) { _, size, date in
            s.bytes += size; s.count += 1
            if days == 0 || date < cutoff { s.selBytes += size; s.selCount += 1 }
        }
    }
    return s
}

func waClean(days: Int) -> (count: Int, bytes: Int64) {
    let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
    var count = 0
    var bytes: Int64 = 0
    for root in waRoots() {
        var victims: [(URL, Int64)] = []
        eachFile(root) { u, size, date in if days == 0 || date < cutoff { victims.append((u, size)) } }
        for (u, size) in victims where (try? FileManager.default.removeItem(at: u)) != nil { count += 1; bytes += size }
        removeEmptyDirs(under: root)
    }
    return (count, bytes)
}

// MARK: - Caches

struct CacheDef: Sendable {
    let key: String
    let paths: [String]
    let browser: Bool
}

let cacheDefs: [CacheDef] = [
    CacheDef(key: "cGradle", paths: [".gradle/caches", ".gradle/wrapper", ".gradle/daemon"], browser: false),
    CacheDef(key: "cHF", paths: [".cache/huggingface"], browser: false),
    CacheDef(key: "cEdge", paths: ["Library/Caches/Microsoft Edge"], browser: true),
    CacheDef(key: "cChrome", paths: ["Library/Caches/Google/Chrome"], browser: true),
    CacheDef(key: "cBrave", paths: ["Library/Caches/BraveSoftware"], browser: true),
    CacheDef(key: "cFirefox", paths: ["Library/Caches/Firefox"], browser: true),
    CacheDef(key: "cBrew", paths: ["Library/Caches/Homebrew"], browser: false),
    CacheDef(key: "cNpm", paths: [".npm/_cacache"], browser: false),
    CacheDef(key: "cPip", paths: ["Library/Caches/pip"], browser: false),
    CacheDef(key: "cYarn", paths: ["Library/Caches/Yarn"], browser: false),
    CacheDef(key: "cPods", paths: ["Library/Caches/CocoaPods"], browser: false),
    CacheDef(key: "cDerived", paths: ["Library/Developer/Xcode/DerivedData"], browser: false),
    CacheDef(key: "cDevSupport", paths: ["Library/Developer/Xcode/iOS DeviceSupport"], browser: false),
]

struct CacheItem: Identifiable, Sendable {
    let id: String          // chave do texto (ex.: "cGradle")
    let paths: [String]
    let bytes: Int64
    let browser: Bool
}

/// Só lista caches com mais de 50 MB
func scanCaches() -> [CacheItem] {
    var items: [CacheItem] = []
    for def in cacheDefs {
        var total: Int64 = 0
        for p in def.paths {
            let u = home.appendingPathComponent(p)
            if FileManager.default.fileExists(atPath: u.path) { total += dirSize(u) }
        }
        if total > 50_000_000 { items.append(CacheItem(id: def.key, paths: def.paths, bytes: total, browser: def.browser)) }
    }
    return items.sorted { $0.bytes > $1.bytes }
}

func deleteCaches(_ items: [CacheItem]) -> Int64 {
    var freed: Int64 = 0
    for item in items {
        for p in item.paths {
            let u = home.appendingPathComponent(p)
            guard FileManager.default.fileExists(atPath: u.path) else { continue }
            let size = dirSize(u)
            if (try? FileManager.default.removeItem(at: u)) != nil { freed += size }
        }
    }
    return freed
}

// MARK: - Histórico

enum HistoryKind: Codable {
    case backupOK(stamp: String, sent: Double?, count: Int, duration: Double? = nil)
    case backupFail(lastGood: String?)
    case stopped
    case startFail
    case snapshots(count: Int)
    case whatsapp(files: Int, bytes: Int64)
    case cache(bytes: Int64)
}

struct HistoryEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let kind: HistoryKind
}

func historyURL() -> URL {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Force TM")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("history.json")
}

func loadHistory() -> [HistoryEntry] {
    guard let data = try? Data(contentsOf: historyURL()) else { return [] }
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    return (try? dec.decode([HistoryEntry].self, from: data)) ?? []
}

func saveHistory(_ h: [HistoryEntry]) {
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    if let data = try? enc.encode(h) { try? data.write(to: historyURL()) }
}

func appendLog(_ line: String) {
    let url = home.appendingPathComponent("Library/Logs/force-tm.log")
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let data = Data("\(f.string(from: Date())) \(line)\n".utf8)
    if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); try? h.close() }
    else { try? data.write(to: url) }
}

func notify(_ title: String, _ text: String, sound: String) {
    let esc = { (s: String) in s.replacingOccurrences(of: "\"", with: "'") }
    sh("/usr/bin/osascript", ["-e", "display notification \"\(esc(text))\" with title \"\(esc(title))\" sound name \"\(sound)\""])
}

// MARK: - Formatação

let stampFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd-HHmmss"; f.locale = Locale(identifier: "en_US_POSIX"); return f
}()
func stampDate(_ s: String) -> Date? { stampFmt.date(from: s) }
func pretty(_ s: String) -> String {
    guard let d = stampDate(s) else { return s }
    let f = DateFormatter(); f.locale = appLocale()
    f.dateFormat = currentLang == "pt" ? "dd/MM/yyyy 'às' HH:mm" : currentLang == "es" ? "dd/MM/yyyy 'a las' HH:mm" : "MMM d, yyyy 'at' h:mm a"
    return f.string(from: d)
}
func dateText(_ d: Date) -> String {
    let f = DateFormatter(); f.locale = appLocale(); f.dateStyle = .medium; f.timeStyle = .short
    return f.string(from: d)
}
func daysAgo(_ s: String) -> Int? {
    guard let d = stampDate(s) else { return nil }
    let c = Calendar.current
    return c.dateComponents([.day], from: c.startOfDay(for: d), to: c.startOfDay(for: Date())).day
}
func agoText(_ n: Int?) -> String {
    guard let n else { return "" }
    return n == 0 ? L("today") : n == 1 ? L("yesterday") : Lf("daysAgo", n)
}
func gb(_ b: Double?) -> String {
    guard let b else { return "—" }
    return String(format: "%.1f GB", locale: appLocale(), b / 1e9)
}
func gb(_ b: Int64) -> String { gb(Double(b)) }
func mbps(_ b: Double?) -> String {
    guard let b else { return "—" }
    return String(format: "%.1f MB/s", locale: appLocale(), b / 1e6)
}
func pct(_ p: Double?) -> String {
    guard let p else { return "—" }
    return String(format: "%.1f%%", locale: appLocale(), p * 100)
}
func durationText(_ s: Double) -> String {
    let t = Int(s), h = t / 3600, m = (t % 3600) / 60
    return h > 0 ? "\(h)h\(String(format: "%02d", m))" : m > 0 ? "\(m) min" : "< 1 min"
}

func elapsedText(since d: Date) -> String {
    let t = Int(Date().timeIntervalSince(d)), h = t / 3600, m = (t % 3600) / 60
    return h > 0 ? "\(h)h\(String(format: "%02d", m))" : m > 0 ? "\(m) min" : "< 1 min"
}

func hms(_ s: Double?) -> String {
    guard let s, s >= 0 else { return L("calculating") }
    let t = Int(s), h = t / 3600, m = (t % 3600) / 60
    return h > 0 ? "\(h)h\(String(format: "%02d", m))" : m > 0 ? "\(m) min" : "< 1 min"
}
