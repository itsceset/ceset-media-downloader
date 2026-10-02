import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var manager: DownloadManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 18) {
                floatingHeader

                HStack(alignment: .top, spacing: 18) {
                    downloadWorkspace
                    activityPanel
                        .frame(width: 300)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 860, minHeight: 640)
    }

    private var floatingHeader: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                }
            .frame(width: 38, height: 38)
            .shadow(color: .black.opacity(0.16), radius: 9, y: 5)

            VStack(alignment: .leading, spacing: 1) {
                Text("Media Studio")
                    .font(.system(size: 15, weight: .semibold))
                Text("Bağlantıdan dosyaya, zahmetsizce")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                ToolBadge(name: "yt-dlp", isAvailable: manager.toolStatus.ytDLP != nil)
                ToolBadge(name: "FFmpeg", isAvailable: manager.toolStatus.ffmpeg != nil)

                Button {
                    manager.refreshTools()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(LiquidIconButtonStyle())
                .help("Araç durumunu yenile")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 58)
        .liquidGlass(cornerRadius: 22)
    }

    private var downloadWorkspace: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Yeni bir indirme başlat")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                Text("Medya bağlantısını ekleyin, istediğiniz kaliteyi seçin.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 28)

            SectionLabel(number: "1", title: "Medya bağlantısı")
            urlInput.padding(.top, 9)

            SectionLabel(number: "2", title: "Format ve kalite")
                .padding(.top, 25)
            formatSelection.padding(.top, 9)

            SectionLabel(number: "3", title: "Kayıt konumu")
                .padding(.top, 25)
            destinationPicker.padding(.top, 9)
            sessionAccess.padding(.top, 10)

            Spacer(minLength: 24)

            HStack(spacing: 12) {
                primaryAction

                if case .completed = manager.state {
                    Button {
                        manager.revealCompletedFile()
                    } label: {
                        Label("Finder’da Göster", systemImage: "folder")
                            .frame(height: 32)
                    }
                    .buttonStyle(LiquidSecondaryButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .luxuryGlassPanel(cornerRadius: 30)
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.09 : 0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 28, y: 16)
    }

    private var urlInput: some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 22)

            TextField("YouTube, Instagram, TikTok veya başka bir bağlantı", text: $manager.urlText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .onSubmit { manager.startDownload() }

            if !manager.urlText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { manager.urlText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Bağlantıyı temizle")
            }

            Button {
                if let value = NSPasteboard.general.string(forType: .string) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        manager.urlText = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } label: {
                Label("Yapıştır", systemImage: "doc.on.clipboard")
                    .frame(height: 28)
            }
            .buttonStyle(LiquidSecondaryButtonStyle())
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 58)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(manager.isTikTokURL ? Color.primary.opacity(0.34) : Color.primary.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .bottomLeading) {
            if manager.isTikTokURL {
                Label("Filigransız TikTok akışı önceliklendirilecek", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .offset(x: 14, y: 28)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: manager.isTikTokURL)
    }

    private var formatSelection: some View {
        HStack(spacing: 10) {
            ForEach(DownloadFormat.allCases) { format in
                QualityOption(format: format, isSelected: manager.selectedFormat == format) {
                    withAnimation(.smooth(duration: 0.3)) {
                        manager.selectedFormat = format
                    }
                }
                .disabled(manager.isDownloading)
            }
        }
    }

    private var destinationPicker: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07))
                Image(systemName: "folder.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(manager.outputDirectory?.lastPathComponent ?? "Klasör seçilmedi")
                    .font(.system(size: 13, weight: .semibold))
                Text(manager.outputDirectory?.path(percentEncoded: false) ?? "Dosyaların kaydedileceği klasörü belirleyin")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            Button("Değiştir") { manager.chooseOutputDirectory() }
                .buttonStyle(LiquidSecondaryButtonStyle())
                .disabled(manager.isDownloading)
        }
        .padding(.horizontal, 13)
        .frame(height: 62)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private var sessionAccess: some View {
        HStack(spacing: 10) {
            Image(systemName: hasSessionAccess ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasSessionAccess ? "Oturum çerezleri etkin" : "Giriş gerektiren içerik")
                    .font(.system(size: 11, weight: .semibold))
                Text(sessionSourceName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if hasSessionAccess {
                Button("Kaldır") { manager.clearSessionAccess() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Button("Zen Profili") {
                manager.chooseZenProfile()
            }
            .buttonStyle(LiquidSecondaryButtonStyle())
            .disabled(manager.isDownloading)

            Button {
                manager.chooseCookiesFile()
            } label: {
                Image(systemName: "doc.text")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(LiquidIconButtonStyle())
            .disabled(manager.isDownloading)
            .help("Alternatif olarak cookies.txt seç")
        }
        .padding(.horizontal, 13)
        .frame(height: 52)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.035 : 0.025), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var hasSessionAccess: Bool {
        manager.browserProfileURL != nil || manager.cookiesFileURL != nil
    }

    private var sessionSourceName: String {
        if let profile = manager.browserProfileURL {
            return "Zen · \(profile.lastPathComponent)"
        }
        if let cookies = manager.cookiesFileURL {
            return cookies.lastPathComponent
        }
        return "Özel, yaş kısıtlı veya giriş isteyen bağlantılar için"
    }

    private var primaryAction: some View {
        Button {
            manager.isDownloading ? manager.cancelDownload() : manager.startDownload()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: manager.isDownloading ? "xmark" : "arrow.down")
                    .font(.system(size: 14, weight: .bold))
                Text(manager.isDownloading ? "İndirmeyi İptal Et" : "İndirmeyi Başlat")
                    .font(.system(size: 14, weight: .semibold))
                if !manager.isDownloading {
                    Text("⌘↩")
                        .font(.system(size: 11, weight: .medium))
                        .opacity(0.65)
                        .padding(.leading, 5)
                }
            }
            .frame(minWidth: 190)
            .frame(height: 34)
        }
        .buttonStyle(LiquidPrimaryButtonStyle(isDestructive: manager.isDownloading))
        .disabled(!manager.isDownloading && !manager.canStart)
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aktivite")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Geçerli işlem")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusOrb(state: manager.state)
            }

            ProgressOrb(progress: manager.progress, state: manager.state)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(manager.statusTitle)
                    .font(.system(size: 15, weight: .semibold))
                Text(manager.statusDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if manager.isDownloading {
                HStack(spacing: 8) {
                    MetricPill(icon: "speedometer", value: manager.speed)
                    MetricPill(icon: "clock", value: manager.eta)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider().opacity(0.6)

            VStack(alignment: .leading, spacing: 10) {
                DetailRow(icon: "film", title: "Format", value: manager.selectedFormat.title)
                DetailRow(icon: "folder", title: "Konum", value: manager.outputDirectory?.lastPathComponent ?? "Seçilmedi")
                DetailRow(icon: "person.crop.circle", title: "Oturum", value: manager.browserProfileURL != nil ? "Zen" : (manager.cookiesFileURL == nil ? "Herkese açık" : "cookies.txt"))
                DetailRow(icon: "shield.checkered", title: "İşlem", value: "Cihazınızda")
            }

            Spacer()

            Label("Medya doğrudan seçtiğiniz klasöre kaydedilir.", systemImage: "lock.shield")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
        .luxuryGlassPanel(cornerRadius: 30)
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.09 : 0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 28, y: 16)
        .animation(.smooth(duration: 0.3), value: manager.isDownloading)
    }
}

private struct AuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(white: 0.025), Color(white: 0.095), Color(white: 0.02)]
                    : [Color(white: 0.96), Color(white: 0.86), Color(white: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                Circle()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.62))
                    .frame(width: proxy.size.width * 0.55)
                    .blur(radius: 100)
                    .offset(x: proxy.size.width * 0.55, y: -proxy.size.height * 0.22)

                Circle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.055 : 0.07))
                    .frame(width: proxy.size.width * 0.5)
                    .blur(radius: 120)
                    .offset(x: -proxy.size.width * 0.2, y: proxy.size.height * 0.60)

                Circle()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.045 : 0.38))
                    .frame(width: proxy.size.width * 0.34)
                    .blur(radius: 90)
                    .offset(x: proxy.size.width * 0.28, y: proxy.size.height * 0.47)
            }
        }
        .ignoresSafeArea()
    }
}

