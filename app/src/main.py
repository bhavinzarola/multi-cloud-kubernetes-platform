"""Application entrypoint for the eks-demo-app FastAPI microservice."""

import logging
import sys

from fastapi import FastAPI
from pythonjsonlogger import jsonlogger

from src.config import get_settings
from src.metrics import setup_metrics
from src.routes import api, health


def configure_logging(log_level: str) -> None:
    """Configure structured JSON logging to stdout.

    12-factor apps log to stdout/stderr and let the platform (Fluent Bit /
    Promtail, shipping to Loki in this stack) handle aggregation.
    """
    handler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter("%(asctime)s %(name)s %(levelname)s %(message)s")
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.handlers = [handler]
    root_logger.setLevel(log_level.upper())


def create_app() -> FastAPI:
    """Application factory: builds and returns the configured FastAPI app."""
    settings = get_settings()
    configure_logging(settings.log_level)

    app = FastAPI(
        title=settings.app_name,
        description="Sample microservice demonstrating the eks-platform-gitops platform",
        version="0.1.0",
    )

    app.include_router(health.router)
    app.include_router(api.router)

    setup_metrics(app)

    logging.getLogger(__name__).info(
        "application startup complete", extra={"environment": settings.environment}
    )

    return app


app = create_app()

if __name__ == "__main__":
    import uvicorn

    settings = get_settings()
    uvicorn.run("main:app", host="0.0.0.0", port=settings.port, reload=False)
