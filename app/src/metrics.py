"""Prometheus instrumentation for the FastAPI application."""

from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator


def setup_metrics(app: FastAPI) -> None:
    """Attach Prometheus instrumentation and expose the /metrics endpoint.

    A ServiceMonitor (see app/helm/eks-demo-app/templates/servicemonitor.yaml)
    scrapes this endpoint from the kube-prometheus-stack Prometheus instance.
    """
    instrumentator = Instrumentator(
        should_group_status_codes=True,
        should_ignore_untemplated=True,
        excluded_handlers=["/metrics", "/health"],
    )
    instrumentator.instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)
