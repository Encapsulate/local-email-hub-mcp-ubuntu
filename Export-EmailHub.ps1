param(
    [string]$RuntimeSource = '',
    [string]$WheelSource = '',
    [string]$Destination = ''
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (!$Destination) {
    $Destination = Join-Path (Split-Path $root -Parent) ('email-hub-portable-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip')
}
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ('email-hub-export-' + [guid]::NewGuid().ToString('N'))
$bundle = Join-Path $stage 'email-hub'
$resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$resolvedStage = [System.IO.Path]::GetFullPath($stage)
if (!$resolvedStage.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe export staging path: $resolvedStage"
}
New-Item -ItemType Directory -Path $bundle -Force | Out-Null
try {
    Get-ChildItem -LiteralPath $root -Force | Where-Object {
        $_.Name -notin @('.git','.venv','state','logs','__pycache__','runtime','wheels','artifacts')
    } | Copy-Item -Destination $bundle -Recurse -Force
    if ($RuntimeSource -and (Test-Path -LiteralPath $RuntimeSource)) {
        $runtimeDestination = Join-Path $bundle 'runtime\python'
        New-Item -ItemType Directory -Path $runtimeDestination -Force | Out-Null
        Get-ChildItem -LiteralPath $RuntimeSource -Force | Copy-Item -Destination $runtimeDestination -Recurse -Force
    }
    if ($WheelSource -and (Test-Path -LiteralPath $WheelSource)) {
        $wheelDestination = Join-Path $bundle 'wheels'
        New-Item -ItemType Directory -Path $wheelDestination -Force | Out-Null
        Get-ChildItem -LiteralPath $WheelSource -Filter '*.whl' | Copy-Item -Destination $wheelDestination -Force
    }
    Compress-Archive -LiteralPath $bundle -DestinationPath $Destination -CompressionLevel Optimal
    Write-Host "Portable bundle created: $Destination"
    Write-Host 'Mailbox data, tokens, queue state, logs, and the machine-specific virtual environment were excluded.'
    Write-Host 'A clean Python runtime and offline dependency wheels are included only when supplied through parameters.'
} finally {
    if ((Test-Path -LiteralPath $resolvedStage) -and $resolvedStage.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}

