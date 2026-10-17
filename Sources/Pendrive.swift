// Backeddy — criar o pendrive do Backeddy Server (baixa a imagem da última versão e grava no pendrive)
import SwiftUI
import AppKit
import CryptoKit
import Compression
import Darwin

// MARK: - Discos externos

struct ExternalDisk: Identifiable, Equatable, Sendable {
    let id: String          // disk4
    let name: String        // "SanDisk Ultra"
    let size: Int64
    let volumes: [String]   // nomes dos volumes, para a pessoa reconhecer o pendrive
    var big: Bool { size > 256_000_000_000 }
}

/// Plist de um comando do diskutil
private func diskutilPlist(_ args: [String]) -> [String: Any]? {
    let r = sh("/usr/sbin/diskutil", args + [], timeout: 20)
    guard let data = r.out.data(using: .utf8),
          let obj = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return nil }
    return obj as? [String: Any]
}

/// Discos físicos que estão por trás de um volume montado (APFS fica num disco "sintetizado")
private func physicalDisks(ofMount mount: String) -> Set<String> {
    guard let info = diskutilPlist(["info", "-plist", mount]) else { return [] }
    var out = Set<String>()
    if let p = info["ParentWholeDisk"] as? String { out.insert(p) }
    for store in info["APFSPhysicalStores"] as? [[String: Any]] ?? [] {
        if let s = store["APFSPhysicalStore"] as? String,
           let whole = s.range(of: "^disk\\d+", options: .regularExpression) { out.insert(String(s[whole])) }
    }
    return out
}

/// Discos de destino do Time Machine conectados (nunca aparecem na lista)
private func timeMachineDisks() -> Set<String> {
    let r = sh("/usr/bin/tmutil", ["destinationinfo", "-X"])
    guard let data = r.out.data(using: .utf8),
          let obj = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [] }
    var out = Set<String>()
    for d in obj["Destinations"] as? [[String: Any]] ?? [] {
        if let mp = d["MountPoint"] as? String { out.formUnion(physicalDisks(ofMount: mp)) }
    }
    return out
}

