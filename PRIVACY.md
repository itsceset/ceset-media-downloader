# Gizlilik

Ceset Media Downloader bir hesap sistemi veya uzaktaki uygulama sunucusu kullanmaz. Medya çözümleme işlemi, kullanıcı tarafından verilen URL için doğrudan ilgili platform ile paket içindeki yt-dlp arasında gerçekleşir. FFmpeg işlemleri cihaz üzerinde yürütülür.

## Cihazda saklanan veriler

Uygulama aşağıdaki tercihleri macOS App Sandbox konteynerinde saklayabilir:

- Kullanıcının seçtiği çıktı klasörüne ait security-scoped bookmark
- Kullanıcı özellikle seçerse Zen profil klasörüne veya `cookies.txt` dosyasına ait security-scoped bookmark
- Pencere boyutu ve standart macOS arayüz tercihleri

Security-scoped bookmark, macOS'un uygulamaya yeniden dosya erişim izni verebilmesi içindir. Zen profilinin veya cookie dosyasının içeriği kaynak projeye ya da uygulama paketine kopyalanmaz.

## Paylaşılmayan veriler

Proje deposu ve dağıtılan uygulama paketi şunları içermez:

- Zen Browser profili
- `cookies.sqlite` veya `cookies.txt`
- Hesap parolaları veya oturum anahtarları
- Kullanıcının indirme geçmişi
- Kullanıcıya özel security-scoped bookmark verileri

Oturum çerezleri hesap erişimi sağlayabilecek hassas verilerdir. Cookie dosyalarını paylaşmayın, Git deposuna eklemeyin ve yalnızca kendi hesabınızla erişme hakkınız olan içerikler için kullanın.
