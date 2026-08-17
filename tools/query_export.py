"""Run a SQL query through the API and save the exported result."""

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Execute a query and export CSV or JSON")
    parser.add_argument("database", help="Configured database connection name")
    parser.add_argument("format", choices=("csv", "json"))
    parser.add_argument("sql", help="SELECT query to execute")
    parser.add_argument("--api", default="http://localhost:8000", help="Backend base URL")
    parser.add_argument("--output", type=Path, help="Optional destination path")
    args = parser.parse_args()

    endpoint = (
        f"{args.api.rstrip('/')}/api/v1/dbs/"
        f"{urllib.parse.quote(args.database, safe='')}/query/export?format={args.format}"
    )
    body = json.dumps({"sql": args.sql}).encode("utf-8")
    request = urllib.request.Request(
        endpoint,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request) as response:
            content = response.read()
            disposition = response.headers.get("Content-Disposition", "")
    except urllib.error.HTTPError as exc:
        print(exc.read().decode("utf-8", errors="replace"), file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"Cannot connect to backend: {exc.reason}", file=sys.stderr)
        return 1

    match = re.search(r'filename="?([^";]+)', disposition)
    destination = args.output or Path(match.group(1) if match else f"query_result.{args.format}")
    destination.write_bytes(content)
    print(f"Exported to {destination.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
