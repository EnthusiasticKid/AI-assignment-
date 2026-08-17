---
description: Execute a database query and export it to CSV or JSON
argument-hint: <database> <csv|json> <SELECT statement>
allowed-tools: Bash(python tools/query_export.py *)
---

Export a database query result using the project's safe query API.

Parse `$ARGUMENTS` as a database connection name, an export format (`csv` or `json`),
and a SELECT statement. Then run:

```bash
python tools/query_export.py <database> <format> "<SELECT statement>"
```

Report the absolute output path. If the backend is unavailable, explain that it must
be started first with `make dev-backend`. Never rewrite a non-SELECT statement to
bypass the backend SQL validator.
