#!/data/data/com.termux/files/usr/bin/bash
# Menjalankan FileBrowser di latar belakang.
set -u

FB_DIR="${FB_DIR:-$HOME/services/filebrowser}"
FB_DB="$FB_DIR/filebrowser.db"
FB_PID="$FB_DIR/filebrowser.pid"
FB_LOG="$FB_DIR/filebrowser.log"

FB_BIN="$(command -v filebrowser || true)"
[ -n "$FB_BIN" ] || { echo "[ERROR] filebrowser belum terpasang. Jalankan: bash install.sh" >&2; exit 1; }
[ -f "$FB_DB" ]  || { echo "[ERROR] Database tidak ditemukan ($FB_DB). Jalankan: bash install.sh" >&2; exit 1; }

is_running() {
    [ -f "$FB_PID" ] || return 1
    pid="$(cat "$FB_PID" 2>/dev/null)"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
    # Pastikan PID itu memang filebrowser (bukan PID daur ulang)
    if [ -r "/proc/$pid/cmdline" ]; then
        grep -aq filebrowser "/proc/$pid/cmdline" || return 1
    fi
    return 0
}

get_ip() {
    ip=""
    ip="$(ip -4 addr show wlan0 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)"
    [ -z "$ip" ] && ip="$(ifconfig wlan0 2>/dev/null | awk '/inet /{print $2}' | head -n1)"
    echo "$ip"
}

if is_running; then
    echo "[*] FileBrowser sudah berjalan (PID $(cat "$FB_PID"))."
    exit 0
fi
rm -f "$FB_PID"

# Baca port sebelum server jalan (database dikunci saat server aktif)
PORT="$("$FB_BIN" config cat -d "$FB_DB" 2>/dev/null | awk '/^Port:/{print $2; exit}')"
PORT="${PORT:-8081}"

# Potong log jika lebih dari 1 MB
if [ -f "$FB_LOG" ] && [ "$(wc -c < "$FB_LOG")" -gt 1048576 ]; then
    : > "$FB_LOG"
fi

termux-wake-lock 2>/dev/null || echo "[!] termux-wake-lock tidak tersedia; Android bisa menghentikan server."

nohup "$FB_BIN" -d "$FB_DB" >> "$FB_LOG" 2>&1 &
echo $! > "$FB_PID"
sleep 2

if is_running; then
    IP="$(get_ip)"
    echo "[OK] FileBrowser berjalan (PID $(cat "$FB_PID"))."
    echo "     Di ponsel  : http://localhost:$PORT"
    if [ -n "$IP" ]; then
        echo "     Dari jaringan: http://$IP:$PORT"
    else
        echo "     Dari jaringan: http://<IP-PONSEL>:$PORT  (IP: lihat pengaturan Wi-Fi)"
    fi
else
    echo "[ERROR] FileBrowser gagal start. Log terakhir:" >&2
    tail -n 15 "$FB_LOG" >&2
    rm -f "$FB_PID"
    exit 1
fi
