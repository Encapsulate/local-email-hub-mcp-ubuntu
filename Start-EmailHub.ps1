$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$python = "$root\.venv\Scripts\python.exe"
$port = 18477
if (!(Test-Path -LiteralPath $python)) { throw "Email Hub runtime is missing: $python" }
if (Get-NetTCPConnection -State Listen -LocalAddress 127.0.0.1 -LocalPort $port -ErrorAction SilentlyContinue) { exit 0 }
$out = "$root\logs\service.out.log"
$err = "$root\logs\service.err.log"
$process = Start-Process -FilePath $python -ArgumentList "`"$root\email_hub.py`"" -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
$process.Id | Set-Content -LiteralPath "$root\state\launcher.pid" -Encoding ascii

