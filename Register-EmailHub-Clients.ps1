$ErrorActionPreference = 'Stop'
$endpoint = 'http://127.0.0.1:18477/mcp'
$description = 'Durable local Outlook email read, search, drafts, and human-approved send queue'

$qwen = Get-Command qwen.cmd -ErrorAction SilentlyContinue
if ($qwen) {
    $list = & $qwen.Source mcp list 2>&1 | Out-String
    if ($list -notmatch 'email-hub') {
        & $qwen.Source mcp add --scope user --transport http --timeout 30000 --description $description email-hub $endpoint
    } else { Write-Host 'Qwen Code: email-hub already registered.' }
}

$pi = Get-Command pi.cmd -ErrorAction SilentlyContinue
if ($pi) {
    $list = & $pi.Source mcp list 2>&1 | Out-String
    if ($list -notmatch 'email-hub') {
        & $pi.Source mcp add email-hub --url $endpoint --exposure direct --description $description
    } else { Write-Host 'Pi: email-hub already registered.' }
}

$hermes = Get-Command hermes.exe -ErrorAction SilentlyContinue
if (!$hermes) { $hermes = Get-Command hermes -ErrorAction SilentlyContinue }
if ($hermes) {
    $list = & $hermes.Source mcp list 2>&1 | Out-String
    if ($list -notmatch 'email-hub') {
        Write-Host 'Hermes will ask two setup questions. Answer No to authentication and Yes to all nine tools.' -ForegroundColor Yellow
        & $hermes.Source mcp add --url $endpoint --connect-timeout 30 email-hub
    } else { Write-Host 'Hermes: email-hub already registered.' }
}

function Add-HarnessBlock([string]$path) {
    if (!(Test-Path -LiteralPath $path)) { return }
    $text = Get-Content -LiteralPath $path -Raw
    if ($text -match 'id:\s*mcp-email-hub') {
        Write-Host "DeepSeek Harness: already registered in $path"
        return
    }
    $block = @"
- insert:
    - id: mcp-email-hub
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: email-hub
        transport: streamable-http
        url: http://127.0.0.1:18477/mcp
        toolCallTimeoutMs: 120000
        failOnStartupError: false
"@
    Copy-Item -LiteralPath $path -Destination ($path + '.before-email-hub.bak') -Force
    $updated = $text.TrimEnd() + "`r`n" + $block.TrimStart() + "`r`n"
    [System.IO.File]::WriteAllText($path, $updated, [System.Text.UTF8Encoding]::new($false))
    Write-Host "DeepSeek Harness: registered in $path"
}

$dsh = Join-Path $env:USERPROFILE '.dsh\profiles'
Add-HarnessBlock (Join-Path $dsh 'web\cordis.patch.yml')
Add-HarnessBlock (Join-Path $dsh 'headless\cordis.patch.yml')

Write-Host ''
Write-Host 'Client registration complete. Start new sessions or reload MCP in existing sessions.' -ForegroundColor Green
Write-Host 'Harness was not forcibly restarted, so active work is preserved.'
