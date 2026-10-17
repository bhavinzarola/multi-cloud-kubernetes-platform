# syntax=docker/dockerfile:1.7

# ---- Build stage: install dependencies into a venv ----
FROM python:3.12-slim AS builder

WORKDIR /build

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ---- Final stage: minimal runtime image ----
FROM python:3.12-slim AS runtime

LABEL org.opencontainers.image.title="eks-demo-app" \
      org.opencontainers.image.description="Sample FastAPI microservice for eks-platform-gitops" \
      org.opencontainers.image.source="https://github.com/your-org/eks-platform-gitops" \
      org.opencontainers.image.licenses="MIT"

# Non-root user
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --shell /usr/sbin/nologin --no-create-home appuser

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY src ./src

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_PORT=8080

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health', timeout=2)" || exit 1

ENTRYPOINT ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
