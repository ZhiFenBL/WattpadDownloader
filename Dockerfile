FROM node:20-alpine AS frontend-builder
WORKDIR /build
COPY src/frontend/package*.json .
RUN npm ci 
COPY src/frontend/. .
RUN npm run build

FROM python:3.13-slim AS python-builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/
COPY src/api/pyproject.toml /app/

RUN uv sync --no-dev --compile

FROM python:3.13-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    aria2 \
    libglib2.0-0 \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libgobject-2.0-0 \
    libcairo2 \
    libfontconfig1 \
    fonts-noto-core \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

COPY --from=python-builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

COPY --from=frontend-builder /build/build /app/src/build

COPY src/api/ /app/

RUN mkdir -p /usr/share/fonts/custom && \
    ln -s /app/src/pdf/fonts/* /usr/share/fonts/custom/ 2>/dev/null || true && \
    fc-cache -fv

WORKDIR /app/src

EXPOSE 80

CMD ["python", "main.py"]
