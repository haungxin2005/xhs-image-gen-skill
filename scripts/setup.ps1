param(
  [string]$ConfigPath = "",
  [string]$WorkspaceRoot = "",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$configDir = Join-Path $skillRoot "config"
$examplePath = Join-Path $configDir "config.example.json"
if ($ConfigPath.Trim().Length -eq 0) {
  $ConfigPath = Join-Path $configDir "config.json"
}

if (-not (Test-Path -LiteralPath $examplePath)) {
  throw "Missing config example: $examplePath"
}

if ((Test-Path -LiteralPath $ConfigPath) -and -not $Force) {
  Write-Host "Config already exists: $ConfigPath"
} else {
  Copy-Item -LiteralPath $examplePath -Destination $ConfigPath -Force
  $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($WorkspaceRoot.Trim().Length -gt 0) {
    $config.workspace_root = $WorkspaceRoot
  }
  if ([string]$config.workspace_root -eq "") {
    $config.workspace_root = Join-Path $env:USERPROFILE ".xhs-image-gen"
  }
  if ([string]$config.output_root -eq "") {
    $config.output_root = Join-Path ([string]$config.workspace_root) "output\native3x4"
  }
  $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
  Write-Host "Created config: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($WorkspaceRoot.Trim().Length -gt 0) {
  $config.workspace_root = $WorkspaceRoot
  if ([string]$config.output_root -eq "" -or $Force) {
    $config.output_root = Join-Path $WorkspaceRoot "output\native3x4"
  }
  $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}
$workspaceRoot = [string]$config.workspace_root
if ($workspaceRoot.Trim().Length -eq 0) {
  $workspaceRoot = Join-Path $env:USERPROFILE ".xhs-image-gen"
}
$outputRoot = [string]$config.output_root
if ($outputRoot.Trim().Length -eq 0) {
  $outputRoot = Join-Path $workspaceRoot "output\native3x4"
}

New-Item -ItemType Directory -Force -Path $configDir | Out-Null
New-Item -ItemType Directory -Force -Path $workspaceRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $workspaceRoot "cache") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $workspaceRoot "cache\accounts") | Out-Null
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$aliasesPath = Join-Path $workspaceRoot "cache\account-aliases.json"
if (-not (Test-Path -LiteralPath $aliasesPath)) {
  "{}" | Set-Content -LiteralPath $aliasesPath -Encoding UTF8
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Edit config/config.json and fill Feishu base/table/field ids."
Write-Host "2. Run: lark-cli auth login"
Write-Host "3. Install or set XHS_DOWNLOADER_DIR for JoeanAmier/XHS-Downloader."
Write-Host "4. Run: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/doctor.ps1"
