#!/data/data/com.termux/files/usr/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  LaporScam.my — Setup Domain Kekal Percuma                 ║
# ║  Menggunakan: Cloudflare Named Tunnel                       ║
# ║  Domain TIDAK berubah walaupun server off/on               ║
# ╚══════════════════════════════════════════════════════════════╝
#
#  CARA GUNA:
#    bash setup_domain_kekal.sh
#
#  APA YANG SKRIP INI BUAT:
#    1. Download cloudflared (jika belum ada)
#    2. Panduan login Cloudflare (percuma)
#    3. Cipta Named Tunnel → domain KEKAL
#    4. Update start.sh supaya guna domain kekal
#    5. Simpan semua config

set -e

# ── Warna ────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; B='\033[1m'; N='\033[0m'

info()  { echo -e "${C}[INFO]${N} $1"; }
ok()    { echo -e "${G}[✓]${N} $1"; }
warn()  { echo -e "${Y}[!]${N} $1"; }
err()   { echo -e "${R}[✗]${N} $1"; exit 1; }
title() { echo -e "\n${B}${C}━━━ $1 ━━━${N}"; }
box()   {
  echo -e "\n${G}${B}╔══════════════════════════════════════════════════════╗${N}"
  echo -e "${G}${B}║  $1${N}"
  echo -e "${G}${B}╚══════════════════════════════════════════════════════╝${N}"
}

DIR="$(cd "$(dirname "$0")" && pwd)"
CF="$DIR/cloudflared"
CF_DIR="$HOME/.cloudflared"
TUNNEL_NAME="laporscam"
PORT="${PORT:-3000}"

clear
echo -e "${R}${B}"
echo "  ╦  ╔═╗╔═╗╔═╗╦═╗╔═╗╔═╗╔═╗╔╦╗"
echo "  ║  ╠═╣╠═╝║ ║╠╦╝╚═╗║  ╠═╣║║║"
echo "  ╩═╝╩ ╩╩  ╚═╝╩╚═╚═╝╚═╝╩ ╩╩ ╩"
echo -e "${N}${C}    Domain Kekal Percuma — Setup Wizard${N}"
echo -e "${Y}    Domain SAMA walaupun server off/on${N}\n"

# ════════════════════════════════════════════════════════
#  SEMAK cloudflared
# ════════════════════════════════════════════════════════
title "Semak cloudflared"

if [ ! -f "$CF" ]; then
  warn "cloudflared tidak jumpa. Muat turun sekarang..."
  ARCH=$(uname -m)
  case "$ARCH" in
    aarch64|arm64) URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
    armv7l|arm)    URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm" ;;
    x86_64)        URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
    *) err "Seni bina $ARCH tidak disokong" ;;
  esac
  curl -L -o "$CF" "$URL" --progress-bar || wget -O "$CF" "$URL" -q --show-progress
  chmod +x "$CF"
  ok "cloudflared dimuat turun"
else
  ok "cloudflared sedia: $($CF --version 2>&1 | head -1)"
fi

# ════════════════════════════════════════════════════════
#  SEMAK sama ada tunnel sudah wujud
# ════════════════════════════════════════════════════════
title "Semak Tunnel Sedia Ada"

EXISTING_ID=""
if [ -f "$CF_DIR/cert.pem" ]; then
  # Cuba cari tunnel yang sudah ada
  EXISTING_ID=$("$CF" tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}' || true)
fi

if [ -n "$EXISTING_ID" ]; then
  echo -e "${G}✓ Tunnel '$TUNNEL_NAME' sudah wujud (ID: $EXISTING_ID)${N}"
  echo -e "${Y}Langkau langkah login dan cipta tunnel.${N}"
  TUNNEL_ID="$EXISTING_ID"
  SKIP_CREATE=true
else
  SKIP_CREATE=false
fi

# ════════════════════════════════════════════════════════
#  LOGIN CLOUDFLARE
# ════════════════════════════════════════════════════════
if [ "$SKIP_CREATE" = false ]; then

title "Login Cloudflare (Akaun Percuma)"

echo ""
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${B}  ARAHAN LOGIN:${N}"
echo ""
echo -e "  1. Skrip akan paparkan PAUTAN LOGIN"
echo -e "  2. Buka pautan itu dalam browser telefon/komputer"
echo -e "  3. Log masuk dengan akaun Cloudflare PERCUMA anda"
echo -e "     (Daftar percuma di: ${C}https://dash.cloudflare.com/sign-up${N})"
echo -e "  4. Klik AUTHORIZE pada halaman yang dibuka"
echo -e "  5. Kembali ke terminal ini — login akan selesai automatik"
echo ""
echo -e "${Y}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
read -p "  Tekan ENTER bila bersedia untuk login..."

