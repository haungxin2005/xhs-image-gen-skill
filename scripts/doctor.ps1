param(
  [string]$ConfigPath = "",
  [switch]$SkipFeishuProbe
)

$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
if ($ConfigPath.Trim().Length -eq 0) {
  $ConfigPath = Join-Path $skillRoot "config\config.json"
}

$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail
  )
  $script:checks.Add([pscustomobject]@{
    name = $Name
    ok = $Ok
    detail = $Detail
  }) | Out-Null
}

function Get-ConfigValue {
  param($Object, [string]$Path)
  $current = $Object
  foreach ($part in $Path.Split(".")) {
    if ($null -eq $current -or -not ($current.PSObject.Properties.Name -contains $part)) {
      return $null
    }
    $current = $current.$part
  }
  return $current
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  Add-Check "config" $false "Missing config.json. Run scripts/setup.ps1 first."
  $checks | ConvertTo-Json -Depth 5
  exit 1
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
Add-Check "config" $true $ConfigPath

$required = @(
  "feishu.base_token",
  "feishu.account_table_id",
  "feishu.task_table_id",
  "feishu.account_fields.name",
  "feishu.account_fields.template_images",
  "feishu.task_fields.summary",
  "feishu.task_fields.account",
  "feishu.task_fields.source_url",
  "feishu.task_fields.source_images",
  "feishu.task_fields.generated_images",
  "feishu.task_fields.status"
)

foreach ($path in $required) {
  $value = Get-ConfigValue $config $path
  Add-Check "config:$path" ([string]$value -ne "") "Required for Feishu workflow"
}

$lark = Get-Command lark-cli -ErrorAction SilentlyContinue
Add-Check "lark-cli" ($null -ne $lark) $(if ($lark) { $lark.Source } else { "Install lark-cli and run lark-cli auth login" })

$xhsDir = [string]$config.xhs_downloader_dir
if ($xhsDir.Trim().Length -eq 0) {
  if ($env:XHS_DOWNLOADER_DIR) {
    $xhsDir = $env:XHS_DOWNLOADER_DIR
  } else {
    $xhsDir = Join-Path $HOME "tools\XHS-Downloader"
  }
}
$xhsMain = Join-Path $xhsDir "main.py"
Add-Check "XHS-Downloader" (Test-Path -LiteralPath $xhsMain) $xhsMain

$generatedImages = Join-Path $env:USERPROFILE ".codex\generated_images"
Add-Check "Codex generated_images" (Test-Path -LiteralPath $generatedImages) $generatedImages

if (-not $SkipFeishuProbe -and $lark) {
  $baseToken = [string]$config.feishu.base_token
  $taskTable = [string]$config.feishu.task_table_id
  if ($baseToken.Trim().Length -gt 0 -and $taskTable.Trim().Length -gt 0) {
    try {
      $probe = & lark-cli base +field-list --base-token $baseToken --table-id $taskTable --as user 2>&1
      Add-Check "Feishu task table probe" ($LASTEXITCODE -eq 0) (($probe | Select-Object -First 3) -join "`n")
    } catch {
      Add-Check "Feishu task table probe" $false $_.Exception.Message
    }
  }
}

$ok = -not ($checks | Where-Object { -not $_.ok })
$result = [pscustomobject]@{
  ok = $ok
  skill_root = $skillRoot
  config = $ConfigPath
  checks = $checks
}

$result | ConvertTo-Json -Depth 6
if (-not $ok) {
  exit 1
}