/// Pendrives e discos externos onde dá para gravar. Nunca lista discos internos, o disco do sistema
/// nem os do Time Machine.
func listExternalDisks() -> [ExternalDisk] {
    // "physical" e não "external": alguns pendrives e leitores de SD se declaram internos
    guard let list = diskutilPlist(["list", "-plist", "physical"]) else { return [] }
    let tm = timeMachineDisks()
    let system = physicalDisks(ofMount: "/")
    var disks: [ExternalDisk] = []
    for entry in list["AllDisksAndPartitions"] as? [[String: Any]] ?? [] {
        guard let id = entry["DeviceIdentifier"] as? String, !tm.contains(id), !system.contains(id),
              let info = diskutilPlist(["info", "-plist", id]) else { continue }
        let bus = info["BusProtocol"] as? String ?? ""
        if (info["VirtualOrPhysical"] as? String) == "Virtual" || bus == "Disk Image" { continue }
        let removable = (info["Removable"] as? Bool) == true || (info["RemovableMedia"] as? Bool) == true
            || (info["Ejectable"] as? Bool) == true || ["USB", "Secure Digital", "SD"].contains(bus)
        if (info["Internal"] as? Bool) == true && !removable { continue }
        let size = Int64(num(info["TotalSize"]) ?? num(info["Size"]) ?? 0)
        guard size > 0 else { continue }
        let name = (info["MediaName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (info["IORegistryEntryName"] as? String) ?? id
        var vols: [String] = []
        for p in entry["Partitions"] as? [[String: Any]] ?? [] {
            if let v = p["VolumeName"] as? String, !v.isEmpty { vols.append(v) }
        }
        for v in entry["APFSVolumes"] as? [[String: Any]] ?? [] {
            if let n = v["VolumeName"] as? String, !n.isEmpty { vols.append(n) }
        }
        disks.append(ExternalDisk(id: id, name: name.trimmingCharacters(in: .whitespaces), size: size, volumes: vols))
    }
    return disks
}

func humanSize(_ b: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: b, countStyle: .decimal)
}

// MARK: - Download da imagem (última release do GitHub)

struct ServerImage: Sendable { let version: String; let url: URL; let sha256: String; let size: Int64 }

enum PendriveError: LocalizedError {
    case msg(String)
    var errorDescription: String? { if case .msg(let m) = self { return m }; return nil }
}

/// Descobre a imagem do pendrive (.img.xz) e o SHA256 dela na última versão publicada
func latestServerImage() async throws -> ServerImage {
    var req = URLRequest(url: URL(string: "https://api.github.com/repos/BackEddy/server/releases/latest")!)
    req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    req.timeoutInterval = 20
    let (data, _) = try await URLSession.shared.data(for: req)
    guard let rel = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let assets = rel["assets"] as? [[String: Any]] else { throw PendriveError.msg(L("pdErrRelease")) }
    let tag = (rel["tag_name"] as? String ?? "").replacingOccurrences(of: "v", with: "")
    func asset(_ test: (String) -> Bool) -> [String: Any]? { assets.first { test($0["name"] as? String ?? "") } }
    guard let img = asset({ $0.range(of: "^backeddy-server-[0-9.]+\\.img\\.xz$", options: .regularExpression) != nil }),
          let name = img["name"] as? String,
          let imgURL = (img["browser_download_url"] as? String).flatMap(URL.init(string:)),
          let sums = asset({ $0 == "SHA256SUMS" }),
          let sumsURL = (sums["browser_download_url"] as? String).flatMap(URL.init(string:)) else {
        throw PendriveError.msg(L("pdErrRelease"))
    }
    let (sumData, _) = try await URLSession.shared.data(from: sumsURL)
    let line = String(decoding: sumData, as: UTF8.self).split(separator: "\n").first { $0.hasSuffix(name) }
    guard let sha = line?.split(separator: " ").first.map(String.init), sha.count == 64 else {
        throw PendriveError.msg(L("pdErrRelease"))
    }
    return ServerImage(version: tag, url: imgURL, sha256: sha.lowercased(), size: Int64(num(img["size"]) ?? 0))
}

/// SHA256 de um arquivo grande, em pedaços, informando o progresso (0…1)
func sha256File(_ url: URL, progress: @Sendable (Double) -> Void) throws -> String {
    let h = try FileHandle(forReadingFrom: url)
    defer { try? h.close() }
    let total = Double((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 1)
    var hasher = SHA256(), done = 0.0
    while let chunk = try h.read(upToCount: 8 << 20), !chunk.isEmpty {
        hasher.update(data: chunk); done += Double(chunk.count)
        progress(done / max(total, 1))
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

/// Baixa um arquivo grande com progresso. As funções de retorno chegam na thread principal.
final class FileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var session: URLSession?
    private let dest: URL
    private let onProgress: (Int64, Int64) -> Void
    private let onDone: (Error?) -> Void

    init(url: URL, to dest: URL, progress: @escaping (Int64, Int64) -> Void, done: @escaping (Error?) -> Void) {
        self.dest = dest; onProgress = progress; onDone = done
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        session?.downloadTask(with: url).resume()
    }
    func cancel() { session?.invalidateAndCancel() }

    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async { self.onProgress(totalBytesWritten, totalBytesExpectedToWrite) }
    }
    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // o arquivo temporário some quando esta função termina: move já
        let fm = FileManager.default
        try? fm.removeItem(at: dest)
        do { try fm.moveItem(at: location, to: dest) } catch { DispatchQueue.main.async { self.onDone(error) }; return }
    }
    func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let e = error as NSError?, e.code == NSURLErrorCancelled { return }
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 200
        let err: Error? = error ?? (status >= 400 ? PendriveError.msg("HTTP \(status)") : nil)
        DispatchQueue.main.async { self.onDone(err) }
        s.finishTasksAndInvalidate()
    }
}

// MARK: - Gravação no pendrive

/// Recebe o descritor de arquivo que o authopen manda pelo socket (SCM_RIGHTS). -1 se não veio.
private func receiveFD(_ sock: Int32) -> Int32 {
    let dataLen = 256, ctrlLen = 64
    let data = UnsafeMutableRawPointer.allocate(byteCount: dataLen, alignment: 8)
    let ctrl = UnsafeMutableRawPointer.allocate(byteCount: ctrlLen, alignment: 8)
    defer { data.deallocate(); ctrl.deallocate() }
    memset(ctrl, 0, ctrlLen)
    var iov = iovec(iov_base: data, iov_len: dataLen)
    return withUnsafeMutablePointer(to: &iov) { iovp -> Int32 in
        var msg = msghdr()
        msg.msg_iov = iovp
        msg.msg_iovlen = 1
        msg.msg_control = ctrl
        msg.msg_controllen = socklen_t(ctrlLen)
        guard recvmsg(sock, &msg, 0) > 0, msg.msg_controllen >= 16 else { return -1 }
        // struct cmsghdr { socklen_t len; int level; int type; } e o dado logo depois (alinhado a 4)
        let level = ctrl.load(fromByteOffset: 4, as: Int32.self)
        let type = ctrl.load(fromByteOffset: 8, as: Int32.self)
        guard level == SOL_SOCKET, type == SCM_RIGHTS else { return -1 }
        return ctrl.load(fromByteOffset: 12, as: Int32.self)
    }
}

