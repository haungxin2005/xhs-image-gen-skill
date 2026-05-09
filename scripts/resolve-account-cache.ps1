param(
  [Parameter(Mandatory=$true)]
  [string]$Account,
  [string]$CacheRoot = "",
  [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
if ($ConfigPath.Trim().Length -eq 0) {
  $ConfigPath = Join-Path $skillRoot "config\config.json"
}

if ($CacheRoot.Trim().Length -eq 0 -and (Test-Path -LiteralPath $ConfigPath)) {
  $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$config.workspace_root -ne "") {
    $CacheRoot = Join-Path ([string]$config.workspace_root) "cache"
  }
}

if ($CacheRoot.Trim().Length -eq 0) {
  $CacheRoot = Join-Path $skillRoot "cache"
}

$aliasesPath = Join-Path $CacheRoot "account-aliases.json"
if (-not (Test-Path -LiteralPath $aliasesPath)) {
  throw "Alias file not found: $aliasesPath"
}

$aliases = Get-Content -LiteralPath $aliasesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entry = $null

if ($aliases.PSObject.Properties.Name -contains $Account) {
  $entry = $aliases.$Account
} else {
  foreach ($prop in $aliases.PSObject.Properties) {
    if ($prop.Value.account_name -eq $Account -or $prop.Value.account_slug -eq $Account) {
      $entry = $prop.Value
      break
    }
  }
}

if ($null -eq $entry) {
  throw "Account cache alias not found: $Account"
}

$accountDir = Join-Path (Join-Path $CacheRoot "accounts") $entry.account_slug
$manifestPath = Join-Path $accountDir "manifest.json"
$styleProfilePath = Join-Path $accountDir "style-profile.md"

if (-not (Test-Path -LiteralPath $manifestPath)) {
  throw "Manifest not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$templates = @{}
foreach ($role in $manifest.template_roles.PSObject.Properties.Name) {
  $rel = $manifest.template_roles.$role
  $path = Join-Path $accountDir $rel
  $templates[$role] = $path
}

[pscustomobject]@{
  status_code = 0
  account_name = $manifest.account_name
  account_slug = $manifest.account_slug
  record_id = $manifest.record_id
  cache_root = $CacheRoot
  account_dir = $accountDir
  manifest = $manifestPath
  style_profile = $styleProfilePath
  templates = $templates
} | ConvertTo-Json -Depth 5 -Compress
