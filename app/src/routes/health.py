"""Liveness and readiness endpoints used by Kubernetes probes."""

import logging

from fastapi import APIRouter, HTTPException, status

from src.config import get_settings

logger = logging.getLogger(__name__)
router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    """Liveness probe target: returns 200 as long as the process is alive."""
    return {"status": "ok"}


@router.get("/ready")
def ready() -> dict[str, str]:
    """Readiness probe target: verifies the service's dependencies are reachable.

    In this demo, dependency health is simulated. Wire this up to a real DB
    ping, cache ping, or upstream health check in a production service.
    """
    settings = get_settings()

    dependency_healthy = _check_dependency(settings.database_url)
    if not dependency_healthy:
        logger.warning("readiness check failed: dependency unavailable")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="dependency not ready",
        )

    return {"status": "ready"}


def _check_dependency(database_url: str) -> bool:
    """Placeholder dependency check. Replace with a real connectivity check."""
    return bool(database_url)