/// Abre o disco para escrita com a senha de administrador, pelo authopen do próprio macOS
/// (o mesmo jeito do balenaEtcher). Devolve nil se a pessoa cancelar.
func openDiskForWriting(_ rawDevice: String) throws -> Int32? {
    var sv: [Int32] = [0, 0]
    guard socketpair(AF_UNIX, SOCK_STREAM, 0, &sv) == 0 else { throw PendriveError.msg("socketpair: \(String(cString: strerror(errno)))") }
    defer { close(sv[0]) }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/libexec/authopen")
    p.arguments = ["-stdoutpipe", "-o", String(O_RDWR), rawDevice]
    p.standardOutput = FileHandle(fileDescriptor: sv[1], closeOnDealloc: false)
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { close(sv[1]); throw error }
    close(sv[1])   // o filho tem a cópia dele; assim o recvmsg vê o fim se o authopen sair sem mandar nada
    let fd = receiveFD(sv[0])
    p.waitUntilExit()
    return fd >= 0 ? fd : nil
}

/// Descompacta o .img.xz e grava direto no disco, em blocos alinhados. progress: 0…1
func writeImage(_ xz: URL, to fd: Int32, progress: @Sendable (Double) -> Void) throws {
    defer { close(fd) }
    guard let input = InputStream(url: xz) else { throw PendriveError.msg("xz") }
    input.open(); defer { input.close() }
    let fileSize = Double((try? FileManager.default.attributesOfItem(atPath: xz.path)[.size] as? NSNumber)?.int64Value ?? 1)
    let inSize = 1 << 20, outSize = 8 << 20
    let inBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: inSize)
    defer { inBuf.deallocate() }
    var raw: UnsafeMutableRawPointer?
    guard posix_memalign(&raw, 16384, outSize) == 0, let outRaw = raw else { throw PendriveError.msg("memória") }
    defer { free(outRaw) }
    let outBuf = outRaw.assumingMemoryBound(to: UInt8.self)

    func writeAll(_ count: Int) throws {
        var off = 0
        while off < count {
            let n = Darwin.write(fd, outBuf + off, count - off)
            if n < 0 {
                if errno == EINTR { continue }
                throw PendriveError.msg(Lf("pdErrWrite", String(cString: strerror(errno))))
            }
            off += n
        }
    }

    var stream = compression_stream(dst_ptr: outBuf, dst_size: outSize, src_ptr: UnsafePointer(inBuf), src_size: 0, state: nil)
    guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZMA) == COMPRESSION_STATUS_OK else {
        throw PendriveError.msg("xz init")
    }
    defer { compression_stream_destroy(&stream) }
    var readTotal = 0.0, eof = false, lastPct = -1
    while true {
        if stream.src_size == 0 && !eof {
            let n = input.read(inBuf, maxLength: inSize)
            if n < 0 { throw PendriveError.msg(input.streamError?.localizedDescription ?? "leitura") }
            if n == 0 { eof = true } else { stream.src_ptr = UnsafePointer(inBuf); stream.src_size = n; readTotal += Double(n) }
        }
        let st = compression_stream_process(&stream, eof ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0)
        if st == COMPRESSION_STATUS_ERROR { throw PendriveError.msg(L("pdErrSha")) }
        let produced = outSize - stream.dst_size
        if stream.dst_size == 0 || (st == COMPRESSION_STATUS_END && produced > 0) {
            // disco "cru": só aceita múltiplos de 512 bytes; completa o último bloco com zeros
            let padded = (produced + 511) / 512 * 512
            if padded > produced { memset(outBuf + produced, 0, padded - produced) }
            try writeAll(padded)
            stream.dst_ptr = outBuf; stream.dst_size = outSize
        }
        let pct = Int(100 * readTotal / max(fileSize, 1))
        if pct != lastPct { lastPct = pct; progress(min(1, readTotal / max(fileSize, 1))) }
        if st == COMPRESSION_STATUS_END { break }
    }
    _ = fsync(fd)
}

