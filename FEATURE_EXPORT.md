# 数据导出功能设计说明

## 1. 功能目标

在原有智能数据库查询工具上增加 CSV 和 JSON 两种导出格式，并将“执行查询、
格式化数据、创建文件、下载结果”组合为一个简单操作。用户可以从网页点击按钮，
也可以通过 Claude Code 自定义命令触发同一流程。

## 2. 原项目理解与切入点

项目采用前后端分离结构：

- 后端使用 FastAPI，`POST /api/v1/dbs/{name}/query` 负责执行查询。
- 查询服务会验证 SQL，只允许安全的只读查询，并将结果统一为 `QueryResult`。
- `QueryResult` 包含字段定义、数据行、行数、耗时和实际执行的 SQL。
- 前端使用 React、TypeScript 和 Ant Design，查询页面位于
  `frontend/src/pages/queries/execute.tsx`。

因此，导出功能复用现有查询服务，在统一结果生成之后增加独立的序列化层，避免将
CSV/JSON 逻辑混入数据库连接代码。

## 3. 功能设计

### 3.1 后端导出服务

`backend/app/services/export.py` 提供统一的 `export_query_result` 函数：

- CSV：按照 `columns` 的顺序输出表头和数据，使用 UTF-8 BOM，确保包含中文的
  文件直接用 Excel 打开时不会乱码。
- JSON：输出 SQL、字段信息、行数、执行耗时和数据行，保留完整查询上下文。
- 日期时间转换为 ISO 8601 字符串，Decimal 转换为字符串，避免精度丢失。

### 3.2 一键查询并导出接口

新增接口：

```text
POST /api/v1/dbs/{name}/query/export?format=csv|json
Body: { "sql": "SELECT ..." }
```

接口内部依次完成：

1. 检查数据库连接是否存在。
2. 调用原有查询服务验证并执行 SQL。
3. 将 `QueryResult` 格式化为 CSV 或 JSON。
4. 生成带数据库名称和 UTC 时间戳的文件名。
5. 通过附件响应返回文件，并在响应头中提供结果行数。

格式参数使用枚举约束；错误的格式会返回 422。SQL 验证错误返回 400，数据库或
文件生成错误返回 500，不存在的数据库连接返回 404。

### 3.3 前端交互

查询页面增加两个按钮：

- `Run & Export CSV`
- `Run & Export JSON`

用户输入 SQL 后点击任一按钮，浏览器会自动调用导出接口并下载文件。自然语言生成
SQL 后不会强制跳转标签，而是在当前标签直接显示生成的 SQL，并提供“执行查询”、
“执行并导出 CSV”和“执行并导出 JSON”三个操作。执行结果继续显示在同一页面下方，
用户可以随时切换到 Manual SQL 修改语句。

### 3.4 Claude Code 自动化

`.claude/commands/query-export.md` 定义 `/query-export` 自定义命令。命令把任务拆分
为参数识别、调用安全查询接口、接收文件、保存文件和报告路径几个步骤，并调用
`tools/query_export.py` 完成实际请求。

示例：

```text
/query-export my_database csv SELECT id, name FROM users
```

命令行脚本只使用 Python 标准库，不需要额外安装 HTTP 客户端：

```bash
python tools/query_export.py my_database json "SELECT id, name FROM users"
```

## 4. Agent 任务分解

本功能按以下子任务组织，便于 Agent 逐步执行和定位错误：

1. 获取数据库名称、导出格式和 SQL。
2. 检查参数是否合法。
3. 通过原查询服务验证并执行 SQL。
4. 获取统一的查询结果。
5. 按目标格式序列化。
6. 创建并返回文件。
7. 向用户报告结果或明确的失败原因。

前端、命令行和 Claude Command 都调用同一个后端接口，避免三套实现产生不一致。

## 5. 安全性和边界处理

- 继续复用原项目 SQL 校验器，不绕过只读查询限制和 1000 行限制。
- 文件名只保留字母、数字、下划线和连字符，避免路径注入。
- CSV 使用固定字段顺序，忽略查询结果中的意外额外键。
- 中文使用 UTF-8 编码；CSV 额外加入 BOM。
- JSON 对日期和 Decimal 等数据库常见类型进行显式转换。
- 浏览器端使用服务端提供的附件文件名，下载后及时释放临时 Blob URL。

## 6. 使用步骤

1. 按项目 README 安装依赖并配置数据库连接。
2. 启动后端和前端：`make dev`。
3. 打开数据库查询页面并输入 SELECT SQL。
4. 点击 `Run & Export CSV` 或 `Run & Export JSON`。
5. 在浏览器下载目录检查导出文件。

自然语言生成 SQL 支持 OpenAI 兼容接口。使用 DeepSeek 时，在 `backend/.env` 中配置：

```env
DEEPSEEK_API_KEY=你的DeepSeek密钥
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-v4-flash
```

## 7. 测试与验证

新增 `backend/tests/unit/test_export.py`，覆盖：

- CSV 表头、数据内容、中文和 UTF-8 BOM。
- JSON 元数据、中文、日期时间和 Decimal 序列化。

验证命令：

```bash
cd backend
uv sync --extra dev
uv run pytest tests/unit/test_export.py -q
uv run ruff check app/services/export.py app/api/v1/queries.py tests/unit/test_export.py
```

本次新增测试结果为 `3 passed`（包含导出接口下载响应测试），新增和修改的核心后端
代码通过 Ruff 和 Mypy 检查。老师原始
仓库的全量测试存在测试代码与当前重构实现不一致的问题，例如仍然 mock 已移除的
`get_connection_pool` 和 `execute_query` 导入点；该既有问题不影响导出模块的专项测试。
前端已在 Node.js 20 Docker 环境中执行 `npm run build`，TypeScript 检查和 Vite
生产构建均通过。

### 真实 MySQL 容器验证

已使用运行中的 MySQL 8.0 容器对完整链路进行验证。后端连接 `rzx_qz` 数据库，执行
了只读的 `information_schema.tables` 查询，并分别调用 CSV 和 JSON 导出接口：

- 查询返回 10 行，接口记录的执行耗时为 2ms。
- CSV 文件为 246 字节，表头和 10 行数据正确。
- JSON 文件为 1123 字节，包含 SQL、字段类型、行数、耗时和数据行。
- 验证过程没有创建、更新或删除 MySQL 业务数据。

实际输出保存在 `verification/mysql_tables.csv` 和
`verification/mysql_tables.json`。复现脚本为 `tools/verify_mysql_export.ps1`，脚本会
临时建立本机到 Docker 内网 MySQL 的端口代理，并在验证完成后自动停止代理和测试后端。

## 8. Cursor 与 Claude Code 的协作思路

- Cursor 适合快速查看类型、跳转调用链、修改前端组件并获得即时类型提示。
- Claude Code 适合把“查询、格式化、创建文件、报告结果”编排成可重复的一条命令。
- 两者共享后端导出接口作为稳定边界：界面迭代不会改变自动化脚本，Agent 流程调整
  也不会复制数据库查询逻辑。
