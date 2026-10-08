# Database Query Tool

## 第五章研发作业：PostgreSQL MCP

第五章第四节 Codex Review 对应的研发作业已完成，代码位于 [`w5/pg-mcp`](w5/pg-mcp)。

- [实现与验收说明](w5/pg-mcp/HOMEWORK.md)
- [安装运行指南](w5/pg-mcp/README.md)
- [测试报告](w5/pg-mcp/test-results.xml)
- [覆盖率数据](w5/pg-mcp/coverage.json)

本次实现多数据库路由、表/列与 EXPLAIN 安全策略、并发限流、退避重试、熔断、指标追踪和响应模型修复。验证结果：**346 项测试通过、整体覆盖率 90.94%**；46 项需真实数据库/API 的测试明确跳过。

A web-based tool for managing PostgreSQL database connections, viewing metadata, and executing SQL queries with natural language support.

## 项目来源

本项目基于极客时间 AI 训练营提供的“数据库查询工具”进行作业扩展：

- 原始仓库：https://github.com/tyrchen/geektime-bootcamp-ai
- 原始代码目录：`w2/db_query`
- 原项目作者：陈天（tyrchen）及相关贡献者

本次作业主要新增和完善了以下内容：

- CSV、JSON 查询结果导出
- “执行查询并导出”的一键自动化流程
- Claude Code `/query-export` 自定义 Command
- 自然语言生成 SQL 后的同页执行与导出交互
- OpenAI 兼容接口及 DeepSeek 模型配置支持
- 导出功能测试、真实 MySQL 验证和 `FEATURE_EXPORT.md` 设计文档

除上述扩展外，项目的基础架构和原有数据库查询能力来自训练营提供的原始代码。
原项目版权及相关权利归原作者所有。

## Project Structure

```
w2/db_query/
├── backend/          # FastAPI backend (Python 3.12+)
├── frontend/         # React frontend (TypeScript, Refine 5)
├── fixtures/         # REST Client test files
│   ├── test.rest     # API test requests
│   └── README.md     # Testing guide
└── Makefile          # Development commands
```

## Quick Start

### Initial Setup

```bash
# Install all dependencies
make install

# Setup database and environment
make setup
# Then edit backend/.env and add your OPENAI_API_KEY

# Start development servers
make dev
```

### Development Commands

```bash
# View all available commands
make help

# Start backend only
make dev-backend

# Start frontend only
make dev-frontend

# Run tests
make test

# Format code
make format

# Run linters
make lint
```

## API Testing

### Using REST Client (VSCode)

1. Install [REST Client extension](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
2. Open `fixtures/test.rest`
3. Click "Send Request" above any HTTP request
4. View responses in VSCode panel

See `fixtures/README.md` for detailed testing guide.

## Query Result Export

The query page provides **Run & Export CSV** and **Run & Export JSON** buttons.
Each button performs the complete workflow in one action: validate the SELECT
statement, execute it, format the result, download the file, and add the query to
history.

The same workflow is available through the API:

```bash
curl -X POST "http://localhost:8000/api/v1/dbs/my_database/query/export?format=csv" \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM users"}' \
  --output users.csv
```

Or through the dependency-free helper script:

```bash
python tools/query_export.py my_database json "SELECT * FROM users"
```

Claude Code users can invoke the custom command as:

```text
/query-export my_database csv SELECT * FROM users
```

See `FEATURE_EXPORT.md` for the design, error handling, and verification details.

### Using Makefile

```bash
# Check if backend is running
make health

# Open API documentation
make docs
```

## Phase 1 Status

✅ **Phase 1 Complete**: All setup and foundation tasks completed.

- Backend project structure initialized
- Frontend project structure initialized
- Core infrastructure (FastAPI, database, models) ready
- Data models defined with camelCase API convention
- Makefile with common development tasks
- REST Client test file for API testing

## Next Steps

Proceed to Phase 2 for core feature implementation (US1 + US2).
