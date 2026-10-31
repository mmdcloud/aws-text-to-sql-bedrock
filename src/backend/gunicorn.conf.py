import os

bind = f"0.0.0.0:{os.getenv('PORT', '80')}"
workers = int(os.getenv("GUNICORN_WORKERS", "2"))
threads = int(os.getenv("GUNICORN_THREADS", "4"))
timeout = int(os.getenv("GUNICORN_TIMEOUT", "60"))
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("LOG_LEVEL", "info").lower()

# Drop worker privileges to appuser if started as root
if hasattr(os, "getuid") and os.getuid() == 0:
    user = os.getenv("GUNICORN_USER", "appuser")
    group = os.getenv("GUNICORN_GROUP", "appgroup")
