import SwiftUI

@main
struct CesetMediaDownloaderApp: App {
    @StateObject private var downloadManager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(downloadManager)
                .frame(minWidth: 820, minHeight: 620)
        }
        .defaultSize(width: 980, height: 720)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("İndirme") {
                Button("İndirmeyi Başlat") {
                    downloadManager.startDownload()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!downloadManager.canStart)

                Button("İndirmeyi İptal Et") {
                    downloadManager.cancelDownload()
                }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!downloadManager.isDownloading)
            }
        }
    }
}
