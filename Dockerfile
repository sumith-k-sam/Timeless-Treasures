# --- Stage 1: Builder ---
FROM python:3.13-alpine AS builder

WORKDIR /app

# Install build dependencies required for compiling Python packages
RUN apk add --no-cache gcc musl-dev linux-headers

# Create a virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies into the virtual environment
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# --- Stage 2: Final Slim Runtime Image ---
FROM python:3.13-alpine

WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# 1. Copy project files as root
COPY . .

# 2. Collect static files as root (avoids permission denied errors)
RUN SECRET_KEY='dummy-key-for-build-only' python manage.py collectstatic --noinput

# 3. Create non-root user and give them ownership of the entire /app directory
RUN adduser -D appuser && chown -R appuser:appuser /app

# 4. Switch to non-root user for runtime security
USER appuser

# Set Django settings module
ENV DJANGO_SETTINGS_MODULE=watch.settings \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# Run with Gunicorn (Production WSGI server)
CMD ["gunicorn", "watch.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4"]
