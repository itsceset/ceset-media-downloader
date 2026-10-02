import AppKit
import Foundation

enum DownloadFormat: String, CaseIterable, Identifiable, Sendable {
    case video1080 = "1080p"
    case video720 = "720p"
    case video480 = "480p"
    case audioMP3 = "MP3"

    var id: Self { self }

    var title: String {
        switch self {
        case .video1080: "Video · 1080p"
        case .video720: "Video · 720p"
        case .video480: "Video · 480p"
        case .audioMP3: "Ses · MP3 320 kbps"
        }
    }

    var shortTitle: String { rawValue }
    var isAudio: Bool { self == .audioMP3 }

    fileprivate var maximumHeight: Int? {
        switch self {
        case .video1080: 1080
        case .video720: 720
        case .video480: 480
        case .audioMP3: nil
        }
    }
}

enum DownloadState: Equatable, Sendable {
    case idle
    case preparing
    case downloading
    case processing
    case completed(URL)
    case failed(String)
    case cancelled
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published var urlText = ""
    @Published var selectedFormat: DownloadFormat = .video1080
    @Published private(set) var state: DownloadState = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var speed = "—"
    @Published private(set) var eta = "—"
    @Published private(set) var mediaTitle = "Yeni indirme"
    @Published private(set) var outputDirectory: URL?
    @Published private(set) var cookiesFileURL: URL?
    @Published private(set) var browserProfileURL: URL?
    @Published private(set) var toolStatus = ToolStatus.discover()

    private var downloadTask: Task<Void, Never>?
    private var processSession: ProcessSession?
    private var isAccessingSecurityScopedDirectory = false
    private var isAccessingSecurityScopedCookiesFile = false
    private var isAccessingSecurityScopedBrowserProfile = false

    private static let bookmarkKey = "outputDirectoryBookmark"
    private static let cookiesBookmarkKey = "cookiesFileBookmark"
    private static let browserProfileBookmarkKey = "browserProfileBookmark"

    init() {
        restoreOutputDirectory()
        restoreCookiesFile()
        restoreBrowserProfile()
    }

    deinit {
        downloadTask?.cancel()
        processSession?.terminate()
    }

    var isDownloading: Bool {
        switch state {
        case .preparing, .downloading, .processing: true
        default: false
        }
    }

    var canStart: Bool {
        !isDownloading && validatedURL != nil && outputDirectory != nil && toolStatus.isReady
    }

    var statusTitle: String {
        switch state {
        case .idle: "Başlamaya hazır"
        case .preparing: "Medya bilgileri alınıyor"
        case .downloading: "İndiriliyor"
        case .processing: "Dosya işleniyor"
        case .completed: "İndirme tamamlandı"
        case .failed: "İndirme başarısız"
        case .cancelled: "İndirme iptal edildi"
        }
    }

    var statusDetail: String {
        switch state {
        case .idle:
            if outputDirectory == nil { return "Başlamak için bir çıktı klasörü seçin." }
            if !toolStatus.isReady { return toolStatus.missingToolsDescription }
            return "Bir medya bağlantısı yapıştırın ve formatı seçin."
        case .preparing: return "Kaynak ve kullanılabilir akışlar inceleniyor…"
        case .downloading: return "\(Int(progress * 100))%  ·  \(speed)  ·  kalan \(eta)"
        case .processing: return selectedFormat.isAudio ? "Ses 320 kbps MP3 olarak hazırlanıyor…" : "Video ve ses FFmpeg ile birleştiriliyor…"
        case .completed(let fileURL): return fileURL.lastPathComponent
        case .failed(let message): return message
        case .cancelled: return "Yarım kalan geçici dosyalar yt-dlp tarafından temizlenir."
        }
    }

    var isTikTokURL: Bool {
        guard let host = validatedURL?.host?.lowercased() else { return false }
        return host == "tiktok.com" || host.hasSuffix(".tiktok.com") || host == "vm.tiktok.com" || host == "vt.tiktok.com"
    }

