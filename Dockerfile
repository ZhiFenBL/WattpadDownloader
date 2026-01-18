FROM node:20-alpine AS frontend-builder
WORKDIR /build
COPY src/frontend/package*.json .
RUN npm ci 
COPY src/frontend/. .
RUN npm run build

FROM python:3.13-alpine AS python-builder
WORKDIR /app
RUN apk add --no-cache \
    build-base \
    python3-dev \
    git \
    libffi-dev \
    musl-dev
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/
COPY src/api/pyproject.toml /app/
RUN uv sync --no-dev --compile

FROM python:3.13-alpine

WORKDIR /app

RUN apk add --no-cache \
    aria2 \
    glib \
    pango \
    cairo \
    libffi \
    gdk-pixbuf \
    fontconfig \
    font-noto \
    font-noto-cjk
    
COPY --from=python-builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

COPY --from=frontend-builder /build/build /app/src/build

COPY src/api/ /app/

RUN mkdir -p /tmp/fonts && \
    ln -s /app/src/create_book/generators/pdf/fonts/* /tmp/fonts 2>/dev/null || true && \
    fc-cache -fv
    
WORKDIR /app/src

EXPOSE 80

CMD ["python", "main.py"]