private struct SectionLabel: View {
    let number: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 21, height: 21)
                .background(Color.primary.opacity(0.08), in: Circle())
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct QualityOption: View {
    let format: DownloadFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: format.isAudio ? "waveform" : "play.rectangle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(format.shortTitle)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(QualityButtonStyle(isSelected: isSelected))
        .accessibilityLabel(format.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct QualityButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.86))
                            : AnyShapeStyle(.thinMaterial)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.28) : Color.primary.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: isSelected ? Color.black.opacity(0.18) : .clear, radius: 12, y: 7)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.22), value: configuration.isPressed)
    }
}

private struct ProgressOrb: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double
    let state: DownloadState

    private var symbol: String {
        switch state {
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        case .cancelled: "xmark"
        default: "arrow.down"
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.07), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(progress, 0.015))
                .stroke(
                    AngularGradient(
                        colors: colorScheme == .dark
                            ? [.white.opacity(0.32), .white, .white.opacity(0.45), .white]
                            : [.black.opacity(0.24), .black, .black.opacity(0.38), .black],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.primary.opacity(0.12), radius: 8)
                .animation(.smooth(duration: 0.45), value: progress)
            Circle().fill(.ultraThinMaterial).padding(18)
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
        }
        .frame(width: 150, height: 150)
    }
}

