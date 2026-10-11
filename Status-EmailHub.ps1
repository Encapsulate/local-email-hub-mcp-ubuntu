$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$python = Join-Path $root '.venv\Scripts\python.exe'
if (!(Test-Path -LiteralPath $python)) { throw 'Email Hub is not installed. Run Setup-EmailHub.cmd.' }
& $python (Join-Path $root 'email_hub.py') --health
Write-Host ''
if (Get-NetTCPConnection -State Listen -LocalAddress 127.0.0.1 -LocalPort 18477 -ErrorAction SilentlyContinue) {
    Write-Host 'MCP endpoint: ONLINE at http://127.0.0.1:18477/mcp' -ForegroundColor Green
} else {
    Write-Host 'MCP endpoint: OFFLINE; attempting recovery...' -ForegroundColor Yellow
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'Start-EmailHub.ps1')
    Start-Sleep -Seconds 2
    if (Get-NetTCPConnection -State Listen -LocalAddress 127.0.0.1 -LocalPort 18477 -ErrorAction SilentlyContinue) {
        Write-Host 'Recovery succeeded.' -ForegroundColor Green
    } else { Write-Host 'Recovery failed. Inspect the logs folder.' -ForegroundColor Red }
}

