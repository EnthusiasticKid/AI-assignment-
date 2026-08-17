$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runtimeDir = Join-Path (Split-Path $projectRoot -Parent) "tmp\db-query-runtime"
$pidFile = Join-Path $runtimeDir "demo-backend.pid"

if (Test-Path $pidFile) {
    $backendPid = Get-Content $pidFile
    if (Get-Process -Id $backendPid -ErrorAction SilentlyContinue) {
        Stop-Process -Id $backendPid
    }
    Remove-Item -LiteralPath $pidFile -Force
}

if (docker ps -a --filter "name=^/db-query-frontend$" --format "{{.Names}}") {
    docker rm -f db-query-frontend | Out-Null
}
if (docker ps -a --filter "name=^/db-query-mysql-proxy$" --format "{{.Names}}") {
    docker rm -f db-query-mysql-proxy | Out-Null
}

Write-Output "Database Query Tool stopped"
