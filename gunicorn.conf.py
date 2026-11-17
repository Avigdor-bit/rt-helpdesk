"""Gunicorn settings for RT Helpdesk.

Per docs/CONTAINER_PACKAGING.md: one worker, four threads, bind 0.0.0.0:8000.
Fixed worker count keeps Prometheus metrics monotonic (per-process counters).
"""
import os

bind = "0.0.0.0:8000"
workers = 1
threads = 4
worker_class = "gthread"

timeout = int(os.getenv("GUNICORN_TIMEOUT", "60"))
graceful_timeout = 30
keepalive = 5

accesslog = "-"
errorlog = "-"
loglevel = os.getenv("GUNICORN_LOGLEVEL", "info")