let pendriveCache: URL = {
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("br.com.backeddy.mac/pendrive", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()

// MARK: - Modelo

let minPendrive: Int64 = 4_000_000_000

/// Instalador da máquina virtual para Windows (sempre o da última versão do servidor)
let windowsInstallerURL = URL(string: "https://github.com/BackEddy/server/releases/latest/download/Instalar-Backeddy.exe")!

/// Quanto este Mac ocupa no disco
func macUsedBytes() -> Int64 {
    let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
    guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys), let total = v.volumeTotalCapacity else { return 0 }
    return max(0, Int64(total) - (v.volumeAvailableCapacityForImportantUsage ?? 0))
}

/// Espaço sugerido para os backups deste Mac: o dobro do que ele ocupa (cópia + histórico), em centenas de GB
func suggestedBackupSize(_ used: Int64) -> Int64 {
    let step: Int64 = 100_000_000_000
    let double = max(used * 2, step)
    return (double + step - 1) / step * step
}

@MainActor
final class PendriveModel: ObservableObject {
    enum Phase: Equatable { case start, windows, choose, download, confirm, write, done, failed(String) }
    @Published var phase: Phase = .choose
    @Published var disks: [ExternalDisk] = []
    @Published var selected: String?
    @Published var scanning = false
    // download
    @Published var image: ServerImage?
    @Published var imageFile: URL?          // .img.xz conferido, pronto para gravar
    @Published var got: Int64 = 0
    @Published var total: Int64 = 0
    @Published var checking: Double?        // conferindo o SHA256 (0…1)
    @Published var writing: Double?         // gravando (0…1)
    @Published var typed = ""
    @Published var doneDisk: ExternalDisk?
    private var downloader: FileDownloader?
    private var timer: Timer?

    var selectedDisk: ExternalDisk? { disks.first { $0.id == selected } }

    func start() {
        phase = .start    // a janela guarda o estado entre aberturas: sempre recomeça pela escolha
        refresh()
        // pendrive colocado ou tirado com a janela aberta
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in if self?.phase == .choose { self?.refresh() } }
        }
    }
    func stop() { timer?.invalidate(); timer = nil; cancelDownload() }

    func back() { cancelDownload(); phase = .choose }

    func cancelDownload() { downloader?.cancel(); downloader = nil; checking = nil }

    /// Baixa (ou reaproveita do cache) a imagem da última versão e confere o SHA256
    func startDownload() {
        phase = .download; got = 0; total = 0; checking = nil; image = nil; imageFile = nil
        Task {
            do {
                let img = try await latestServerImage()
                image = img; total = img.size
                let file = pendriveCache.appendingPathComponent(img.url.lastPathComponent)
                // de outra versão: apaga para não acumular
                for f in (try? FileManager.default.contentsOfDirectory(at: pendriveCache, includingPropertiesForKeys: nil)) ?? []
                where f.lastPathComponent != file.lastPathComponent { try? FileManager.default.removeItem(at: f) }
                if FileManager.default.fileExists(atPath: file.path), try await verify(file, img) {
                    imageFile = file; phase = .confirm; return
                }
                downloader = FileDownloader(url: img.url, to: file, progress: { g, t in
                    self.got = g; if t > 0 { self.total = t }
                }, done: { err in
                    guard self.phase == .download else { return }
                    self.downloader = nil
                    if let err { self.phase = .failed(err.localizedDescription); return }
                    Task {
                        do {
                            if try await self.verify(file, img) { self.imageFile = file; self.phase = .confirm }
                            else { try? FileManager.default.removeItem(at: file); self.phase = .failed(L("pdErrSha")) }
                        } catch { self.phase = .failed(error.localizedDescription) }
                    }
                })
            } catch {
                if phase == .download { phase = .failed(error.localizedDescription) }
            }
        }
    }

    var eraseConfirmed: Bool { typed.trimmingCharacters(in: .whitespaces).uppercased() == L("pdEraseWord") }

    /// Desmonta, pede a senha (authopen), grava e ejeta
    func startWrite() {
        guard let disk = selectedDisk, let file = imageFile, eraseConfirmed else { return }
        phase = .write; writing = 0
        Task {
            do {
                // o pendrive ainda está lá e é o mesmo?
                let now = await Task.detached { listExternalDisks() }.value
                guard now.contains(where: { $0.id == disk.id && $0.size == disk.size }) else { throw PendriveError.msg(L("pdErrGone")) }
                let um = await Task.detached { sh("/usr/sbin/diskutil", ["unmountDisk", "force", "/dev/\(disk.id)"], mergeErr: true, timeout: 60) }.value
                guard um.code == 0 else { throw PendriveError.msg(L("pdErrUnmount") + "\n" + um.out) }
                guard let fd = try await Task.detached(operation: { try openDiskForWriting("/dev/r\(disk.id)") }).value else {
                    writing = nil; phase = .confirm; return    // cancelou a senha
                }
                try await Task.detached {
                    try writeImage(file, to: fd) { v in DispatchQueue.main.async { self.writing = v } }
                }.value
                _ = await Task.detached { sh("/usr/sbin/diskutil", ["eject", "/dev/\(disk.id)"], timeout: 60) }.value
                writing = nil; typed = ""; doneDisk = disk; phase = .done
            } catch {
                writing = nil; phase = .failed(error.localizedDescription)
            }
        }
    }

    private func verify(_ file: URL, _ img: ServerImage) async throws -> Bool {
        checking = 0
        defer { checking = nil }
        let sha = try await Task.detached {
            try sha256File(file) { v in DispatchQueue.main.async { self.checking = v } }
        }.value
        return sha == img.sha256
    }

    func refresh() {
        guard !scanning else { return }
        scanning = true
        Task {
            let found = await Task.detached { listExternalDisks() }.value
            disks = found
            if let s = selected, !found.contains(where: { $0.id == s }) { selected = nil }
            if selected == nil, found.count == 1, found[0].size >= minPendrive { selected = found[0].id }
            scanning = false
        }
    }
}

