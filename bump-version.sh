#!/bin/bash
# バージョンアップスクリプト
# 使い方:
#   ./bump-version.sh patch "バグ修正の内容"
#   ./bump-version.sh minor "新機能の内容"
#   ./bump-version.sh major "大幅変更の内容"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX="$SCRIPT_DIR/index.html"
SW="$SCRIPT_DIR/sw.js"

# 引数チェック
TYPE="${1:-patch}"
MESSAGE="${2:-更新}"

if [[ "$TYPE" != "patch" && "$TYPE" != "minor" && "$TYPE" != "major" ]]; then
  echo "エラー: 第1引数は patch / minor / major のいずれかを指定してください"
  exit 1
fi

# 現在のバージョンを取得
CURRENT=$(grep -o "APP_VERSION = 'v[0-9]*\.[0-9]*\.[0-9]*'" "$INDEX" | grep -o '[0-9]*\.[0-9]*\.[0-9]*')
if [[ -z "$CURRENT" ]]; then
  echo "エラー: index.html から APP_VERSION が見つかりませんでした"
  exit 1
fi

MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)

# 新バージョンを計算
if [[ "$TYPE" == "major" ]]; then
  MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
elif [[ "$TYPE" == "minor" ]]; then
  MINOR=$((MINOR + 1)); PATCH=0
else
  PATCH=$((PATCH + 1))
fi

NEW_VER="v${MAJOR}.${MINOR}.${PATCH}"
TODAY=$(date +%Y-%m-%d)

echo "バージョン: v$CURRENT → $NEW_VER"
echo "変更内容: $MESSAGE"

# Python で index.html と sw.js を更新
python3 - "$INDEX" "$SW" "$CURRENT" "$NEW_VER" "$TODAY" "$MESSAGE" <<'PYEOF'
import sys

index_path, sw_path, old_ver, new_ver, today, message = sys.argv[1:]

# --- index.html ---
with open(index_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(f"APP_VERSION = 'v{old_ver}'", f"APP_VERSION = '{new_ver}'")

new_entry = (
    f"  {{\n"
    f"    version: '{new_ver}',\n"
    f"    date: '{today}',\n"
    f"    changes: ['{message}']\n"
    f"  }},\n"
)
content = content.replace("const CHANGELOG = [\n", f"const CHANGELOG = [\n{new_entry}")

with open(index_path, 'w', encoding='utf-8') as f:
    f.write(content)

# --- sw.js ---
with open(sw_path, 'r', encoding='utf-8') as f:
    sw = f.read()

sw = sw.replace(f"migraine-tracker-v{old_ver}", f"migraine-tracker-{new_ver}")

with open(sw_path, 'w', encoding='utf-8') as f:
    f.write(sw)

print("  index.html / sw.js 更新完了")
PYEOF

echo "✅ 完了しました！"
echo "   APP_VERSION = '${NEW_VER}'"
echo "   CACHE_NAME  = 'migraine-tracker-${NEW_VER}'"
