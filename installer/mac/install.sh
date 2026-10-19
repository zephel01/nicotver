#!/bin/bash
# nicotver インストーラー (macOS)
# 管理者権限 (sudo) は不要です。何度実行しても同じ場所に上書き更新します。
#   インストール先: ~/Library/Application Support/nicotver
#     node/       ... (必要な場合のみ) Node.js
#     src/        ... ソースコード
#     extension/  ... Chrome / Edge に読み込むフォルダ
#
# オプション:
#   --force-node-download  インストール済みの Node.js を使わずにダウンロードする
#   --no-open              最後に Finder でフォルダを開かない
set -euo pipefail

REPO_URL="https://github.com/zephel01/nicotver.git"
ZIP_URL="https://codeload.github.com/zephel01/nicotver/zip/refs/heads/main"
NODE_MAJOR=22
MIN_NODE=18

BASE="$HOME/Library/Application Support/nicotver"
NODE_HOME="$BASE/node"
SRC="$BASE/src"
EXT="$BASE/extension"

FORCE_NODE=0
NO_OPEN=0
for a in "$@"; do
  case "$a" in
    --force-node-download) FORCE_NODE=1 ;;
    --no-open) NO_OPEN=1 ;;
  esac
done

step() { printf '\n==> %s\n' "$1"; }
fail() { printf '\nエラー: %s\n' "$1" >&2; exit 1; }

node_major() {
  local v
  v="$("$1" -v 2>/dev/null || true)"
  v="${v#v}"
  echo "${v%%.*}" | grep -E '^[0-9]+$' || echo 0
}

mkdir -p "$BASE"

# ---- 1. Node.js ----
step "Node.js を確認しています"
NODE_BIN=""
if [ "$FORCE_NODE" -eq 0 ] && command -v node >/dev/null 2>&1; then
  if [ "$(node_major "$(command -v node)")" -ge "$MIN_NODE" ]; then
    NODE_BIN="$(command -v node)"
    echo "インストール済みの Node.js を使います: $NODE_BIN ($("$NODE_BIN" -v))"
  fi
fi
if [ -z "$NODE_BIN" ]; then
  case "$(uname -m)" in
    arm64) ARCH=arm64 ;;
    x86_64) ARCH=x64 ;;
    *) fail "対応していない CPU です: $(uname -m)" ;;
  esac
  SUMS_URL="https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/SHASUMS256.txt"
  LINE="$(curl -fsSL "$SUMS_URL" | grep -E " node-v[0-9.]+-darwin-${ARCH}\.tar\.gz$" | head -n 1)" || fail "Node.js のダウンロード情報を取得できませんでした ($SUMS_URL)"
  EXPECTED="${LINE%% *}"
  TARBALL="${LINE##* }"
  DIRNAME="${TARBALL%.tar.gz}"
  if [ -x "$NODE_HOME/$DIRNAME/bin/node" ]; then
    echo "ダウンロード済みの Node.js を使います: $DIRNAME"
  else
    echo "Node.js ($DIRNAME) をダウンロードしています..."
    mkdir -p "$NODE_HOME"
    curl -fsSL -o "$NODE_HOME/$TARBALL" "https://nodejs.org/dist/latest-v${NODE_MAJOR}.x/$TARBALL"
    ACTUAL="$(shasum -a 256 "$NODE_HOME/$TARBALL" | awk '{print $1}')"
    if [ "$ACTUAL" != "$EXPECTED" ]; then
      rm -f "$NODE_HOME/$TARBALL"
      fail "Node.js の SHA256 が一致しません (期待値 $EXPECTED / 実際 $ACTUAL)"
    fi
    echo "SHA256 を確認しました。展開しています..."
    find "$NODE_HOME" -mindepth 1 -maxdepth 1 -type d -name 'node-v*' -exec rm -rf {} +
    tar -xzf "$NODE_HOME/$TARBALL" -C "$NODE_HOME"
    rm -f "$NODE_HOME/$TARBALL"
  fi
  NODE_BIN="$NODE_HOME/$DIRNAME/bin/node"
  echo "Node.js: $("$NODE_BIN" -v)"
fi
export PATH="$(dirname "$NODE_BIN"):$PATH"

# ---- 2. ソース ----
step "ソースコードを取得しています"
# git は Xcode コマンドラインツールが入っている場合だけ使う (未導入だとインストール画面が出るため)
HAS_GIT=0
if command -v git >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then HAS_GIT=1; fi
if [ "$HAS_GIT" -eq 1 ] && [ -d "$SRC/.git" ]; then
  echo "git pull で更新します"
  git -C "$SRC" pull --ff-only || fail "git pull に失敗しました"
elif [ "$HAS_GIT" -eq 1 ] && [ ! -e "$SRC" ]; then
  git clone --depth 1 "$REPO_URL" "$SRC" || fail "git clone に失敗しました"
else
  echo "GitHub から ZIP をダウンロードします"
  TMP="$(mktemp -d "$BASE/tmp.XXXXXX")"
  curl -fsSL -o "$TMP/src.zip" "$ZIP_URL" || fail "ZIP のダウンロードに失敗しました"
  unzip -q "$TMP/src.zip" -d "$TMP" || fail "ZIP の展開に失敗しました"
  EXTRACTED="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [ -n "$EXTRACTED" ] || fail "ZIP の展開に失敗しました"
  mkdir -p "$SRC"
  # node_modules は残して、それ以外を入れ替える
  find "$SRC" -mindepth 1 -maxdepth 1 ! -name node_modules -exec rm -rf {} +
  cp -R "$EXTRACTED"/. "$SRC"/
  rm -rf "$TMP"
fi

# ---- 3. 依存パッケージ ----
step "依存パッケージをインストールしています (npm install --ignore-scripts)"
# node-sass のネイティブビルドは新しい Node.js で失敗するため、インストールスクリプトは実行しません。
# ビルドには同梱の sass (dart-sass) が使われます。
cd "$SRC"
npm install --ignore-scripts --no-audit --no-fund || fail "npm install に失敗しました"

# ---- 4. ビルド ----
step "ビルドしています"
npm run build || fail "ビルドに失敗しました"
[ -f "$SRC/build/manifest.json" ] || fail "build/manifest.json が見つかりません"

# ---- 5. 拡張機能フォルダへコピー ----
step "拡張機能フォルダを更新しています"
mkdir -p "$EXT"
find "$EXT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -R "$SRC/build"/. "$EXT"/
echo "完了: $EXT"

if [ "$NO_OPEN" -eq 0 ]; then open "$EXT" || true; fi

cat <<MSG

============================================================
 nicotver の準備ができました
============================================================

拡張機能フォルダ:
  $EXT

[はじめてのとき] Chrome に読み込む手順
  1. Chrome のアドレスバーに chrome://extensions と入力して開く
  2. 右上の「デベロッパー モード」をオンにする
  3. 「パッケージ化されていない拡張機能を読み込む」を押す
  4. 上の拡張機能フォルダを選ぶ
     (ファイル選択画面で ⌘+Shift+G を押し、次のパスを貼り付けると早いです)
     ~/Library/Application Support/nicotver/extension
  (Edge の場合: edge://extensions →「開発者モード」をオン →「展開して読み込み」)

[更新のとき]
  chrome://extensions で nicotver の再読み込みボタン (↻) を押し、TVer のページを再読み込みしてください。

[アンインストール]
  chrome://extensions で nicotver を削除してから、次のフォルダを削除してください:
  $BASE

MSG