    func refreshTools() {
        toolStatus = .discover()
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "İndirilenlerin Kaydedileceği Klasörü Seçin"
        panel.prompt = "Klasörü Seç"
        panel.message = "Uygulama yalnızca seçtiğiniz klasöre yazma izni alır."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let directory = panel.url else { return }
        setOutputDirectory(directory, persist: true)
    }

    func chooseCookiesFile() {
        let panel = NSOpenPanel()
        panel.title = "Netscape cookies.txt Dosyasını Seçin"
        panel.prompt = "Çerezleri Kullan"
        panel.message = "Yalnızca size ait hesaplardan dışa aktardığınız Netscape biçimindeki cookies.txt dosyasını seçin."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }
        clearBrowserProfile()
        setCookiesFile(fileURL, persist: true)
    }

    func chooseZenProfile() {
        let panel = NSOpenPanel()
        panel.title = "Zen Profil Klasörünü Seçin"
        panel.prompt = "Profili Kullan"
        panel.message = "about:profiles sayfasında ‘Kök Dizin’ olarak gösterilen klasörü seçin. Çerezler dışa aktarılmaz."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        let zenProfiles = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/zen/Profiles", isDirectory: true)
        if FileManager.default.fileExists(atPath: zenProfiles.path) {
            panel.directoryURL = zenProfiles
        }

        guard panel.runModal() == .OK, let profileURL = panel.url else { return }
        guard FileManager.default.fileExists(atPath: profileURL.appendingPathComponent("cookies.sqlite").path) else {
            state = .failed("Seçilen klasör bir Zen profili değil. Zen’de about:profiles sayfasındaki ‘Kök Dizin’ klasörünü seçin.")
            return
        }
        clearCookiesFile()
        setBrowserProfile(profileURL, persist: true)
    }

    func clearCookiesFile() {
        if isAccessingSecurityScopedCookiesFile {
            cookiesFileURL?.stopAccessingSecurityScopedResource()
        }
        isAccessingSecurityScopedCookiesFile = false
        cookiesFileURL = nil
        UserDefaults.standard.removeObject(forKey: Self.cookiesBookmarkKey)
    }

    func clearSessionAccess() {
        clearCookiesFile()
        clearBrowserProfile()
    }

    func startDownload() {
        guard !isDownloading else { return }
        guard let sourceURL = validatedURL else {
            state = .failed("Geçerli bir http veya https bağlantısı girin.")
            return
        }
        guard let outputDirectory else {
            state = .failed("Önce bir çıktı klasörü seçin.")
            return
        }

        toolStatus = .discover()
        guard let ytDLP = toolStatus.ytDLP, let ffmpeg = toolStatus.ffmpeg else {
            state = .failed(toolStatus.missingToolsDescription)
            return
        }

        resetProgress()
        state = .preparing
        let format = selectedFormat
        let arguments = makeArguments(sourceURL: sourceURL, outputDirectory: outputDirectory, format: format, ffmpeg: ffmpeg)
        let session = ProcessSession(executableURL: ytDLP, arguments: arguments)
        processSession = session

        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in session.events() {
                    guard !Task.isCancelled else { throw CancellationError() }
                    self.consume(event)
                }
                if case .completed = self.state { return }
                self.state = .completed(outputDirectory)
            } catch is CancellationError {
                self.state = .cancelled
            } catch {
                self.state = .failed(error.localizedDescription)
            }
            self.processSession = nil
            self.downloadTask = nil
        }
    }

    func cancelDownload() {
        guard isDownloading else { return }
        processSession?.terminate()
        downloadTask?.cancel()
        processSession = nil
        downloadTask = nil
        state = .cancelled
    }

    func revealCompletedFile() {
        guard case .completed(let url) = state else { return }
        if url.hasDirectoryPath {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private var validatedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }

    private func resetProgress() {
        progress = 0
        speed = "—"
        eta = "—"
        mediaTitle = "Medya hazırlanıyor"
    }

    private func consume(_ event: ProcessEvent) {
        switch event {
        case .line(let line):
            if line.hasPrefix("__CMD_TITLE__") {
                mediaTitle = String(line.dropFirst("__CMD_TITLE__".count))
            } else if line.hasPrefix("__CMD_FILE__") {
                let path = String(line.dropFirst("__CMD_FILE__".count))
                progress = 1
                state = .completed(URL(fileURLWithPath: path))
            } else if line.hasPrefix("__CMD_POSTPROCESS__") {
                state = .processing
            } else if line.hasPrefix("__CMD_PROGRESS__") {
                parseProgress(String(line.dropFirst("__CMD_PROGRESS__".count)))
            }
        }
    }

    private func parseProgress(_ payload: String) {
        let parts = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty else { return }
        let percentageText = parts[0].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        if let percentage = Double(percentageText) {
            progress = min(max(percentage / 100, 0), 1)
        }
        if parts.count > 1, !parts[1].isEmpty, parts[1] != "NA" { speed = parts[1].trimmingCharacters(in: .whitespaces) }
        if parts.count > 2, !parts[2].isEmpty, parts[2] != "NA" { eta = parts[2].trimmingCharacters(in: .whitespaces) }
        state = .downloading
    }

    private func makeArguments(sourceURL: URL, outputDirectory: URL, format: DownloadFormat, ffmpeg: URL) -> [String] {
        var arguments = [
            "--ignore-config",
            "--no-playlist",
            "--impersonate", browserProfileURL == nil ? "chrome" : "firefox",
            "--newline",
            "--progress",
            "--concurrent-fragments", "4",
            "--retries", "10",
            "--fragment-retries", "10",
            "--retry-sleep", "fragment:exp=1:20",
            "--progress-template", "download:__CMD_PROGRESS__%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "before_dl:__CMD_TITLE__%(title)s",
            "--print", "post_process:__CMD_POSTPROCESS__",
            "--print", "after_move:__CMD_FILE__%(filepath)s",
            "--ffmpeg-location", ffmpeg.deletingLastPathComponent().path,
            "--paths", outputDirectory.path,
            "--output", "%(title).180B [%(id)s].%(ext)s"
        ]

        if let browserProfileURL {
            arguments += ["--cookies-from-browser", "firefox:\(browserProfileURL.path)"]
        } else if let cookiesFileURL {
            arguments += ["--cookies", cookiesFileURL.path]
        }

        if format.isAudio {
            arguments += [
                "--format", "bestaudio/best",
                "--extract-audio",
                "--audio-format", "mp3",
                "--audio-quality", "320K",
                "--embed-metadata",
                "--embed-thumbnail"
            ]
        } else if let height = format.maximumHeight {
            // Prefer native MP4/M4A, but retain a universal fallback for sites that
            // expose only HLS/DASH or omit dimensions. `res` uses the shorter edge,
            // so 720×1280 portrait clips are correctly treated as 720p.
            let selector = "bestvideo*[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/bestvideo*+bestaudio/best"
            arguments += [
                "--format", selector,
                // H.264 + AAC is natively playable by QuickTime on every supported
                // Apple Silicon Mac. Keep resolution first, then prefer compatible
                // codecs before falling back to a site's only available stream.
                "--format-sort", "res:\(height),codec:h264:aac,ext:mp4:m4a",
                "--merge-output-format", "mp4",
                "--remux-video", "mp4",
                "--embed-metadata"
            ]
        }

        arguments.append(sourceURL.absoluteString)
        return arguments
    }

    private func restoreOutputDirectory() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            setOutputDirectory(url, persist: stale)
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        }
    }

    private func restoreCookiesFile() {
        guard let data = UserDefaults.standard.data(forKey: Self.cookiesBookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            guard FileManager.default.fileExists(atPath: url.path) else {
                clearCookiesFile()
                return
            }
            setCookiesFile(url, persist: stale)
        } catch {
            clearCookiesFile()
        }
    }

    private func restoreBrowserProfile() {
        guard let data = UserDefaults.standard.data(forKey: Self.browserProfileBookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            guard FileManager.default.fileExists(atPath: url.appendingPathComponent("cookies.sqlite").path) else {
                clearBrowserProfile()
                return
            }
            setBrowserProfile(url, persist: stale)
        } catch {
            clearBrowserProfile()
        }
    }

    private func setOutputDirectory(_ url: URL, persist: Bool) {
        if isAccessingSecurityScopedDirectory {
            outputDirectory?.stopAccessingSecurityScopedResource()
        }
        outputDirectory = url
        isAccessingSecurityScopedDirectory = url.startAccessingSecurityScopedResource()

        guard persist else { return }
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        } catch {
            state = .failed("Klasör izni kaydedilemedi: \(error.localizedDescription)")
        }
    }

    private func setCookiesFile(_ url: URL, persist: Bool) {
        if isAccessingSecurityScopedCookiesFile {
            cookiesFileURL?.stopAccessingSecurityScopedResource()
        }
        cookiesFileURL = url
        isAccessingSecurityScopedCookiesFile = url.startAccessingSecurityScopedResource()

        guard persist else { return }
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.cookiesBookmarkKey)
        } catch {
            state = .failed("Çerez dosyası izni kaydedilemedi: \(error.localizedDescription)")
        }
    }

    private func setBrowserProfile(_ url: URL, persist: Bool) {
        if isAccessingSecurityScopedBrowserProfile {
            browserProfileURL?.stopAccessingSecurityScopedResource()
        }
        browserProfileURL = url
        isAccessingSecurityScopedBrowserProfile = url.startAccessingSecurityScopedResource()

        guard persist else { return }
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.browserProfileBookmarkKey)
        } catch {
            state = .failed("Zen profil izni kaydedilemedi: \(error.localizedDescription)")
        }
    }

    private func clearBrowserProfile() {
        if isAccessingSecurityScopedBrowserProfile {
            browserProfileURL?.stopAccessingSecurityScopedResource()
        }
        isAccessingSecurityScopedBrowserProfile = false
        browserProfileURL = nil
        UserDefaults.standard.removeObject(forKey: Self.browserProfileBookmarkKey)
    }
}