private struct StatusOrb: View {
    let state: DownloadState

    private var color: Color {
        switch state {
        case .completed: Color.primary.opacity(0.92)
        case .failed: Color.primary.opacity(0.72)
        case .preparing, .downloading, .processing: Color.primary.opacity(0.82)
        default: Color.secondary.opacity(0.55)
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .padding(9)
            .background(color.opacity(0.12), in: Circle())
            .shadow(color: color.opacity(0.35), radius: 5)
    }
}

private struct MetricPill: View {
    let icon: String
    let value: String

    var body: some View {
        Label(value, systemImage: icon)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.045), in: Capsule())
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value).font(.system(size: 11, weight: .medium)).lineLimit(1)
        }
    }
}

private struct ToolBadge: View {
    let name: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isAvailable ? .primary : .secondary)
            Text(name).font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.primary.opacity(0.045), in: Capsule())
        .help(isAvailable ? "Kullanıma hazır" : "Bulunamadı")
    }
}

private struct LiquidGlassModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        }
    }
}

private struct LuxuryGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background(.ultraThinMaterial, in: shape)
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay { specularBorder }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { specularBorder }
        }
    }

    private var specularBorder: some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.34 : 0.90),
                    .white.opacity(0.04),
                    .white.opacity(colorScheme == .dark ? 0.16 : 0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
    }
}

private extension View {
    func liquidGlass(cornerRadius: CGFloat) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }

    func luxuryGlassPanel(cornerRadius: CGFloat) -> some View {
        modifier(LuxuryGlassPanelModifier(cornerRadius: cornerRadius))
    }
}

private struct LiquidPrimaryButtonStyle: PrimitiveButtonStyle {
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                Button(action: configuration.trigger, label: { configuration.label })
                    .buttonStyle(.glassProminent)
                    .tint(Color.primary)
                    .controlSize(.large)
            } else {
                Button(action: configuration.trigger, label: { configuration.label })
                    .buttonStyle(.borderedProminent)
                    .tint(Color.primary)
                    .controlSize(.large)
            }
        }
    }
}

private struct LiquidSecondaryButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                Button(action: configuration.trigger, label: { configuration.label }).buttonStyle(.glass)
            } else {
                Button(action: configuration.trigger, label: { configuration.label }).buttonStyle(.bordered)
            }
        }
        .controlSize(.regular)
    }
}

private struct LiquidIconButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                Button(action: configuration.trigger, label: { configuration.label }).buttonStyle(.glass)
            } else {
                Button(action: configuration.trigger, label: { configuration.label })
                    .buttonStyle(.borderless)
                    .background(.thinMaterial, in: Circle())
            }
        }
        .buttonBorderShape(.circle)
    }
}
