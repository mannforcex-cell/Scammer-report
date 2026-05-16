# 🚨 LaporScam.my — Platform Laporan Scammer Malaysia

> Platform awam percuma untuk melaporkan & menyemak nombor telefon scammer di Malaysia.  
> Dibina menggunakan Python (Flask) + SQLite + Cloudflare/Serveo Tunnel.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Linux-brightgreen)
![Python](https://img.shields.io/badge/Python-3.8%2B-blue)
![Flask](https://img.shields.io/badge/Flask-3.0-red)
![License](https://img.shields.io/badge/License-MIT-yellow)

---

## 📸 Preview

```
╔══════════════════════════════════════════════╗
║   🚨 LaporScam.my — Python Flask                     ║
║   🌐 http://0.0.0.0:3000                             ║
║   📁 DB  : data/scammer_reports.db                   ║
║   📂 Uploads: ./uploads/                             ║
╚══════════════════════════════════════════════╝
```

---

## 📁 Struktur Fail

```
laporscam/
├── app.py                  ← Backend Flask (Python)
├── index.html              ← Frontend (HTML + CSS + JS)
├── requirements.txt        ← Senarai pakej Python
├── setup.sh                ← Auto-install semua (jalankan sekali)
├── README.md               ← Panduan ini
├── data/
│   └── scammer_reports.db  ← Database SQLite (auto-cipta)
└── uploads/                ← Gambar bukti (auto-cipta)
```

---

## ✨ Ciri-ciri

- 📋 **Borang laporan lengkap** — nombor telefon, kerugian, jenis scam, bukti gambar
- 🔍 **Semak nombor** — cari sama ada nombor pernah dilaporkan
- 📊 **Statistik live** — jumlah laporan, kerugian, nombor unik
- 📱 **Nombor telefon penuh** — boleh salin & terus panggil
- 🌐 **Boleh akses seluruh dunia** — via Serveo tunnel percuma
- 💾 **Database SQLite** — tiada setup tambahan diperlukan
- 📎 **Upload bukti** — sokong gambar & PDF sehingga 10MB
- 🔒 **Rate limiting** — hadkan spam laporan
- 📱 **Android optimized** — touch-friendly, responsive

---

## 🛠️ Keperluan

| Perkara | Versi |
|---------|-------|
| Python  | 3.8+  |
| pip     | Terkini |
| Termux (Android) | Terkini |
| Sambungan Internet | ✅ |

---

## 🚀 Pemasangan — A sampai Z

### A) Download / Clone Projek

**Cara 1 — Clone dari GitHub:**
```bash
pkg install git -y
git clone https://github.com/USERNAME/laporscam.git
cd laporscam
```

**Cara 2 — Download ZIP:**
```bash
# Download dan extract
pkg install wget unzip -y
wget https://github.com/USERNAME/laporscam/archive/main.zip
unzip main.zip
cd laporscam-main
```

---

### B) Pasang Python & Dependencies

```bash
# Pasang Python (Termux)
pkg install python -y

# Jalankan setup automatik
bash setup.sh
```

Setup akan buat:
- ✅ Virtual environment Python
- ✅ Install Flask & semua pakej
- ✅ Cipta folder `data/` dan `uploads/`
- ✅ Cipta fail `.env`

---

### C) Jalankan Server

Buka **2 tab** dalam Termux (tekan `+` atas kanan):

**Tab 1 — Flask Server:**
```bash
cd ~/laporscam
python3 app.py
```

Tunggu sampai nampak:
```
✅ Database sedia
🌐 Running on http://0.0.0.0:3000
```

**Tab 2 — Tunnel (Link Awam):**
```bash
ssh -o "StrictHostKeyChecking no" -R laporscammy:80:localhost:3000 serveo.net
```

Tunggu sampai nampak:
```
Forwarding HTTP traffic from https://laporscammy.serveousercontent.com
```

---

### D) Akses Laman Web

| Jenis Akses | URL |
|-------------|-----|
| **Tempatan** (WiFi sama) | `http://192.168.x.x:3000` |
| **Awam** (seluruh dunia) | `https://laporscammy.serveousercontent.com` |

---

### E) Elak Server Mati (Penting!)

```bash
# Jalankan dalam tab baru — elak telefon hibernate
termux-wake-lock
```

---

## 🔄 Cara Start Semula (Setiap Kali)

```bash
# Tab 1
cd ~/laporscam && python3 app.py

# Tab 2
ssh -o "StrictHostKeyChecking no" -R laporscammy:80:localhost:3000 serveo.net
```

> 💡 **Link awam kekal sama** — `https://laporscammy.serveousercontent.com`

---

## 📊 API Endpoints

| Method | Endpoint | Fungsi |
|--------|----------|--------|
| `GET` | `/` | Halaman utama |
| `POST` | `/api/report` | Hantar laporan baru |
| `GET` | `/api/reports` | Senarai semua laporan |
| `GET` | `/api/stats` | Statistik keseluruhan |
| `GET` | `/api/check/<phone>` | Semak nombor telefon |

**Query params untuk `/api/reports`:**
```
?page=1        → nombor halaman
?limit=15      → bilangan rekod per halaman
?search=0111   → cari nombor
?type=Parcel   → tapis mengikut jenis scam
```

---

## 🗄️ Database

Database SQLite disimpan di `data/scammer_reports.db`.

**Struktur jadual `reports`:**

| Kolum | Jenis | Keterangan |
|-------|-------|------------|
| `id` | INTEGER | ID auto |
| `phone` | TEXT | Nombor scammer |
| `loss_amount` | REAL | Jumlah kerugian (RM) |
| `incident_date` | TEXT | Tarikh kejadian |
| `incident_time` | TEXT | Masa kejadian |
| `scam_type` | TEXT | Jenis scam |
| `custom_type` | TEXT | Jenis custom |
| `evidence_path` | TEXT | Nama fail bukti |
| `notes` | TEXT | Nota/kronologi |
| `ip_address` | TEXT | IP pelapor |
| `created_at` | TEXT | Masa laporan |

**Backup database:**
```bash
cp data/scammer_reports.db data/backup_$(date +%Y%m%d).db
```

---

## 🔧 Konfigurasi

Edit fail `.env` untuk tukar setting:

```env
PORT=3000
```

Tukar port jika 3000 sudah digunakan:
```bash
PORT=3001 python3 app.py
```

---

## 🐛 Troubleshooting

| Masalah | Penyelesaian |
|---------|-------------|
| `ModuleNotFoundError` | Jalankan `source venv/bin/activate` dulu |
| Port 3000 digunakan | Tukar `PORT=3001` dalam `.env` |
| Upload gambar gagal | Semak `mkdir -p uploads` |
| Serveo link berubah | Pastikan SSH key dah register di serveo |
| Server mati sendiri | Jalankan `termux-wake-lock` |
| `python3: not found` | Jalankan `pkg install python -y` |
| Database error | Padam `data/scammer_reports.db` dan restart |

---

## 📱 Setup SSH Key untuk Link Kekal (Sekali Sahaja)

Untuk pastikan link serveo kekal sama:

```bash
# 1. Generate SSH key
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""

# 2. Cuba connect — akan dapat link untuk register
ssh -o "StrictHostKeyChecking no" -R laporscammy:80:localhost:3000 serveo.net

# 3. Buka link yang muncul dalam browser
# 4. Login dengan Google/GitHub
# 5. Cuba semula — link dah kekal!
```

---

## 🌐 Cara Upload ke GitHub

```bash
# 1. Init git
git init
git add .
git commit -m "🚨 LaporScam.my - Initial commit"

# 2. Buat repo baru di github.com, lepas tu:
git remote add origin https://github.com/USERNAME/laporscam.git
git branch -M main
git push -u origin main
```

> ⚠️ **Jangan upload** folder `data/`, `uploads/`, `venv/` ke GitHub!

Buat fail `.gitignore`:
```
data/
uploads/
venv/
__pycache__/
*.pyc
.env
*.db
```

---

## 📜 Lesen

MIT License — Bebas guna, ubah suai, dan kongsi.

---

## 🤝 Sumbangan

PR dan issue dialu-alukan! Bersama kita lindungi masyarakat Malaysia dari scammer. 🇲🇾

---

*Dibina dengan ❤️ untuk keselamatan masyarakat Malaysia*
