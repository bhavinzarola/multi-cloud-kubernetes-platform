"""Tests for the /api/v1/items routes."""

from fastapi.testclient import TestClient


def test_list_items_returns_sample_data(client: TestClient) -> None:
    response = client.get("/api/v1/items")
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 3
    assert items[0]["name"] == "widget"


def test_get_item_returns_matching_item(client: TestClient) -> None:
    response = client.get("/api/v1/items/2")
    assert response.status_code == 200
    assert response.json()["name"] == "gadget"


def test_get_item_returns_null_for_missing_id(client: TestClient) -> None:
    response = client.get("/api/v1/items/999")
    assert response.status_code == 200
    assert response.json() is None


def test_metrics_endpoint_is_exposed(client: TestClient) -> None:
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"python_info" in response.content or b"# HELP" in response.content
