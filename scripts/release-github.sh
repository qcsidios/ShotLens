#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${SHOTLENS_APP_VERSION:-$("$ROOT_DIR/scripts/next-release-version.sh")}"
DMG_PATH="$ROOT_DIR/build/release/ShotLens-$VERSION.dmg"

if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Release version must use three-part semver like v1.1.0, got: $VERSION" >&2
  exit 1
fi

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  echo "Commit or stash local changes before creating a GitHub release." >&2
  exit 1
fi

if git -C "$ROOT_DIR" rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "Tag already exists: $VERSION" >&2
  exit 1
fi

SHOTLENS_APP_VERSION="$VERSION" "$ROOT_DIR/scripts/package-dmg.sh" >/dev/null

git -C "$ROOT_DIR" tag "$VERSION"
git -C "$ROOT_DIR" push origin "$VERSION"

gh release create "$VERSION" "$DMG_PATH" \
  --repo qcsidios/ShotLens \
  --title "ShotLens $VERSION" \
  --notes-file <(cat <<EOF
## 更新内容

- 新增默认 SiliconFlow 翻译配置，Key 留空时可使用公共福利额度。
- 控制台显示默认地址和模型，并提示混元模型当前限免。
- 新增 GitHub Release 更新检查和 DMG 自动升级入口。
- 保留飞书文档作为无法访问 GitHub 用户的手动更新渠道。

## 注意事项

- 默认福利 Key 可能限额、失效或被随时撤销，重度用户建议填写自己的 API Key。
- \`tencent/Hunyuan-MT-7B\` 当前限免，后续以 SiliconFlow/模型服务商政策为准。
EOF
)

echo "$VERSION"
