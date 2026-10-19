#!/bin/bash
# ダブルクリックで実行できる nicotver インストーラー (macOS)
cd "$(dirname "$0")" || exit 1
bash ./install.sh "$@"
status=$?
echo
read -r -p "Enter キーを押すと閉じます..." _
exit $status
