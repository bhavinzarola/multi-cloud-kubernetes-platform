"""12-factor application configuration, sourced from environment variables.

In-cluster, these values are populated from a ConfigMap (non-secret config)
and an ExternalSecret (secret config, synced from AWS Secrets Manager) — see
kubernetes/base/externalsecret.yaml and app/helm/eks-demo-app/templates/configmap.yaml.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration for the eks-demo-app service."""

    model_config = SettingsConfigDict(env_prefix="APP_", case_sensitive=False)

    app_name: str = "eks-demo-app"
    environment: str = "dev"
    log_level: str = "INFO"
    port: int = 8080

    # Example of a value that would come from an ExternalSecret in real use.
    database_url: str = "sqlite:///./local.db"

    # Feature flag example, sourced from the ConfigMap.
    feature_new_items_endpoint: bool = True


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance (avoids re-parsing env vars per request)."""
    return Settings()
