# Ceset Media Downloader

Yerel çalışan, Apple Silicon için optimize edilmiş modern bir macOS medya indirme yöneticisi. SwiftUI arayüzünü, `yt-dlp` kaynak çözümlemesini ve FFmpeg medya işlemesini tek bir Sandbox uyumlu uygulamada birleştirir.

## Öne çıkanlar

- YouTube, TikTok, Instagram, Facebook ve yt-dlp tarafından desteklenen diğer birçok platform
- QuickTime uyumlu H.264 + AAC öncelikli MP4 çıktısı
- 1080p, 720p ve 480p kalite seçenekleri
- 320 kbps MP3 ses çıkarma
- Ayrı video ve ses akışlarını FFmpeg ile otomatik birleştirme
- İndirme yüzdesi, hız ve kalan süre gösterimi
- Zen Browser profili veya Netscape `cookies.txt` ile isteğe bağlı yerel oturum desteği
- Light/Dark Mode ve macOS 26 Liquid Glass; eski sürümlerde Material fallback
- Ana thread'i bloklamayan Swift Concurrency tabanlı `Process` entegrasyonu
- Apple Silicon ARM64 FFmpeg ve bağımsız yt-dlp paketleme desteği

## Gereksinimler

- Apple Silicon Mac
- macOS 14 veya üzeri
- Xcode 16 veya üzeri

## Çalıştırma

1. `CesetMediaDownloader.xcodeproj` dosyasını Xcode ile açın.
2. Terminal'de proje dizinine girip `./scripts/bootstrap-tools.sh` komutunu çalıştırın.
3. Target → Signing & Capabilities bölümünden kendi takımınızı seçin.
4. App Sandbox altında şu izinlerin açık olduğunu doğrulayın:
   - Outgoing Connections (Client)
   - User Selected File (Read/Write)
5. `CesetMediaDownloader` scheme'ini seçip Run düğmesine basın.

Bootstrap betiği resmi yt-dlp macOS paketini ve Apple Silicon FFmpeg/FFprobe derlemelerini doğrudan sağlayıcılarından indirir. Binary dosyalar lisans ve depo boyutu nedeniyle Git deposunda yeniden dağıtılmaz. Kurulumdan sonra Homebrew veya ayrı Python gerekmez.

## Çıktı davranışı

- Video indirmelerinde MP4/M4A akışları ve QuickTime uyumluluğu için H.264/AAC codec'leri önceliklendirilir.
- Ayrı video ve ses akışları FFmpeg tarafından tek `.mp4` dosyasında birleştirilir.
- Çözünürlük kısa kenara göre sıralandığından 720×1280 dikey içerik doğru biçimde 720p kabul edilir.
- Ses seçeneği mümkün olan en iyi kaynak sesi alıp 320 kbps MP3 çıktısı üretir.

## Zen Browser ile oturum kullanımı

Giriş gerektiren bir bağlantı için Zen'de `about:profiles` sayfasını açın. Aktif profil altındaki **Kök Dizini Finder'da Göster** seçeneğini kullanın ve uygulamadaki **Zen Profili** düğmesiyle, içinde `cookies.sqlite` bulunan profil klasörünü seçin.

Uygulama çerezleri dışa aktarmaz. Seçilen klasöre erişim yetkisi macOS security-scoped bookmark olarak yalnızca uygulamanın Sandbox konteynerinde saklanır. Alternatif olarak belge simgesiyle Netscape biçiminde bir `cookies.txt` seçilebilir.

## Gizlilik

- URL'ler ve medya dosyaları bir aracı sunucuya gönderilmez.
- İndirme ve dönüştürme işlemleri cihaz üzerinde yürütülür.
- Zen profili, cookie içeriği ve seçilen klasör izinleri kaynak kodda veya uygulama paketinde bulunmaz.
- Cookie ve Xcode kullanıcı verileri `.gitignore` ile depodan hariç tutulur.

Ayrıntılar için [PRIVACY.md](PRIVACY.md) dosyasına bakın.

## Proje yapısı

```text
CesetMediaDownloader/
├── CesetMediaDownloaderApp.swift   # Uygulama yaşam döngüsü
├── ContentView.swift               # SwiftUI arayüzü
├── DownloadManager.swift           # Process, yt-dlp ve FFmpeg yönetimi
├── CesetMediaDownloader.entitlements
├── Assets.xcassets
├── Resources/Tools                 # Bootstrap ile kurulan medya araçları
└── ../scripts/bootstrap-tools.sh   # Geliştirme araçlarını hazırlar
```

## Dağıtım ve üçüncü taraf araçları

İndirilen araçların kendi lisansları geçerlidir. FFmpeg lisans koşulları kullanılan derleme yapılandırmasına göre GPL/LGPL yükümlülükleri doğurabilir. `bootstrap-tools.sh` dosyaları geliştiricinin makinesine indirir; proje deposu üçüncü taraf executable dosyalarını yeniden dağıtmaz. Bir uygulama binary'si yayımlamadan önce kullandığınız FFmpeg derlemesinin kaynak, lisans ve yeniden dağıtım koşullarını ayrıca doğrulayın.

Siteler extractor davranışlarını değiştirebildiği için yt-dlp paketi düzenli olarak güncellenmelidir. DRM korumalı, kaldırılmış, özel, coğrafi veya ağ düzeyinde engellenen içeriklerin indirilebilmesi garanti edilmez.

## Sorumlu kullanım

Yalnızca indirme ve saklama hakkına sahip olduğunuz içeriklerde kullanın. İçerik sahibinin haklarına ve ilgili platformun kullanım koşullarına uyun.
