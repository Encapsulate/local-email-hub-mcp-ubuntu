$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$venvPython = Join-Path $root '.venv\Scripts\python.exe'

function Find-CompatiblePython {
    $bundled = Join-Path $root 'runtime\python\python.exe'
    if (Test-Path -LiteralPath $bundled) { return $bundled }
    $command = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($command) {
        $compatible = & $command.Source -c "import sys; print(int((3,11) <= sys.version_info[:2] < (3,15)))"
        if ($compatible -eq '1') { return $command.Source }
    }
    $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcher) {
        $candidate = & $launcher.Source -3 -c "import sys; print(sys.executable)" 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    throw 'Python 3.11-3.14 is required. Use the full portable bundle or install a compatible Python.'
}

if (!(Test-Path -LiteralPath $venvPython)) {
    $python = Find-CompatiblePython
    & $python -m venv (Join-Path $root '.venv')
}
$wheels = Join-Path $root 'wheels'
if ((Test-Path -LiteralPath $wheels) -and (Get-ChildItem -LiteralPath $wheels -Filter '*.whl' -ErrorAction SilentlyContinue)) {
    & $venvPython -m pip install --disable-pip-version-check --no-index --find-links $wheels -r (Join-Path $root 'requirements.txt')
} else {
    & $venvPython -m pip install --disable-pip-version-check -r (Join-Path $root 'requirements.txt')
}

$health = & $venvPython (Join-Path $root 'email_hub.py') --health
if ($LASTEXITCODE -ne 0) { throw 'Outlook health check failed.' }
$health

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'Start-EmailHub.ps1')
Start-Sleep -Seconds 2
if (!(Get-NetTCPConnection -State Listen -LocalAddress 127.0.0.1 -LocalPort 18477 -ErrorAction SilentlyContinue)) {
    throw 'Email Hub did not start on 127.0.0.1:18477.'
}
& $venvPython (Join-Path $root 'verify_mcp.py')

$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$aioShortcut = $shell.CreateShortcut((Join-Path $desktop 'Email Hub AIO.lnk'))
$aioShortcut.TargetPath = (Join-Path $root 'Email-Hub-AIO.cmd')
$aioShortcut.WorkingDirectory = $root
$aioShortcut.Description = 'All-in-one local email tools, status, approvals, repair, and export'
$aioShortcut.Save()

$approvalShortcut = $shell.CreateShortcut((Join-Path $desktop 'Email Hub Approval.lnk'))
$approvalShortcut.TargetPath = (Join-Path $root 'Approve-EmailHub.cmd')
$approvalShortcut.WorkingDirectory = $root
$approvalShortcut.Description = 'Review and approve queued AI-drafted email'
$approvalShortcut.Save()

$statusShortcut = $shell.CreateShortcut((Join-Path $desktop 'Email Hub Status.lnk'))
$statusShortcut.TargetPath = (Join-Path $root 'Status-EmailHub.cmd')
$statusShortcut.WorkingDirectory = $root
$statusShortcut.Description = 'Check Local Email Hub health and durable queue state'
$statusShortcut.Save()

$startup = [Environment]::GetFolderPath('Startup')
$startupShortcut = $shell.CreateShortcut((Join-Path $startup 'Local Email Hub.lnk'))
$startupShortcut.TargetPath = 'powershell.exe'
$startupShortcut.Arguments = "-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$(Join-Path $root 'Start-EmailHub.ps1')`""
$startupShortcut.WorkingDirectory = $root
$startupShortcut.WindowStyle = 7
$startupShortcut.Description = 'Start the resilient local email MCP service'
$startupShortcut.Save()
Write-Host ''
Write-Host 'Email Hub is installed and healthy.' -ForegroundColor Green
Write-Host 'Run Register-EmailHub-Clients.ps1 to connect supported local AI clients.'


