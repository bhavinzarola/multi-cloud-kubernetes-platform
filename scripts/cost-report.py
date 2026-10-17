#!/usr/bin/env python3
"""Print estimated AWS cost broken down by namespace/tag using Cost Explorer.

Maps cluster costs to Kubernetes namespaces via the 'Environment' and
'Project' cost-allocation tags applied by Terraform (see terraform/modules/*
and required_tags in policies/opa/terraform.rego).

Usage:
    python3 scripts/cost-report.py [--days 7] [--project eks-platform-gitops]

Requires: boto3, and AWS credentials with ce:GetCostAndUsage permission.
"""

from __future__ import annotations

import argparse
import datetime as dt
import logging

import boto3

logger = logging.getLogger("cost-report")
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=7, help="Lookback window in days")
    parser.add_argument(
        "--project", type=str, default="eks-platform-gitops", help="Value of the Project tag to filter on"
    )
    return parser.parse_args()


def fetch_cost_by_environment(days: int, project: str) -> list[dict]:
    """Query Cost Explorer, grouped by the 'Environment' cost-allocation tag."""
    client = boto3.client("ce")
    end = dt.date.today()
    start = end - dt.timedelta(days=days)

    response = client.get_cost_and_usage(
        TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
        Granularity="DAILY",
        Metrics=["UnblendedCost"],
        Filter={
            "Tags": {"Key": "Project", "Values": [project]},
        },
        GroupBy=[{"Type": "TAG", "Key": "Environment"}],
    )
    return response.get("ResultsByTime", [])


def summarize(results: list[dict]) -> dict[str, float]:
    totals: dict[str, float] = {}
    for period in results:
        for group in period.get("Groups", []):
            key = group["Keys"][0].split("$")[-1] or "untagged"
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            totals[key] = totals.get(key, 0.0) + amount
    return totals


def main() -> None:
    args = parse_args()
    logger.info("Fetching cost data for project=%s over the last %d days...", args.project, args.days)

    try:
        results = fetch_cost_by_environment(args.days, args.project)
    except Exception:  # noqa: BLE001
        logger.exception("Failed to query Cost Explorer. Check credentials/permissions.")
        raise SystemExit(1) from None

    totals = summarize(results)
    if not totals:
        logger.info("No cost data found for the given filters.")
        return

    print(f"\nEstimated cost by environment (last {args.days} days):")
    print("-" * 45)
    for env, amount in sorted(totals.items(), key=lambda kv: kv[1], reverse=True):
        print(f"  {env:<20} ${amount:>10.2f}")
    print("-" * 45)
    print(f"  {'TOTAL':<20} ${sum(totals.values()):>10.2f}\n")


if __name__ == "__main__":
    main()
