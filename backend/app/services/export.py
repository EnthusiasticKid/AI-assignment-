"""Serialize query results into downloadable files."""

import csv
import io
import json
from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from app.models.schemas import QueryResult

ExportFormat = Literal["csv", "json"]


def _json_default(value: object) -> str:
    """Convert common database values into JSON-safe strings."""
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, Decimal):
        return str(value)
    return str(value)


def export_query_result(result: QueryResult, export_format: ExportFormat) -> bytes:
    """Return a query result encoded as CSV or JSON bytes."""
    if export_format == "csv":
        output = io.StringIO(newline="")
        column_names = [column.name for column in result.columns]
        writer = csv.DictWriter(output, fieldnames=column_names, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(result.rows)
        # A UTF-8 BOM keeps Chinese text readable when opened directly in Excel.
        return output.getvalue().encode("utf-8-sig")

    if export_format == "json":
        payload = {
            "sql": result.sql,
            "rowCount": result.row_count,
            "executionTimeMs": result.execution_time_ms,
            "columns": [column.model_dump(by_alias=True) for column in result.columns],
            "rows": result.rows,
        }
        return json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
            default=_json_default,
        ).encode("utf-8")

    raise ValueError(f"Unsupported export format: {export_format}")


def media_type_for(export_format: ExportFormat) -> str:
    """Return the response media type for an export format."""
    if export_format == "csv":
        return "text/csv; charset=utf-8"
    return "application/json; charset=utf-8"
