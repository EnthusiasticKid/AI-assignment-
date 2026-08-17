$ErrorActionPreference = "Stop"

$proxyName = "db-query-mysql-proxy"
$proxyRunning = docker ps --filter "name=^/$proxyName$" --format "{{.Names}}"
$proxyStarted = $false
if ($proxyRunning -ne $proxyName) {
    docker run -d --rm `
        --name $proxyName `
        --network rzx_qz_analysis_source_app-net `
        -p 127.0.0.1:13306:3306 `
        alpine/socat `
        tcp-listen:3306,fork,reuseaddr `
        tcp-connect:mysql:3306 | Out-Null
    $proxyStarted = $true
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
    throw "MySQL credentials were not found in the rzx-expand container environment"
}

$encodedUser = [uri]::EscapeDataString($mysqlUser)
$encodedPassword = [uri]::EscapeDataString($mysqlPassword)
$databaseUrl = "mysql://${encodedUser}:${encodedPassword}@127.0.0.1:13306/rzx_qz"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$backendDir = Join-Path $projectRoot "backend"
$runtimeDir = Join-Path (Split-Path $projectRoot -Parent) "tmp\db-query-runtime"
$outputDir = Join-Path $projectRoot "verification"
New-Item -ItemType Directory -Force -Path $runtimeDir, $outputDir | Out-Null

$env:OPENAI_API_KEY = "test-key"
$env:DB_QUERY_DATA_DIR = $runtimeDir
$python = Join-Path $backendDir ".venv\Scripts\python.exe"
$process = Start-Process -FilePath $python `
    -ArgumentList "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "18000" `
    -WorkingDirectory $backendDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $runtimeDir "backend.out.log") `
    -RedirectStandardError (Join-Path $runtimeDir "backend.err.log") `
    -PassThru

try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:18000/health" -TimeoutSec 1
            if ($health.status -eq "healthy") {
                $ready = $true
                break
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $ready) {
        throw "Backend did not become ready"
    }

    $connectionBody = @{
        url = $databaseUrl
        dbType = "mysql"
        description = "MySQL Docker verification"
    } | ConvertTo-Json
    Invoke-RestMethod `
        -Method Put `
        -Uri "http://127.0.0.1:18000/api/v1/dbs/rzx_mysql" `
        -ContentType "application/json" `
        -Body $connectionBody | Out-Null

    $queryBody = @{
        sql = "SELECT TABLE_NAME, TABLE_ROWS FROM information_schema.tables WHERE table_schema = 'rzx_qz' ORDER BY TABLE_NAME LIMIT 10"
    } | ConvertTo-Json

    Invoke-WebRequest `
        -Method Post `
        -Uri "http://127.0.0.1:18000/api/v1/dbs/rzx_mysql/query/export?format=csv" `
        -ContentType "application/json" `
        -Body $queryBody `
        -OutFile (Join-Path $outputDir "mysql_tables.csv")
    Invoke-WebRequest `
        -Method Post `
        -Uri "http://127.0.0.1:18000/api/v1/dbs/rzx_mysql/query/export?format=json" `
        -ContentType "application/json" `
        -Body $queryBody `
        -OutFile (Join-Path $outputDir "mysql_tables.json")

    $csv = Get-Item (Join-Path $outputDir "mysql_tables.csv")
    $json = Get-Item (Join-Path $outputDir "mysql_tables.json")
    Write-Output "CSV=$($csv.FullName) ($($csv.Length) bytes)"
    Write-Output "JSON=$($json.FullName) ($($json.Length) bytes)"
} finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id
    }
    if ($proxyStarted) {
        docker stop $proxyName | Out-Null
    }
}