// MARK: - Janela

struct PendriveView: View {
    @StateObject private var p = PendriveModel()
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "server.rack").font(.system(size: 30)).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("pdTitle")).font(.title3.weight(.semibold))
                    Text(L("pdSubtitle")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            switch p.phase {
            case .start: startStep
            case .windows: windowsStep
            case .choose: chooseStep
            case .download: downloadStep
            case .failed(let msg): failedStep(msg)
            case .confirm: confirmStep
            case .write: writeStep
            case .done: doneStep
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear { p.start() }
        .onDisappear { p.stop() }
    }

    // Onde o servidor vai rodar: PC dedicado (pendrive) ou máquina virtual num PC com Windows
    var startStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("pdWhere")).font(.headline)
            wayCard(icon: "pc", title: L("pdWayPC"), desc: L("pdWayPCDesc")) { p.phase = .choose }
            wayCard(icon: "macwindow.on.rectangle", title: L("pdWayVM"), desc: L("pdWayVMDesc")) { p.phase = .windows }
            Text(L("pdWayHint")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    func wayCard(icon: String, title: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).font(.system(size: 26)).frame(width: 36).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(desc).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Máquina virtual: o instalador roda no PC com Windows; daqui só mandamos o link e sugerimos o tamanho
    var windowsStep: some View {
        let used = macUsedBytes()
        let suggest = suggestedBackupSize(used)
        return VStack(alignment: .leading, spacing: 10) {
            Text(L("pdWinTitle")).font(.headline)
            md(L("pdWinStep1")).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(windowsInstallerURL.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            HStack(spacing: 8) {
                Button { copyLink() } label: { Label(copied ? L("pdWinCopied") : L("pdWinCopy"), systemImage: copied ? "checkmark" : "doc.on.doc") }
                ShareLink(item: windowsInstallerURL) { Label(L("pdWinSend"), systemImage: "square.and.arrow.up") }
                Button { NSWorkspace.shared.open(windowsInstallerURL) } label: { Label(L("pdWinDownload"), systemImage: "arrow.down.circle") }
            }
            .controlSize(.small)
            md(L("pdWinStep2")).font(.callout).fixedSize(horizontal: false, vertical: true)
            md(Lf("pdWinStep3", humanSize(suggest), humanSize(used))).font(.callout).fixedSize(horizontal: false, vertical: true)
            md(L("pdWinStep4")).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L("pdBack")) { p.phase = .start }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L("pdWinConfigure")) { openWindow(id: "tmsetup") }
                Button(L("pdClose")) { dismissWindow(id: "pendrive") }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
    }

    func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(windowsInstallerURL.absoluteString, forType: .string)
        copied = true
    }

    var chooseStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("pdChoose")).font(.headline)
            if p.disks.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(L("pdNoDisk")).font(.callout).foregroundStyle(.secondary)
                }
                .padding(.vertical, 18).frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(p.disks) { d in diskRow(d) }
                }
            }
            if let d = p.selectedDisk, d.big {
                Label(L("pdBigWarn"), systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(Color.orange).fixedSize(horizontal: false, vertical: true)
            }
            Text(L("pdHint")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("pdBack")) { p.phase = .start }.keyboardShortcut(.cancelAction)
                Button(L("pdContinue")) { p.startDownload() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(p.selectedDisk == nil)
            }
        }
    }

    var downloadStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(p.image.map { Lf("pdDownloading", $0.version) } ?? L("pdLooking")).font(.headline)
            if let c = p.checking {
                ProgressView(value: c)
                Text(L("pdChecking")).font(.caption).foregroundStyle(.secondary)
            } else if p.total > 0 {
                ProgressView(value: Double(p.got), total: Double(p.total))
                Text("\(p.got / 1_000_000) / \(p.total / 1_000_000) MB · \(Int(100 * Double(p.got) / Double(p.total)))%")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
            HStack {
                Text(L("pdCacheHint")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L("pdBack")) { p.back() }.keyboardShortcut(.cancelAction)
            }
        }
    }

    var confirmStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("pdEraseTitle"), systemImage: "exclamationmark.octagon.fill").font(.headline).foregroundStyle(Color.red)
            if let d = p.selectedDisk {
                Text("\(d.name) · \(humanSize(d.size))" + (d.volumes.isEmpty ? "" : " — " + d.volumes.joined(separator: ", ")))
                    .font(.callout.weight(.semibold))
            }
            Text(L("pdEraseMsg")).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Text(Lf("pdTypeToConfirm", L("pdEraseWord"))).font(.callout)
                TextField(L("pdEraseWord"), text: $p.typed).textFieldStyle(.roundedBorder).frame(width: 130)
                    .onSubmit { p.startWrite() }
            }
            HStack {
                if let img = p.image { Text("Backeddy Server \(img.version)").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button(L("pdBack")) { p.back() }.keyboardShortcut(.cancelAction)
                Button(L("pdWrite"), role: .destructive) { p.startWrite() }
                    .buttonStyle(.borderedProminent).tint(.red).disabled(!p.eraseConfirmed)
            }
        }
    }

    var writeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("pdWriting")).font(.headline)
            ProgressView(value: p.writing ?? 0)
            Text("\(Int(100 * (p.writing ?? 0)))% · " + L("pdWritingHint")).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    var doneStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("pdDoneTitle"), systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Color.green)
            md(L("pdDoneSteps")).font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("pdAnother")) { p.back() }
                Button(L("pdClose")) { dismissWindow(id: "pendrive") }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }
    }

    func failedStep(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("pdFailed"), systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(Color.orange)
            Text(msg).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("pdBack")) { p.back() }.keyboardShortcut(.cancelAction)
                Button(L("pdRetry")) { p.startDownload() }.buttonStyle(.borderedProminent)
            }
        }
    }

    func diskRow(_ d: ExternalDisk) -> some View {
        let tooSmall = d.size < minPendrive
        let sel = p.selected == d.id
        return Button {
            if !tooSmall { p.selected = d.id }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: sel ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(sel ? Color.accentColor : .secondary)
                Image(systemName: d.big ? "externaldrive.fill" : "mediastick").font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(d.name) · \(humanSize(d.size))").font(.callout.weight(.medium))
                    Text(tooSmall ? L("pdTooSmall") : d.volumes.isEmpty ? d.id : d.volumes.joined(separator: ", "))
                        .font(.caption).foregroundStyle(tooSmall ? Color.red : .secondary)
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
        .opacity(tooSmall ? 0.5 : 1)
    }
}

