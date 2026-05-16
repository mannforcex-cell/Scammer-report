"""
╔══════════════════════════════════════════════════════════╗
║   LaporScam.my — Python Flask Backend                   ║
║   Stack: Flask + SQLite + Cloudflare Tunnel             ║
╚══════════════════════════════════════════════════════════╝
"""

import os
import re
import json
import sqlite3
import subprocess
import threading
import time
from datetime import datetime
from functools import wraps

from flask import (
    Flask, request, jsonify, send_from_directory,
    g, abort
)
from flask_cors import CORS
from werkzeug.utils import secure_filename

# ─────────────────────────────────────────────────────────
#  KONFIGURASI
# ─────────────────────────────────────────────────────────
BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
DB_PATH     = os.path.join(BASE_DIR, "data", "scammer_reports.db")
UPLOAD_DIR  = os.path.join(BASE_DIR, "uploads")
STATIC_DIR  = os.path.join(BASE_DIR, "static")

ALLOWED_EXT = {"jpg", "jpeg", "png", "gif", "webp", "pdf"}
MAX_MB      = 10  # MB

# Buat folder jika belum ada
for d in [os.path.dirname(DB_PATH), UPLOAD_DIR, STATIC_DIR]:
    os.makedirs(d, exist_ok=True)

# ─────────────────────────────────────────────────────────
#  FLASK APP
# ─────────────────────────────────────────────────────────
app = Flask(__name__, static_folder=STATIC_DIR, static_url_path="/static")
app.config["MAX_CONTENT_LENGTH"] = MAX_MB * 1024 * 1024
CORS(app)

# ─────────────────────────────────────────────────────────
#  DATABASE HELPERS
# ─────────────────────────────────────────────────────────
def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH, detect_types=sqlite3.PARSE_DECLTYPES)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA journal_mode=WAL")   # lebih pantas
        g.db.execute("PRAGMA foreign_keys=ON")
    return g.db

@app.teardown_appcontext
def close_db(exc=None):
    db = g.pop("db", None)
    if db:
        db.close()

def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS reports (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                phone          TEXT    NOT NULL,
                loss_amount    REAL    DEFAULT 0,
                incident_date  TEXT,
                incident_time  TEXT,
                scam_type      TEXT    NOT NULL,
                custom_type    TEXT,
                evidence_path  TEXT,
                notes          TEXT,
                ip_address     TEXT,
                created_at     TEXT    DEFAULT (datetime('now','localtime'))
            )
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_phone
            ON reports(phone)
        """)
        conn.commit()
    print("✅ Database sedia:", DB_PATH)

# ─────────────────────────────────────────────────────────
#  RATE LIMITER MUDAH (in-memory)
# ─────────────────────────────────────────────────────────
_rate_store: dict = {}
_rate_lock  = threading.Lock()

def rate_limit(max_calls: int, window_sec: int):
    """Decorator: hadkan bilangan request per IP."""
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            ip  = _get_ip()
            key = f"{fn.__name__}:{ip}"
            now = time.time()
            with _rate_lock:
                calls = [t for t in _rate_store.get(key, []) if now - t < window_sec]
                if len(calls) >= max_calls:
                    return jsonify(success=False,
                                   message=f"Terlalu banyak cubaan. Cuba lagi selepas {window_sec//60} minit."), 429
                calls.append(now)
                _rate_store[key] = calls
            return fn(*args, **kwargs)
        return wrapper
    return decorator

def _get_ip():
    return (
        request.headers.get("CF-Connecting-IP") or
        request.headers.get("X-Forwarded-For", "").split(",")[0].strip() or
        request.remote_addr or "unknown"
    )

# ─────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────
def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXT

def clean_phone(phone: str) -> str:
    return re.sub(r"[^\d+\-\s()]", "", phone).strip()

def paginate(query, count_query, params, page, per_page):
    db     = get_db()
    total  = db.execute(count_query, params).fetchone()[0]
    offset = (page - 1) * per_page
    rows   = db.execute(query + f" LIMIT {per_page} OFFSET {offset}", params).fetchall()
    return total, [dict(r) for r in rows]

# ─────────────────────────────────────────────────────────
#  ROUTES — HALAMAN UTAMA
# ─────────────────────────────────────────────────────────
@app.route("/")
def index():
    return send_from_directory(BASE_DIR, "index.html")

@app.route("/uploads/<path:filename>")
def serve_upload(filename):
    return send_from_directory(UPLOAD_DIR, filename)

# ─────────────────────────────────────────────────────────
#  API — HANTAR LAPORAN
# ─────────────────────────────────────────────────────────
@app.route("/api/report", methods=["POST"])
@rate_limit(max_calls=5, window_sec=900)   # 5 laporan / 15 minit / IP
def create_report():
    phone     = request.form.get("phone", "").strip()
    scam_type = request.form.get("scam_type", "").strip()

    if not phone:
        return jsonify(success=False, message="Nombor telefon wajib diisi."), 400
    if not scam_type:
        return jsonify(success=False, message="Jenis scam wajib dipilih."), 400

    # Parse nilai pilihan
    try:
        loss = float(request.form.get("loss_amount") or 0)
    except ValueError:
        loss = 0.0

    custom_type   = request.form.get("custom_type", "").strip() or None
    incident_date = request.form.get("incident_date") or None
    incident_time = request.form.get("incident_time") or None
    notes         = request.form.get("notes", "").strip() or None

    # Handle upload fail
    evidence_path = None
    file = request.files.get("evidence")
    if file and file.filename:
        if not allowed_file(file.filename):
            return jsonify(success=False, message="Jenis fail tidak dibenarkan."), 400
        fname = f"{int(time.time() * 1000)}_{secure_filename(file.filename)}"
        file.save(os.path.join(UPLOAD_DIR, fname))
        evidence_path = fname

    db = get_db()
    cur = db.execute("""
        INSERT INTO reports
          (phone, loss_amount, incident_date, incident_time,
           scam_type, custom_type, evidence_path, notes, ip_address)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, [clean_phone(phone), loss, incident_date, incident_time,
          scam_type, custom_type, evidence_path, notes, _get_ip()])
    db.commit()

    print(f"📋 Laporan #{cur.lastrowid} — {phone}")
    return jsonify(success=True,
                   message="Laporan berjaya dihantar! Terima kasih.",
                   report_id=cur.lastrowid)

