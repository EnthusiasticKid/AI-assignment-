"""Tests for query result export serialization."""

import csv
import io
import json
import os
from datetime import datetime
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

os.environ.setdefault("OPENAI_API_KEY", "test-key")

from app.api.v1 import queries  # noqa: E402
from app.models.database import DatabaseType  # noqa: E402
from app.models.schemas import QueryColumn, QueryResult
from app.services.export import export_query_result


def sample_result() -> QueryResult:
    return QueryResult(
        columns=[
            QueryColumn(name="id", dataType="integer"),
            QueryColumn(name="name", dataType="character varying"),
            QueryColumn(name="amount", dataType="numeric"),
            QueryColumn(name="created_at", dataType="timestamp"),
        ],
        rows=[
            {
                "id": 1,
                "name": "张三",
                "amount": Decimal("12.50"),
                "created_at": datetime(2026, 8, 17, 9, 30),
            }
        ],
        rowCount=1,
        executionTimeMs=8,
        sql="SELECT * FROM users LIMIT 1000",
    )


def test_export_csv_has_bom_headers_and_chinese() -> None:
    content = export_query_result(sample_result(), "csv")

    assert content.startswith(b"\xef\xbb\xbf")
    rows = list(csv.DictReader(io.StringIO(content.decode("utf-8-sig"))))
    assert rows[0]["name"] == "张三"
    assert rows[0]["amount"] == "12.50"


def test_export_json_has_metadata_and_serializes_database_values() -> None:
    content = export_query_result(sample_result(), "json")
    payload = json.loads(content)

    assert payload["rowCount"] == 1
    assert payload["columns"][0] == {"name": "id", "dataType": "integer"}
    assert payload["rows"][0]["name"] == "张三"
    assert payload["rows"][0]["amount"] == "12.50"
    assert payload["rows"][0]["created_at"] == "2026-08-17T09:30:00"


@pytest.mark.asyncio
async def test_execute_and_export_endpoint_returns_download(monkeypatch) -> None:
    connection = SimpleNamespace(
        db_type=DatabaseType.POSTGRESQL,
        url="postgresql://example/test",
    )
    query_result = sample_result()
    execute = AsyncMock(return_value=query_result)
    monkeypatch.setattr(queries, "execute_query_with_service", execute)

    class Result:
        @staticmethod
        def first():
            return connection

    class SessionStub:
        @staticmethod
        def exec(_statement):
            return Result()

    response = await queries.execute_and_export_query(
        "test-db",
        queries.QueryInput(sql="SELECT * FROM users"),
        "json",
        SessionStub(),
    )
    content = b"".join([chunk async for chunk in response.body_iterator])

    assert json.loads(content)["rowCount"] == 1
    assert response.headers["content-disposition"].endswith('.json"')
    assert response.headers["x-query-row-count"] == "1"
    execute.assert_awaited_once()