// MARK: - Textos

let SPendrive: [String: [String: String]] = [
    "pdMenu": ["pt": "Montar o Backeddy Server…", "en": "Set Up a Backeddy Server…", "es": "Montar el Backeddy Server…"],
    "pdTitle": ["pt": "Montar o Backeddy Server", "en": "Set up a Backeddy Server", "es": "Montar el Backeddy Server"],
    "pdSubtitle": ["pt": "Um servidor de backup para os Macs e PCs da casa, num computador que fica ligado.",
                   "en": "A backup server for the Macs and PCs at home, on a computer that stays on.",
                   "es": "Un servidor de backup para los Mac y PC de casa, en un ordenador que queda encendido."],
    "pdWhere": ["pt": "Onde o servidor vai rodar?", "en": "Where will the server run?", "es": "¿Dónde va a funcionar el servidor?"],
    "pdWayPC": ["pt": "Num computador só para os backups", "en": "On a computer just for backups", "es": "En un ordenador solo para los backups"],
    "pdWayPCDesc": ["pt": "Um PC ou notebook que ninguém mais usa vira o servidor. Tudo nele é apagado. É o jeito mais simples e o mais rápido, e você só precisa de um pendrive.",
                    "en": "A PC or laptop nobody uses anymore becomes the server. Everything on it is erased. It's the simplest and fastest way, and all you need is a USB drive.",
                    "es": "Un PC o portátil que ya nadie usa se convierte en el servidor. Todo lo que tiene se borra. Es la forma más simple y rápida, y solo necesitas un pendrive."],
    "pdWayVM": ["pt": "Num PC com Windows que já fica ligado", "en": "On a Windows PC that's always on", "es": "En un PC con Windows que ya queda encendido"],
    "pdWayVMDesc": ["pt": "O Windows e os arquivos continuam como estão: o servidor roda numa máquina virtual dentro dele. Precisa de espaço livre para os backups, de preferência num disco separado (conte o dobro do que os Macs e PCs ocupam), e esse PC tem que ficar ligado.",
                    "en": "Windows and its files stay as they are: the server runs in a virtual machine inside it. It needs free space for the backups, ideally on a separate disk (plan for twice what the Macs and PCs use), and the PC has to stay on.",
                    "es": "Windows y sus archivos quedan como están: el servidor funciona en una máquina virtual dentro de él. Necesita espacio libre para los backups, mejor en un disco aparte (calcula el doble de lo que ocupan los Mac y PC), y ese PC tiene que quedar encendido."],
    "pdWayHint": ["pt": "Não sabe? Se tem um PC parado, escolha o primeiro: é mais rápido e não depende do Windows.",
                  "en": "Not sure? If you have a spare PC, pick the first: it's faster and doesn't depend on Windows.",
                  "es": "¿No sabes? Si tienes un PC parado, elige el primero: es más rápido y no depende de Windows."],
    "pdWinTitle": ["pt": "Instale no PC com Windows", "en": "Install on the Windows PC", "es": "Instala en el PC con Windows"],
    "pdWinStep1": ["pt": "**1.** No PC com Windows, baixe o instalador por este link. Dica: mande o link para você mesmo (e-mail, WhatsApp) e abra lá.",
                   "en": "**1.** On the Windows PC, download the installer from this link. Tip: send the link to yourself (email, messages) and open it there.",
                   "es": "**1.** En el PC con Windows, descarga el instalador con este enlace. Consejo: envíate el enlace (correo, WhatsApp) y ábrelo allí."],
    "pdWinCopy": ["pt": "Copiar o link", "en": "Copy Link", "es": "Copiar el enlace"],
    "pdWinCopied": ["pt": "Copiado", "en": "Copied", "es": "Copiado"],
    "pdWinSend": ["pt": "Enviar o link…", "en": "Send Link…", "es": "Enviar el enlace…"],
    "pdWinDownload": ["pt": "Baixar aqui no Mac", "en": "Download on This Mac", "es": "Descargar en este Mac"],
    "pdWinStep2": ["pt": "**2.** Abra o arquivo baixado. Se o Windows avisar “O Windows protegeu o computador”, clique em **Mais informações › Executar assim mesmo**.",
                   "en": "**2.** Open the downloaded file. If Windows says “Windows protected your PC”, click **More info › Run anyway**.",
                   "es": "**2.** Abre el archivo descargado. Si Windows avisa “Windows protegió su PC”, haz clic en **Más información › Ejecutar de todas formas**."],
    "pdWinStep3": ["pt": "**3.** Escolha o disco e o tamanho dos backups: reserve pelo menos **%@** para este Mac (ele usa %@ hoje; o resto é para o histórico). Some o que os outros Macs e PCs precisarem.",
                   "en": "**3.** Choose the disk and the backup size: set aside at least **%@** for this Mac (it uses %@ today; the rest is for history). Add what the other Macs and PCs need.",
                   "es": "**3.** Elige el disco y el tamaño de los backups: reserva al menos **%@** para este Mac (hoy usa %@; el resto es para el historial). Suma lo que necesiten los otros Mac y PC."],
    "pdWinStep4": ["pt": "**4.** A instalação abre numa janela, igual à do pendrive. No fim, clique em **Ejetar pendrive** no instalador do Windows. Depois, volte aqui e use **Configurar este Mac** para ele fazer backup no servidor.",
                   "en": "**4.** The setup opens in a window, just like the USB one. At the end, click **Ejetar pendrive** (eject) in the Windows installer. Then come back here and use **Set Up This Mac** so it backs up to the server.",
                   "es": "**4.** La instalación se abre en una ventana, igual que la del pendrive. Al final, haz clic en **Ejetar pendrive** (expulsar) en el instalador de Windows. Después, vuelve aquí y usa **Configurar este Mac** para que haga backup en el servidor."],
    "pdWinConfigure": ["pt": "Configurar este Mac…", "en": "Set Up This Mac…", "es": "Configurar este Mac…"],
    "pdChoose": ["pt": "Escolha o pendrive", "en": "Choose the USB drive", "es": "Elige el pendrive"],
    "pdNoDisk": ["pt": "Coloque um pendrive de pelo menos 4 GB neste Mac.", "en": "Plug a USB drive of at least 4 GB into this Mac.",
                 "es": "Conecta un pendrive de al menos 4 GB a este Mac."],
    "pdTooSmall": ["pt": "Pequeno demais: precisa de pelo menos 4 GB", "en": "Too small: needs at least 4 GB", "es": "Demasiado pequeño: necesita al menos 4 GB"],
    "pdBigWarn": ["pt": "Isso parece um HD, não um pendrive. Tudo nele será apagado. Confira se é o disco certo.",
                  "en": "This looks like a hard drive, not a USB stick. Everything on it will be erased. Make sure it's the right disk.",
                  "es": "Esto parece un disco duro, no un pendrive. Todo lo que tenga se borrará. Comprueba que sea el disco correcto."],
    "pdHint": ["pt": "Discos do Mac e do Time Machine não aparecem aqui.", "en": "Your Mac's disks and Time Machine disks don't show up here.",
               "es": "Los discos del Mac y de Time Machine no aparecen aquí."],
    "pdLooking": ["pt": "Procurando a versão mais recente…", "en": "Looking for the latest version…", "es": "Buscando la versión más reciente…"],
    "pdDownloading": ["pt": "Baixando o Backeddy Server %@", "en": "Downloading Backeddy Server %@", "es": "Descargando Backeddy Server %@"],
    "pdChecking": ["pt": "Conferindo se o arquivo chegou inteiro…", "en": "Checking that the file arrived intact…", "es": "Comprobando que el archivo llegó completo…"],
    "pdCacheHint": ["pt": "Fica guardado: o próximo pendrive não baixa de novo.", "en": "It's kept: the next drive won't download again.",
                    "es": "Se guarda: el próximo pendrive no lo descarga de nuevo."],
    "pdFailed": ["pt": "Não deu certo", "en": "That didn't work", "es": "No funcionó"],
    "pdRetry": ["pt": "Tentar de novo", "en": "Try Again", "es": "Reintentar"],
    "pdErrRelease": ["pt": "Não encontrei a imagem do pendrive na última versão do Backeddy Server. Confira a internet e tente de novo.",
                     "en": "Couldn't find the USB image in the latest Backeddy Server release. Check your internet connection and try again.",
                     "es": "No encontré la imagen del pendrive en la última versión de Backeddy Server. Revisa la conexión y vuelve a intentarlo."],
    "pdErrSha": ["pt": "O arquivo baixado veio com defeito (a conferência não bateu). Tente de novo.",
                 "en": "The downloaded file is damaged (the check didn't match). Try again.",
                 "es": "El archivo descargado llegó dañado (la comprobación no coincide). Vuelve a intentarlo."],
    "pdEraseTitle": ["pt": "Tudo neste pendrive será apagado", "en": "Everything on this drive will be erased", "es": "Todo lo que hay en este pendrive se borrará"],
    "pdEraseMsg": ["pt": "Fotos, documentos e o que mais estiver nele somem para sempre. Confira se é o pendrive certo.",
                   "en": "Photos, documents and anything else on it will be gone for good. Make sure it's the right drive.",
                   "es": "Fotos, documentos y todo lo demás desaparecerán para siempre. Comprueba que sea el pendrive correcto."],
    "pdEraseWord": ["pt": "APAGAR", "en": "ERASE", "es": "BORRAR"],
    "pdTypeToConfirm": ["pt": "Para confirmar, digite %@:", "en": "To confirm, type %@:", "es": "Para confirmar, escribe %@:"],
    "pdWrite": ["pt": "Apagar e gravar", "en": "Erase and Write", "es": "Borrar y grabar"],
    "pdWriting": ["pt": "Gravando o pendrive…", "en": "Writing the USB drive…", "es": "Grabando el pendrive…"],
    "pdWritingHint": ["pt": "não tire o pendrive (uns 5 minutos)", "en": "don't unplug the drive (about 5 minutes)", "es": "no saques el pendrive (unos 5 minutos)"],
    "pdDoneTitle": ["pt": "Pendrive pronto! Já pode tirar.", "en": "USB drive ready! You can unplug it.", "es": "¡Pendrive listo! Ya puedes sacarlo."],
    "pdDoneSteps": ["pt": "1. Coloque o pendrive no PC que vai virar o servidor, com os discos que vão guardar os backups e o **cabo de rede** ligado.\n2. Ligue o PC e escolha o pendrive no menu de partida: geralmente **F12**, F11, F8 ou Esc logo que ele liga (depende do fabricante).\n3. Siga a tela. Leva uns 5 minutos.",
                    "en": "1. Plug the drive into the PC that will become the server, with the disks that will hold the backups and the **network cable** connected.\n2. Turn the PC on and pick the drive in the boot menu: usually **F12**, F11, F8 or Esc right after power-on (depends on the maker).\n3. Follow the screen. It takes about 5 minutes.",
                    "es": "1. Conecta el pendrive al PC que será el servidor, con los discos que guardarán los backups y el **cable de red** conectado.\n2. Enciende el PC y elige el pendrive en el menú de arranque: normalmente **F12**, F11, F8 o Esc justo al encenderlo (depende del fabricante).\n3. Sigue la pantalla. Tarda unos 5 minutos."],
    "pdAnother": ["pt": "Gravar outro", "en": "Write Another", "es": "Grabar otro"],
    "pdClose": ["pt": "Fechar", "en": "Close", "es": "Cerrar"],
    "pdErrGone": ["pt": "O pendrive foi tirado ou trocado. Coloque de novo e escolha outra vez.",
                  "en": "The drive was unplugged or swapped. Plug it back in and choose it again.",
                  "es": "Sacaron o cambiaron el pendrive. Vuelve a conectarlo y elígelo otra vez."],
    "pdErrUnmount": ["pt": "Não consegui liberar o pendrive. Feche os arquivos abertos nele e tente de novo.",
                     "en": "Couldn't release the drive. Close any files open on it and try again.",
                     "es": "No pude liberar el pendrive. Cierra los archivos abiertos en él y vuelve a intentarlo."],
    "pdErrWrite": ["pt": "Erro ao gravar no pendrive (%@). Ele pode estar com defeito.", "en": "Error writing to the drive (%@). It may be faulty.",
                   "es": "Error al grabar en el pendrive (%@). Puede estar dañado."],
    "pdBack": ["pt": "Voltar", "en": "Back", "es": "Volver"],
    "pdContinue": ["pt": "Continuar", "en": "Continue", "es": "Continuar"],
]