mkdir -p "$CF_DIR"

# Jalankan login — akan papar URL
"$CF" tunnel login

if [ ! -f "$CF_DIR/cert.pem" ]; then
  err "Login gagal. Pastikan anda authorize dalam browser."
fi
ok "Login Cloudflare berjaya!"

# ════════════════════════════════════════════════════════
#  CIPTA NAMED TUNNEL
# ════════════════════════════════════════════════════════
title "Cipta Named Tunnel '$TUNNEL_NAME'"

# Cipta tunnel
CREATE_OUT=$("$CF" tunnel create "$TUNNEL_NAME" 2>&1)
echo "$CREATE_OUT"

# Ekstrak Tunnel ID
TUNNEL_ID=$(echo "$CREATE_OUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)

if [ -z "$TUNNEL_ID" ]; then
  # Cuba cari dari senarai
  TUNNEL_ID=$("$CF" tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}')
fi

if [ -z "$TUNNEL_ID" ]; then
  err "Gagal dapatkan Tunnel ID. Cuba semula."
fi

ok "Tunnel ID: $TUNNEL_ID"

fi  # end if SKIP_CREATE = false

# ════════════════════════════════════════════════════════
#  DAPATKAN SUBDOMAIN CLOUDFLARE
# ════════════════════════════════════════════════════════
title "Tetapkan Domain Kekal"

# Domain format: <tunnel-id>.cfargotunnel.com
# Ini KEKAL — tidak berubah langsung
TUNNEL_DOMAIN="${TUNNEL_ID}.cfargotunnel.com"

# Buat routing untuk tunnel ini
# Guna trycloudflare subdomain sebagai hostname
HOSTNAME="${TUNNEL_NAME}.${TUNNEL_ID:0:8}.workers.dev"

# Route subdomain ke tunnel
"$CF" tunnel route dns "$TUNNEL_NAME" "$TUNNEL_NAME" 2>/dev/null || true

ok "Tunnel domain: $TUNNEL_DOMAIN"

# ════════════════════════════════════════════════════════
#  BUAT FAIL KONFIGURASI
# ════════════════════════════════════════════════════════
title "Cipta Fail Konfigurasi"

# Cari credentials file
CRED_FILE="$CF_DIR/${TUNNEL_ID}.json"
if [ ! -f "$CRED_FILE" ]; then
  # Cuba lokasi lain
  CRED_FILE=$(find "$CF_DIR" -name "*.json" | head -1)
fi

cat > "$CF_DIR/config.yml" << EOF
# Konfigurasi Cloudflare Tunnel — LaporScam.my
# Fail ini diurus oleh setup_domain_kekal.sh
# JANGAN padam fail ini

tunnel: ${TUNNEL_ID}
credentials-file: ${CRED_FILE}

ingress:
  - service: http://localhost:${PORT}
EOF

ok "Config disimpan: $CF_DIR/config.yml"

# Simpan info tunnel
cat > "$DIR/.tunnel_info" << EOF
TUNNEL_NAME=${TUNNEL_NAME}
TUNNEL_ID=${TUNNEL_ID}
TUNNEL_DOMAIN=${TUNNEL_DOMAIN}
CRED_FILE=${CRED_FILE}
PORT=${PORT}
CREATED=$(date)
EOF

ok "Info tunnel disimpan: $DIR/.tunnel_info"

# ════════════════════════════════════════════════════════
#  BUAT start.sh YANG DIKEMAS KINI
# ════════════════════════════════════════════════════════
title "Kemaskini start.sh"

cat > "$DIR/start.sh" << 'STARTSH'
#!/data/data/com.termux/files/usr/bin/bash
# ── Jalankan LaporScam.my dengan domain KEKAL ──

G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; B='\033[1m'; N='\033[0m'

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

# Load config
[ -f .env ]          && export $(grep -v '^#' .env | xargs 2>/dev/null)
[ -f .tunnel_info ]  && source .tunnel_info
PORT="${PORT:-3000}"

# Aktifkan Python venv
if [ -d "$DIR/venv" ]; then
  source "$DIR/venv/bin/activate"
fi

echo -e "\n${C}${B}🚀 Memulakan LaporScam.my...${N}\n"

# ── Mulakan Flask ──────────────────────────────────────
python3 "$DIR/app.py" > "$DIR/flask.log" 2>&1 &
FLASK_PID=$!
echo -e "${G}✓ Flask berjalan (PID: $FLASK_PID)${N}"
sleep 2

if ! kill -0 $FLASK_PID 2>/dev/null; then
  echo -e "${Y}⚠ Flask gagal start. Semak flask.log:${N}"
  tail -20 "$DIR/flask.log"
  exit 1
fi

# ── Papar Domain Kekal ─────────────────────────────────
if [ -n "$TUNNEL_ID" ]; then
  echo ""
  echo -e "╔══════════════════════════════════════════════════════╗"
  echo -e "║  🌐 DOMAIN KEKAL ANDA:                              ║"
  echo -e "║                                                      ║"
  echo -e "║  ${G}https://${TUNNEL_ID}.cfargotunnel.com${N}"
  echo -e "║                                                      ║"
  echo -e "║  ✅ Domain ini SAMA walaupun server off/on           ║"
  echo -e "║  📤 Kongsi link ini dengan sesiapa sahaja           ║"
  echo -e "╚══════════════════════════════════════════════════════╝"
  echo ""
fi

# ── Mulakan Cloudflare Tunnel ──────────────────────────
echo -e "${Y}🔗 Menyambung Cloudflare Tunnel...${N}"
"$DIR/cloudflared" tunnel --config "$HOME/.cloudflared/config.yml" run &
CF_PID=$!

sleep 3
if kill -0 $CF_PID 2>/dev/null; then
  echo -e "${G}✓ Tunnel aktif — domain boleh diakses!${N}"
else
  echo -e "${Y}⚠ Tunnel mungkin ada masalah. Semak log di atas.${N}"
fi

echo -e "\n${G}Server berjalan. Tekan Ctrl+C untuk berhenti.${N}\n"

# Cleanup bila berhenti
trap "echo -e '\n🔴 Menghentikan...'; kill $FLASK_PID $CF_PID 2>/dev/null; exit 0" INT TERM

wait $FLASK_PID
STARTSH

chmod +x "$DIR/start.sh"
ok "start.sh dikemas kini dengan domain kekal"

# ════════════════════════════════════════════════════════
#  BUAT stop.sh
# ════════════════════════════════════════════════════════
cat > "$DIR/stop.sh" << 'STOPSH'
#!/data/data/com.termux/files/usr/bin/bash
echo "🔴 Menghentikan LaporScam.my..."
pkill -f "app.py"   2>/dev/null && echo "✓ Flask dihentikan"   || echo "- Flask tidak berjalan"
pkill -f "cloudflared" 2>/dev/null && echo "✓ Tunnel dihentikan" || echo "- Tunnel tidak berjalan"
echo "Selesai."
STOPSH
chmod +x "$DIR/stop.sh"

# ════════════════════════════════════════════════════════
#  RINGKASAN AKHIR
# ════════════════════════════════════════════════════════
echo ""
echo -e "${G}${B}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║   ✅  SETUP DOMAIN KEKAL SELESAI!                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo -e "║                                                          ║${N}"
echo -e "${G}${B}║  🌐 DOMAIN ANDA (KEKAL SELAMA-LAMANYA):              ║${N}"
echo -e "${C}${B}║                                                          ║${N}"
printf "${C}${B}║  https://%-47s║${N}\n" "${TUNNEL_ID}.cfargotunnel.com"
echo -e "${G}${B}║                                                          ║${N}"
echo -e "${G}${B}║  📌 Simpan link ini — ia tidak akan berubah!            ║${N}"
echo -e "${G}${B}║  📤 Kongsi dengan sesiapa — boleh akses dari mana-mana ║${N}"
echo -e "${G}${B}║                                                          ║${N}"
echo -e "${G}${B}╠══════════════════════════════════════════════════════════╣${N}"
echo -e "${G}${B}║  Cara guna seterusnya:                                   ║${N}"
echo -e "${G}${B}║    bash start.sh  → hidupkan server + tunnel            ║${N}"
echo -e "${G}${B}║    bash stop.sh   → matikan server                      ║${N}"
echo -e "${G}${B}╚══════════════════════════════════════════════════════════╝${N}"
echo ""
echo -e "${Y}  💾 Domain anda disimpan dalam fail: .tunnel_info${N}"
echo -e "${Y}  📋 Log Flask: flask.log${N}"
echo ""
echo -e "${C}  Untuk mulakan server sekarang, jalankan:${N}"
echo -e "  ${B}bash start.sh${N}"
echo ""
