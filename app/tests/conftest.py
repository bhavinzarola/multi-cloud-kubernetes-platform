"""Shared pytest fixtures for the eks-demo-app test suite."""

import pytest
from fastapi.testclient import TestClient

from src.main import create_app


@pytest.fixture
def client() -> TestClient:
    """Return a TestClient wrapping a freshly created app instance."""
    app = create_app()
    return TestClient(app)
