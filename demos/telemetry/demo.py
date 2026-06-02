#!/usr/bin/env python3
"""
Telemetry Demo - Query OGX metrics via Grafana

Shows request counts, latency percentiles, error rates, and inference
throughput collected via the OTEL Collector -> Prometheus pipeline.
Queries are proxied through Grafana's datasource API (route enabled by default).

Usage:
    uv run demos/telemetry/demo.py
"""

import sys
from pathlib import Path

import requests

# Add project root to path for imports
PROJECT_ROOT = Path(__file__).parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from demos.common.utils import load_demo_config

QUERIES = [
    ("Total Requests", "sum(ogx_requests_total) by (api)", "requests"),
    ("Request Rate (5m)", "sum(rate(ogx_requests_total[5m])) by (api)", "req/s"),
    ("Error Rate (5m)", "sum(rate(ogx_requests_total{status='error'}[5m])) / sum(rate(ogx_requests_total[5m]))", "ratio"),
    ("Concurrent Requests", "sum(ogx_concurrent_requests) by (api)", ""),
    ("Latency p50", "histogram_quantile(0.50, sum(rate(ogx_request_duration_seconds_bucket[5m])) by (le))", "s"),
    ("Latency p95", "histogram_quantile(0.95, sum(rate(ogx_request_duration_seconds_bucket[5m])) by (le))", "s"),
    ("Latency p99", "histogram_quantile(0.99, sum(rate(ogx_request_duration_seconds_bucket[5m])) by (le))", "s"),
    ("Inference p95 by Model", "histogram_quantile(0.95, sum(rate(ogx_inference_duration_seconds_bucket[5m])) by (le, model))", "s"),
    ("Tokens/s by Model (p50)", "histogram_quantile(0.50, sum(rate(ogx_inference_tokens_per_second_bucket[5m])) by (le, model))", "tok/s"),
    ("Vector IO Inserts (5m)", "sum(rate(ogx_vector_io_inserts_total[5m]))", "ops/s"),
    ("Vector Stores Created", "sum(ogx_vector_io_stores_total)", ""),
]


def get_datasource_proxy_url(session, grafana_url):
    resp = session.get(f"{grafana_url}/api/datasources", timeout=10)
    resp.raise_for_status()
    for ds in resp.json():
        if ds.get("type") == "prometheus":
            return f"{grafana_url}/api/datasources/proxy/{ds['id']}"
    return None


def query_prometheus(session, proxy_url, expr):
    resp = session.get(f"{proxy_url}/api/v1/query", params={"query": expr}, timeout=10)
    resp.raise_for_status()
    data = resp.json()
    if data.get("status") != "success":
        return None
    return data["data"]["result"]


def format_value(value, unit):
    try:
        v = float(value)
    except (ValueError, TypeError):
        return str(value)
    if unit == "ratio":
        return f"{v:.2%}"
    if unit == "s":
        if v < 0.001:
            return f"{v*1e6:.0f}us"
        if v < 1:
            return f"{v*1000:.1f}ms"
        return f"{v:.2f}s"
    if unit in ("req/s", "ops/s", "tok/s"):
        return f"{v:.2f} {unit}"
    if v == int(v):
        return f"{int(v)}"
    return f"{v:.2f}"


def main():
    print("=" * 60)
    print("OGX Telemetry Demo")
    print("=" * 60)

    config = load_demo_config()

    grafana_url = config['grafana_url']
    if not grafana_url:
        print("\nError: Grafana URL is required")
        print("Set GRAFANA_URL env var or ensure the Grafana route exists")
        sys.exit(1)

    grafana_url = grafana_url.rstrip("/")
    print(f"\nGrafana: {grafana_url}")

    password = config['grafana_password']
    session = requests.Session()
    if password:
        session.auth = ("admin", password)
    else:
        print("Warning: No Grafana admin password found, trying without auth")

    try:
        proxy_url = get_datasource_proxy_url(session, grafana_url)
    except Exception as e:
        print(f"Cannot reach Grafana: {e}")
        sys.exit(1)

    if not proxy_url:
        print("No Prometheus datasource found in Grafana")
        sys.exit(1)

    print("Prometheus datasource: OK")
    print(f"Dashboard: {grafana_url}/d/ogx-overview/ogx-overview")
    print()

    has_data = False
    for title, expr, unit in QUERIES:
        try:
            results = query_prometheus(session, proxy_url, expr)
        except Exception as e:
            print(f"  {title:30s}  error: {e}")
            continue

        if not results:
            print(f"  {title:30s}  (no data)")
            continue

        has_data = True
        if len(results) == 1 and not results[0]["metric"]:
            val = format_value(results[0]["value"][1], unit)
            print(f"  {title:30s}  {val}")
        else:
            print(f"  {title}:")
            for r in results:
                labels = r["metric"]
                label_str = ", ".join(f"{k}={v}" for k, v in labels.items() if k != "__name__")
                val = format_value(r["value"][1], unit)
                print(f"    {label_str or '-':26s}  {val}")

    if not has_data:
        print("  No OGX metrics found. Generate some traffic first")
        print("  (e.g. uv run demos/hello/demo.py)")

    print()
    print("=" * 60)


if __name__ == "__main__":
    main()
