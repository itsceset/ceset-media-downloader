#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
tools_dir="$project_dir/CesetMediaDownloader/Resources/Tools"
staging_dir=$(mktemp -d /tmp/ceset-media-tools.XXXXXX)

cleanup() {
    rm -rf "$staging_dir"
}
trap cleanup EXIT

mkdir -p "$tools_dir"

echo "yt-dlp indiriliyor…"
curl -L --fail --retry 3 \
    "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos.zip" \
    -o "$staging_dir/yt-dlp_macos.zip"
ditto -x -k "$staging_dir/yt-dlp_macos.zip" "$staging_dir/yt-dlp"

yt_dlp_path="$staging_dir/yt-dlp/yt-dlp_macos"
if [[ ! -x "$yt_dlp_path" ]]; then
    echo "Hata: yt-dlp_macos paketten çıkarılamadı." >&2
    exit 1
fi

rm -rf "$tools_dir/YTDLP.bundle"
mv "$staging_dir/yt-dlp" "$tools_dir/YTDLP.bundle"

echo "FFmpeg ve FFprobe indiriliyor…"
curl -L --fail --retry 3 \
    "https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffmpeg.zip" \
    -o "$staging_dir/ffmpeg.zip"
curl -L --fail --retry 3 \
    "https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/ffprobe.zip" \
    -o "$staging_dir/ffprobe.zip"

ditto -x -k "$staging_dir/ffmpeg.zip" "$staging_dir/ffmpeg-unpacked"
ditto -x -k "$staging_dir/ffprobe.zip" "$staging_dir/ffprobe-unpacked"

ffmpeg_path=$(find "$staging_dir/ffmpeg-unpacked" -type f -name ffmpeg -print -quit)
ffprobe_path=$(find "$staging_dir/ffprobe-unpacked" -type f -name ffprobe -print -quit)

if [[ -z "$ffmpeg_path" || -z "$ffprobe_path" ]]; then
    echo "Hata: FFmpeg arşivleri beklenen executable dosyalarını içermiyor." >&2
    exit 1
fi

cp "$ffmpeg_path" "$tools_dir/ffmpeg"
cp "$ffprobe_path" "$tools_dir/ffprobe"
chmod +x "$tools_dir/ffmpeg" "$tools_dir/ffprobe" "$tools_dir/YTDLP.bundle/yt-dlp_macos"

if ! file "$tools_dir/ffmpeg" | grep -q arm64; then
    echo "Hata: indirilen FFmpeg Apple Silicon ARM64 değil." >&2
    exit 1
fi

echo "Hazır:"
"$tools_dir/YTDLP.bundle/yt-dlp_macos" --version
"$tools_dir/ffmpeg" -version | head -n 1
"$tools_dir/ffprobe" -version | head -n 1
