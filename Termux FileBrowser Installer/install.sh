#!/data/data/com.termux/files/usr/bin/bash
# Installer FileBrowser untuk Termux (tanpa Jellyfin/Syncthing).
# Pengaturan bisa diubah lewat variabel lingkungan, contoh:
#   FB_PORT=9000 FB_ROOT=$HOME/storage/shared/NAS bash install.sh
set -eu

FB_DIR="${FB_DIR:-$HOME/services/filebrowser}"
FB_DB="$FB_DIR/filebrowser.db"
FB_ROOT="${FB_ROOT:-$HOME/nas}"     # folder yang dibagikan (bukan seluruh penyimpanan)
FB_PORT="${FB_PORT:-8081}"          # 8081 agar tidak bentrok dengan server PHP di 8080
FB_ADDR="${FB_ADDR:-0.0.0.0}"       # 0.0.0.0 = bisa diakses dari jaringan lokal
FB_USER="${FB_USER:-admin}"

info() { echo "[*] $*"; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

[ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || die "Skrip ini hanya untuk Termux."

install_binary() {
    if command -v filebrowser >/dev/null 2>&1; then
        info "filebrowser sudah terpasang: $(command -v filebrowser)"
        return 0
    fi

    info "Mencoba 'pkg install filebrowser'..."
    if pkg install -y filebrowser >/dev/null 2>&1 && command -v filebrowser >/dev/null 2>&1; then
        return 0
    fi

    info "Tidak tersedia di repositori Termux. Mengunduh rilis resmi dari GitHub..."
    case "$(uname -m)" in
        aarch64|arm64)   arch=arm64 ;;
        armv7l|armv8l|arm) arch=armv7 ;;
        x86_64)          arch=amd64 ;;
        *) die "Arsitektur tidak didukung: $(uname -m)" ;;
    esac

    pkg install -y curl tar >/dev/null 2>&1 || die "Gagal memasang curl/tar."

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    url="https://github.com/filebrowser/filebrowser/releases/latest/download/linux-${arch}-filebrowser.tar.gz"

    curl -fL --retry 3 -o "$tmp/fb.tar.gz" "$url" \
        || die "Unduhan gagal: $url"
    tar -xzf "$tmp/fb.tar.gz" -C "$tmp" filebrowser \
        || die "Arsip tidak berisi biner 'filebrowser'."
    install -m 755 "$tmp/filebrowser" "$PREFIX/bin/filebrowser"

    filebrowser version >/dev/null 2>&1 \
        || die "Biner terpasang tetapi tidak bisa dijalankan di perangkat ini."
}

read_password() {
    while true; do
        printf "Password untuk '%s' (min 12 karakter): " "$FB_USER" >&2
        IFS= read -rs p1 </dev/tty; echo >&2
        printf "Ulangi password: " >&2
        IFS= read -rs p2 </dev/tty; echo >&2
        if [ "${#p1}" -lt 12 ]; then
            echo "Terlalu pendek, minimal 12 karakter." >&2; continue
        fi
        if [ "$p1" != "$p2" ]; then
            echo "Password tidak sama." >&2; continue
        fi
        FB_PASS="$p1"
        return 0
    done
}

install_binary

mkdir -p "$FB_DIR" "$FB_ROOT"
chmod 700 "$FB_DIR"

if [ -f "$FB_DB" ]; then
    info "Database sudah ada, konfigurasi dan akun tidak diubah."
    info "Untuk mengulang dari awal: bash stop.sh && rm $FB_DB"
else
    read_password
    info "Membuat konfigurasi..."
    filebrowser config init -a "$FB_ADDR" -p "$FB_PORT" -r "$FB_ROOT" -d "$FB_DB" >/dev/null \
        || { rm -f "$FB_DB"; die "Gagal membuat konfigurasi."; }
    info "Membuat akun admin '$FB_USER'..."
    filebrowser users add "$FB_USER" "$FB_PASS" --perm.admin=true -d "$FB_DB" >/dev/null \
        || { rm -f "$FB_DB"; die "Gagal membuat akun (cek panjang password)."; }
    chmod 600 "$FB_DB"
    unset FB_PASS p1 p2
fi

echo
echo "[OK] Instalasi selesai."
echo "     Folder dibagikan : $FB_ROOT"
echo "     Port             : $FB_PORT"
echo "     Jalankan         : bash start.sh"
echo "     Hentikan         : bash stop.sh"