# ─────────────────────────────────────────────────────────
#  API — SENARAI LAPORAN
# ─────────────────────────────────────────────────────────
@app.route("/api/reports")
def list_reports():
    page     = max(1, int(request.args.get("page", 1)))
    per_page = min(50, int(request.args.get("limit", 20)))
    search   = request.args.get("search", "").strip()
    scam_type = request.args.get("type", "")

    conditions, params = [], []
    if search:
        conditions.append("phone LIKE ?")
        params.append(f"%{search}%")
    if scam_type and scam_type != "all":
        conditions.append("scam_type = ?")
        params.append(scam_type)

    where = ("WHERE " + " AND ".join(conditions)) if conditions else ""

    select = f"""
        SELECT id, phone, loss_amount, incident_date, scam_type,
               custom_type, notes, created_at,
               CASE WHEN evidence_path IS NOT NULL THEN 1 ELSE 0 END AS has_evidence
        FROM reports {where}
        ORDER BY created_at DESC
    """
    total, rows = paginate(select, f"SELECT COUNT(*) FROM reports {where}",
                           params, page, per_page)

    return jsonify(success=True, total=total, page=page, data=rows)

# ─────────────────────────────────────────────────────────
#  API — STATISTIK
# ─────────────────────────────────────────────────────────
@app.route("/api/stats")
def stats():
    db  = get_db()
    row = db.execute("""
        SELECT
            COUNT(*) AS total_reports,
            COALESCE(SUM(loss_amount), 0) AS total_loss,
            COUNT(DISTINCT phone)          AS unique_numbers
        FROM reports
    """).fetchone()

    by_type = db.execute("""
        SELECT scam_type, COUNT(*) AS count
        FROM reports GROUP BY scam_type ORDER BY count DESC
    """).fetchall()

    return jsonify(success=True, data={
        "total_reports":  row["total_reports"],
        "total_loss":     row["total_loss"],
        "unique_numbers": row["unique_numbers"],
        "by_type":        [dict(r) for r in by_type],
    })

# ─────────────────────────────────────────────────────────
#  API — SEMAK NOMBOR
# ─────────────────────────────────────────────────────────
@app.route("/api/check/<phone>")
def check_phone(phone):
    clean = re.sub(r"[^\d+]", "", phone)
    db    = get_db()
    rows  = db.execute("""
        SELECT id, scam_type, loss_amount, created_at
        FROM reports WHERE phone LIKE ?
        ORDER BY created_at DESC
    """, [f"%{clean}%"]).fetchall()

    return jsonify(success=True,
                   found=len(rows) > 0,
                   count=len(rows),
                   reports=[dict(r) for r in rows])

# ─────────────────────────────────────────────────────────
#  ERROR HANDLERS
# ─────────────────────────────────────────────────────────
@app.errorhandler(413)
def too_large(e):
    return jsonify(success=False, message=f"Fail terlalu besar. Had {MAX_MB}MB."), 413

@app.errorhandler(404)
def not_found(e):
    return jsonify(success=False, message="Endpoint tidak ditemui."), 404

# ─────────────────────────────────────────────────────────
#  ENTRY POINT
# ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("PORT", 3000))
    print(f"""
╔══════════════════════════════════════════════╗
║   🚨 LaporScam.my — Python Flask            ║
║   🌐 http://0.0.0.0:{port:<26}║
║   📁 DB  : {DB_PATH[-38:]:<38}║
║   📂 Uploads: ./uploads/                    ║
╚══════════════════════════════════════════════╝
    """)
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)
