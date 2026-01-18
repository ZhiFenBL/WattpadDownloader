# Stage 1: Frontend Builder (Uses Alpine for speed/size)
FROM node:20-alpine AS frontend-builder
WORKDIR /build
COPY src/frontend/package*.json .
# Use 'ci' for faster, reliable builds based on lockfile
RUN npm ci 
COPY src/frontend/. .
RUN npm run build

# Stage 2: Python Builder (Compiles dependencies)
# We use 'slim' (Debian) here to avoid Alpine C-compiler headaches with Python wheels
FROM python:3.13-slim AS python-builder

WORKDIR /app

# Install compilers just for this stage
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

COPY src/api/pyproject.toml /app/

# Compile the venv so we don't need 'uv' in the final image
RUN uv sync --no-dev --compile

# Stage 3: Final Runtime Image
# We use 'slim' (Debian) for best compatibility with PDF/Font libraries
FROM python:3.13-slim

WORKDIR /app

# Install ONLY the runtime libraries needed for PDF generation
# Added 'libglib2.0-0' based on their update
# Added 'libcairo2', 'fontconfig', 'fonts-dejavu' to fix the PDF hang
RUN apt-get update && apt-get install -y --no-install-recommends \
    aria2 \
    libglib2.0-0 \
    libgobject-2.0-0 \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libcairo2 \
    libfontconfig1 \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Copy the pre-compiled virtual environment
COPY --from=python-builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Copy the built frontend
COPY --from=frontend-builder /build/build /app/src/build

# Copy the API source code to the ROOT /app/ folder (Fixes the "file not found" error)
COPY src/api/ /app/

# Register custom fonts properly with the system
RUN mkdir -p /usr/share/fonts/custom && \
    ln -s /app/src/pdf/fonts/* /usr/share/fonts/custom/ 2>/dev/null || true && \
    fc-cache -fv

WORKDIR /app/src

EXPOSE 80

# Run directly with python (faster startup than 'uv run')
CMD ["python", "main.py"]
