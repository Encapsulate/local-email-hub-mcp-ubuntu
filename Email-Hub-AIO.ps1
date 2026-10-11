$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
while ($true) {
    Clear-Host
    Write-Host 'Local Email Hub' -ForegroundColor Cyan
    Write-Host '1. Status and safe recovery'
    Write-Host '2. Review and approve queued messages'
    Write-Host '3. Register or repair AI client connections'
    Write-Host '4. Repair/reinstall the Email Hub runtime'
    Write-Host '5. Export a credential-free portable bundle'
    Write-Host '6. Open OpenWebUI integrations'
    Write-Host 'Q. Quit'
    $choice = Read-Host 'Choose'
    switch ($choice.ToUpperInvariant()) {
        '1' { & (Join-Path $root 'Status-EmailHub.ps1'); Read-Host 'Press Enter' | Out-Null }
        '2' { & (Join-Path $root 'Approve-EmailHub.ps1'); Read-Host 'Press Enter' | Out-Null }
        '3' { & (Join-Path $root 'Register-EmailHub-Clients.ps1'); Read-Host 'Press Enter' | Out-Null }
        '4' { & (Join-Path $root 'Setup-EmailHub.ps1'); Read-Host 'Press Enter' | Out-Null }
        '5' { & (Join-Path $root 'Export-EmailHub.ps1'); Read-Host 'Press Enter' | Out-Null }
        '6' {
            Start-Process 'http://127.0.0.1:3000/admin/settings/integrations'
            Write-Host 'Add an MCP (Streamable HTTP) connection named Email Hub:'
            Write-Host 'http://host.docker.internal:18477/mcp' -ForegroundColor Green
            Read-Host 'Press Enter' | Out-Null
        }
        'Q' { return }
    }
}

