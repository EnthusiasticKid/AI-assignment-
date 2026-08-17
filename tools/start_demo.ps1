$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backendDir = Join-Path $projectRoot "backend"
$frontendDir = Join-Path $projectRoot "frontend"
$runtimeDir = Join-Path (Split-Path $projectRoot -Parent) "tmp\db-query-runtime"
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

if (-not (docker ps --filter "name=^/db-query-mysql-proxy$" --format "{{.Names}}")) {
    docker run -d --rm `
        --name db-query-mysql-proxy `
        --network rzx_qz_analysis_source_app-net `
        -p 127.0.0.1:13306:3306 `
        alpine/socat `
        tcp-listen:3306,fork,reuseaddr `
        tcp-connect:mysql:3306 | Out-Null
}

$container = docker inspect rzx-expand | ConvertFrom-Json
$containerEnv = @{}
foreach ($item in $container[0].Config.Env) {
    $parts = $item -split "=", 2
    $containerEnv[$parts[0]] = $parts[1]
}
$mysqlUser = $containerEnv["MYSQL_USER"]
$mysqlPassword = $containerEnv["MYSQL_PASSWORD"]
if (-not $mysqlUser -or -not $mysqlPassword) {
    throw "MySQL credentials were not found in rzx-expand"
}
$databaseUrl = "mysql://$([uri]::EscapeDataString($mysqlUser)):$([uri]::EscapeDataString($mysqlPassword))@127.0.0.1:13306/rzx_qz"

$pidFile = Join-Path $runtimeDir "demo-backend.pid"
if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile
    if (Get-Process -Id $oldPid -ErrorAction SilentlyContinue) {
        Stop-Process -Id $oldPid
    }
}
$envFile = Join-Path $backendDir ".env"
$envFileHasKey = (Test-Path $envFile) -and (Select-String -LiteralPath $envFile -Pattern "^\s*(LLM_API_KEY|OPENAI_API_KEY|DEEPSEEK_API_KEY)\s*=\s*\S+" -Quiet)
$processHasKey = $env:LLM_API_KEY -or $env:OPENAI_API_KEY -or $env:DEEPSEEK_API_KEY
if (-not $processHasKey -and -not $envFileHasKey) {
    throw "LLM API key is missing. Add DEEPSEEK_API_KEY or OPENAI_API_KEY to backend/.env."
}
$env:DB_QUERY_DATA_DIR = $runtimeDir
$python = Join-Path $backendDir ".venv\Scripts\python.exe"
$backend = Start-Process -FilePath $python `
    -ArgumentList "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8000" `
    -WorkingDirectory $backendDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $runtimeDir "demo-backend.out.log") `
    -RedirectStandardError (Join-Path $runtimeDir "demo-backend.err.log") `
    -PassThru
Set-Content -LiteralPath $pidFile -Value $backend.Id

$ready = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 1
        if ($health.status -eq "healthy") {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Milliseconds 500
    }
}
if (-not $ready) {
    throw "Backend failed to start. See $runtimeDir\demo-backend.err.log"
}

$connectionBody = @{
    url = $databaseUrl
    dbType = "mysql"
    description = "MySQL Docker database"
} | ConvertTo-Json
Invoke-RestMethod `
    -Method Put `
    -Uri "http://127.0.0.1:8000/api/v1/dbs/rzx_mysql" `
    -ContentType "application/json" `
    -Body $connectionBody | Out-Null

if (docker ps -a --filter "name=^/db-query-frontend$" --format "{{.Names}}") {
    docker rm -f db-query-frontend | Out-Null
}
$mount = $frontendDir.Replace("\", "/")
docker run -d --rm `
    --name db-query-frontend `
    -p 127.0.0.1:5173:5173 `
    -v "${mount}:/app" `
    -w /app `
    node:20-alpine `
    sh -c "npm install --legacy-peer-deps && npm run dev -- --host 0.0.0.0" | Out-Null

Write-Output "Backend: http://127.0.0.1:8000"
Write-Output "API docs: http://127.0.0.1:8000/docs"
Write-Output "Frontend is starting: http://127.0.0.1:5173"