struct ToolStatus: Sendable {
    let ytDLP: URL?
    let ffmpeg: URL?

    var isReady: Bool { ytDLP != nil && ffmpeg != nil }

    var missingToolsDescription: String {
        let names = [("yt-dlp", ytDLP), ("FFmpeg", ffmpeg)].compactMap { $0.1 == nil ? $0.0 : nil }
        return "Eksik araç: \(names.joined(separator: ", ")). Resources/Tools içine ARM64 çalıştırılabilir dosyayı ekleyin veya Homebrew ile kurun."
    }

    static func discover() -> ToolStatus {
        ToolStatus(
            ytDLP: locate(named: "yt-dlp"),
            ffmpeg: locate(named: "ffmpeg")
        )
    }

    private static func locate(named name: String) -> URL? {
        var candidates: [URL] = []
        if let resources = Bundle.main.resourceURL {
            if name == "yt-dlp" {
                candidates += [
                    resources.appendingPathComponent("YTDLP.bundle/yt-dlp_macos"),
                    resources.appendingPathComponent("Tools/YTDLP.bundle/yt-dlp_macos")
                ]
            }
            candidates += [
                resources.appendingPathComponent("Tools/\(name)"),
                resources.appendingPathComponent(name)
            ]
        }
        let environmentPaths = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        candidates += environmentPaths.map { URL(fileURLWithPath: $0).appendingPathComponent(name) }
        candidates += [
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)"),
            URL(fileURLWithPath: "/usr/bin/\(name)")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

private enum ProcessEvent: Sendable {
    case line(String)
}

private enum ProcessFailure: LocalizedError {
    case launch(String)
    case exited(code: Int32, details: String)

    var errorDescription: String? {
        switch self {
        case .launch(let details): "yt-dlp başlatılamadı: \(details)"
        case .exited(let code, let details):
            friendlyMessage(code: code, details: details)
        }
    }

    private func friendlyMessage(code: Int32, details: String) -> String {
        let normalized = details.lowercased()
        if normalized.contains("your ip address is blocked") || normalized.contains("blocked from accessing this post") {
            return "Platform bu IP adresinden erişimi engelledi. Farklı bir ağ veya güvenilir bir VPN ile yeniden deneyin; gerekiyorsa cookies.txt seçin."
        }
        if normalized.contains("localhost.localdomain") || normalized.contains("certificate subject name") {
            return "Bu platforma erişim ağ veya DNS sağlayıcınız tarafından yönlendiriliyor. Güvenli DNS ya da VPN etkinleştirip yeniden deneyin. Sertifika denetimi güvenlik için kapatılmadı."
        }
        if normalized.contains("login required")
            || normalized.contains("sign in")
            || normalized.contains("cookies")
            || normalized.contains("private video")
            || normalized.contains("age-restricted") {
            return "Bu içerik oturum açmayı gerektiriyor. Tarayıcınızdan Netscape biçiminde dışa aktardığınız cookies.txt dosyasını uygulamada seçip yeniden deneyin."
        }
        if normalized.contains("requested format is not available") {
            return "Bu bağlantıda indirilebilir bir video akışı bulunamadı. İçerik kaldırılmış, DRM korumalı veya oturumla sınırlandırılmış olabilir."
        }
        return details.isEmpty ? "yt-dlp \(code) koduyla sonlandı." : details
    }
}

private final class ProcessSession: @unchecked Sendable {
    private let executableURL: URL
    private let arguments: [String]
    private let lock = NSLock()
    private var process: Process?

    init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }

    func events() -> AsyncThrowingStream<ProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let pipe = Pipe()
            let accumulator = LineAccumulator { line in
                continuation.yield(.line(line))
            }

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            let toolDirectory = executableURL.deletingLastPathComponent().path
            let inheritedPath = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            process.environment = ProcessInfo.processInfo.environment.merging([
                "PYTHONUNBUFFERED": "1",
                "PATH": "\(toolDirectory):\(inheritedPath)"
            ]) { _, new in new }

            lock.withLock { self.process = process }

            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    accumulator.finish()
                } else {
                    accumulator.append(data)
                }
            }

            process.terminationHandler = { [weak self] process in
                pipe.fileHandleForReading.readabilityHandler = nil
                accumulator.finish()
                let details = accumulator.recentErrorLines.joined(separator: "\n")
                self?.lock.withLock { self?.process = nil }
                if process.terminationReason == .uncaughtSignal || process.terminationStatus == SIGTERM {
                    continuation.finish(throwing: CancellationError())
                } else if process.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: ProcessFailure.exited(code: process.terminationStatus, details: details))
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.terminate()
            }

            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                lock.withLock { self.process = nil }
                continuation.finish(throwing: ProcessFailure.launch(error.localizedDescription))
            }
        }
    }

    func terminate() {
        lock.withLock {
            guard let process, process.isRunning else { return }
            process.terminate()
        }
    }
}

private final class LineAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var errors: [String] = []
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    var recentErrorLines: [String] {
        lock.withLock { Array(errors.suffix(8)) }
    }

    func append(_ data: Data) {
        let lines: [String] = lock.withLock {
            buffer.append(data)
            var parsed: [String] = []
            while let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newline]
                buffer.removeSubrange(...newline)
                if let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                    parsed.append(line)
                    if !line.hasPrefix("__CMD_PROGRESS__") {
                        errors.append(line)
                    }
                }
            }
            return parsed
        }
        lines.forEach(onLine)
    }

    func finish() {
        let remainder: String? = lock.withLock {
            guard !buffer.isEmpty else { return nil }
            defer { buffer.removeAll() }
            return String(data: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let remainder, !remainder.isEmpty { onLine(remainder) }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
