# nicotver インストーラー (Windows)
# 管理者権限は不要です。何度実行しても同じ場所に上書き更新します。
#   インストール先: %LOCALAPPDATA%\nicotver
#     node\       ... (必要な場合のみ) ポータブル版 Node.js
#     src\        ... ソースコード
#     extension\  ... Chrome / Edge に読み込むフォルダ
param(
  [switch]$ForceNodeDownload,
  [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoUrl   = 'https://github.com/zephel01/nicotver.git'
$ZipUrl    = 'https://codeload.github.com/zephel01/nicotver/zip/refs/heads/main'
$NodeMajor = 22
$MinNode   = 18

$Base   = Join-Path $env:LOCALAPPDATA 'nicotver'
$NodeHome = Join-Path $Base 'node'
$Src    = Join-Path $Base 'src'
$Ext    = Join-Path $Base 'extension'

function Step($msg) { Write-Host ''; Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host ''; Write-Host "エラー: $msg" -ForegroundColor Red; exit 1 }

function Get-NodeMajor($exe) {
  try {
    $v = & $exe -v 2>$null
    if ($v -match '^v(\d+)\.') { return [int]$Matches[1] }
  } catch {}
  return 0
}

New-Item -ItemType Directory -Force $Base | Out-Null

# ---- 1. Node.js ----
Step 'Node.js を確認しています'
$nodeExe = $null
if (-not $ForceNodeDownload) {
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if ($cmd -and (Get-NodeMajor $cmd.Source) -ge $MinNode) {
    $nodeExe = $cmd.Source
    Write-Host "インストール済みの Node.js を使います: $nodeExe ($(& $nodeExe -v))"
  }
}
if (-not $nodeExe) {
  $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
  $sumsUrl = "https://nodejs.org/dist/latest-v$NodeMajor.x/SHASUMS256.txt"
  $sums = (Invoke-WebRequest $sumsUrl -UseBasicParsing).Content
  $line = ($sums -split "`n") | Where-Object { $_ -match "\s(node-v[\d\.]+-win-$arch\.zip)\s*$" } | Select-Object -First 1
  if (-not $line) { Fail "Node.js のダウンロード情報を取得できませんでした ($sumsUrl)" }
  $parts = $line.Trim() -split '\s+'
  $expected = $parts[0].ToLower()
  $zipName = $parts[1]
  $dirName = $zipName -replace '\.zip$', ''
  $portable = Join-Path $NodeHome $dirName
  if (Test-Path (Join-Path $portable 'node.exe')) {
    Write-Host "ダウンロード済みのポータブル版 Node.js を使います: $dirName"
  } else {
    Write-Host "ポータブル版 Node.js ($dirName) をダウンロードしています..."
    New-Item -ItemType Directory -Force $NodeHome | Out-Null
    $zip = Join-Path $NodeHome $zipName
    Invoke-WebRequest "https://nodejs.org/dist/latest-v$NodeMajor.x/$zipName" -OutFile $zip -UseBasicParsing
    $actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) { Remove-Item $zip -Force; Fail "Node.js の SHA256 が一致しません (期待値 $expected / 実際 $actual)" }
    Write-Host 'SHA256 を確認しました。展開しています...'
    Get-ChildItem $NodeHome -Directory -Filter 'node-v*' | Remove-Item -Recurse -Force
    Expand-Archive $zip -DestinationPath $NodeHome -Force
    Remove-Item $zip -Force
  }
  $nodeExe = Join-Path $portable 'node.exe'
  Write-Host "Node.js: $(& $nodeExe -v)"
}
$nodeDir = Split-Path $nodeExe -Parent
$env:Path = "$nodeDir;$env:Path"
$npm = Join-Path $nodeDir 'npm.cmd'
if (-not (Test-Path $npm)) { $npm = 'npm.cmd' }

# ---- 2. ソース ----
Step 'ソースコードを取得しています'
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git -and (Test-Path (Join-Path $Src '.git'))) {
  Write-Host 'git pull で更新します'
  & git -C $Src pull --ff-only
  if ($LASTEXITCODE -ne 0) { Fail 'git pull に失敗しました' }
} elseif ($git -and -not (Test-Path $Src)) {
  & git clone --depth 1 $RepoUrl $Src
  if ($LASTEXITCODE -ne 0) { Fail 'git clone に失敗しました' }
} else {
  Write-Host 'GitHub から ZIP をダウンロードします'
  $tmp = Join-Path $Base ('tmp-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $tmp | Out-Null
  $zip = Join-Path $tmp 'src.zip'
  Invoke-WebRequest $ZipUrl -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath $tmp -Force
  $extracted = Get-ChildItem $tmp -Directory | Select-Object -First 1
  if (-not $extracted) { Fail 'ZIP の展開に失敗しました' }
  New-Item -ItemType Directory -Force $Src | Out-Null
  # node_modules は残して、それ以外を入れ替える
  Get-ChildItem $Src -Force | Where-Object { $_.Name -ne 'node_modules' } | Remove-Item -Recurse -Force
  Get-ChildItem $extracted.FullName -Force | Copy-Item -Destination $Src -Recurse -Force
  Remove-Item $tmp -Recurse -Force
}

# ---- 3. 依存パッケージ ----
Step '依存パッケージをインストールしています (npm install --ignore-scripts)'
# node-sass のネイティブビルドは新しい Node.js で失敗するため、インストールスクリプトは実行しません。
# ビルドには同梱の sass (dart-sass) が使われます。
Push-Location $Src
$ErrorActionPreference = 'Continue'
& $npm install --ignore-scripts --no-audit --no-fund
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($code -ne 0) { Pop-Location; Fail "npm install に失敗しました (終了コード $code)" }

# ---- 4. ビルド ----
Step 'ビルドしています'
$env:NODE_OPTIONS = '--openssl-legacy-provider'
$ErrorActionPreference = 'Continue'
& $nodeExe 'node_modules\webpack-cli\bin\cli.js' --mode=production --config 'config\webpack.config.js'
$code = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
Remove-Item Env:\NODE_OPTIONS
Pop-Location
if ($code -ne 0) { Fail "ビルドに失敗しました (終了コード $code)" }
if (-not (Test-Path (Join-Path $Src 'build\manifest.json'))) { Fail 'build\manifest.json が見つかりません' }

# ---- 5. 拡張機能フォルダへコピー ----
Step '拡張機能フォルダを更新しています'
New-Item -ItemType Directory -Force $Ext | Out-Null
Get-ChildItem $Ext -Force | Remove-Item -Recurse -Force
Get-ChildItem (Join-Path $Src 'build') -Force | Copy-Item -Destination $Ext -Recurse -Force
Write-Host "完了: $Ext"

if (-not $NoOpen) { Start-Process explorer.exe $Ext }

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' nicotver の準備ができました' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Host '拡張機能フォルダ:'
Write-Host "  $Ext"
Write-Host ''
Write-Host '[はじめてのとき] Chrome に読み込む手順'
Write-Host '  1. Chrome のアドレスバーに chrome://extensions と入力して開く'
Write-Host '  2. 右上の「デベロッパー モード」をオンにする'
Write-Host '  3. 「パッケージ化されていない拡張機能を読み込む」を押す'
Write-Host '  4. 上の拡張機能フォルダを選ぶ'
Write-Host '  (Edge の場合: edge://extensions →「開発者モード」をオン →「展開して読み込み」)'
Write-Host ''
Write-Host '[更新のとき]'
Write-Host '  chrome://extensions で nicotver の再読み込みボタン (円形の矢印) を押し、TVer のページを再読み込みしてください。'
Write-Host ''
Write-Host '[アンインストール]'
Write-Host '  chrome://extensions で nicotver を削除してから、次のフォルダを削除してください:'
Write-Host "  $Base"
Write-Host ''
