# Bundle araçları

Bu klasör uygulamanın sandbox içinde bağımsız çalışması için gerekli araçları barındırır:

- `YTDLP.bundle`: Resmî unpackaged macOS yt-dlp dağıtımı. Tek dosyalı PyInstaller sürümü App Sandbox altında System V semaphore kullanamadığı için özellikle bu dağıtım kullanılır.
- `ffmpeg`: Statik Apple Silicon FFmpeg binary'si.
- `ffprobe`: Statik Apple Silicon FFprobe binary'si.

Binary dosyalar Git deposunda tutulmaz. Proje kökünde `./scripts/bootstrap-tools.sh` çalıştırılarak sağlayıcılarından indirilir. Uygulama önce bundle içindeki araçları, yalnızca geliştirme geri dönüşü olarak Homebrew ve `PATH` konumlarını arar.
