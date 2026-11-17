# syntax=docker/dockerfile:1.7
# RT Helpdesk — multi-stage build per docs/CONTAINER_PACKAGING.md
# Stages: base -> test (extends base) -> runtime (extends base, LAST = default)

FROM python:3.12-slim-bookworm AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app

# Runtime dependencies BEFORE source (cache-friendly)
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements.txt

# UID/GID 10001 as required
RUN groupadd --gid 10001 app \
 && useradd  --uid 10001 --gid app --create-home --shell /usr/sbin/nologin app


# ---------- test target ----------
# Contains runtime deps + dev deps + tests + pytest.ini. Final user 10001:10001.
FROM base AS test
# requirements-dev.txt includes '-r requirements.txt' so both files are needed
COPY requirements-dev.txt ./
COPY requirements.txt ./
RUN python -m pip install --no-cache-dir -r requirements-dev.txt

COPY app/ ./app/
COPY tests/ ./tests/
COPY pytest.ini ./
COPY gunicorn.conf.py ./

USER 10001:10001
CMD ["python", "-m", "pytest", "-q", "-p", "no:cacheprovider"]


# ---------- runtime target (LAST -> default) ----------
FROM base AS runtime
ARG APP_VERSION=local
ENV APP_VERSION=${APP_VERSION}

COPY app/ ./app/
COPY gunicorn.conf.py ./
# requirements.txt was only needed in the `base` layer to install packages.
RUN rm -f /app/requirements.txt

USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz', timeout=3).status==200 else 1)"

# JSON form -> gunicorn receives SIGTERM/SIGINT as PID 1
CMD ["gunicorn", "--config", "gunicorn.conf.py", "app:create_app()"]
