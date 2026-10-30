"""
wsgi.py — Gunicorn entrypoint.

Imports the application instance created in app/main.py.
Gunicorn is invoked as:
    gunicorn --config gunicorn.conf.py wsgi:application
"""
from app.main import application  # noqa: F401  (re-exported for Gunicorn)
