#!/data/data/com.termux/files/usr/bin/bash
# Menghentikan FileBrowser yang dijalankan oleh start.sh.
set -u

FB_DIR="${FB_DIR:-$HOME/services/filebrowser}"
FB_PID="$FB_DIR/filebrowser.pid"

if [ ! -f "$FB_PID" ]; then
    echo "[*] FileBrowser tidak berjalan (PID file tidak ada)."
    exit 0
fi

pid="$(cat "$FB_PID" 2>/dev/null)"

if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    echo "[*] Proses sudah tidak ada. Membersihkan PID file."
    rm -f "$FB_PID"
    exit 0
fi

# Jangan menghentikan proses lain bila PID sudah didaur ulang
if [ -r "/proc/$pid/cmdline" ] && ! grep -aq filebrowser "/proc/$pid/cmdline"; then
    echo "[!] PID $pid bukan filebrowser. PID file usang dihapus, tidak ada proses yang dihentikan."
    rm -f "$FB_PID"
    exit 1
fi

kill "$pid"
i=0
while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do
    sleep 0.5
    i=$((i + 1))
done

if kill -0 "$pid" 2>/dev/null; then
    echo "[!] Tidak berhenti dengan baik, memaksa (SIGKILL)..."
    kill -9 "$pid" 2>/dev/null
    sleep 1
fi

if kill -0 "$pid" 2>/dev/null; then
    echo "[ERROR] Gagal menghentikan PID $pid." >&2
    exit 1
fi

rm -f "$FB_PID"
echo "[OK] FileBrowser dihentikan."
echo "     Wake lock masih aktif. Jika tidak ada layanan lain, lepas dengan: termux-wake-unlock"
