# ShotLens

## 中文

ShotLens 是一个轻量级 macOS 菜单栏截图翻译工具。

它会冻结当前屏幕，让你框选一个区域，在独立 helper 进程中执行 OCR，通过 OpenAI-compatible API 翻译识别到的文字，并把译文覆盖渲染回原截图。

### 功能

- 菜单栏常驻工具，支持全局快捷键
- 冻结屏幕后框选翻译区域
- 基于 Apple Vision 的独立 OCR helper 进程
- OpenAI-compatible 翻译 API 配置
- 针对 UI 文本、菜单、段落、文章和混合截图的布局感知渲染
- 可拖动的结果浮窗，支持重试、原文/译文切换、复制截图到剪贴板
- 简洁控制台，用于查看权限、快捷键和 API 设置
- 应用图标与 macOS 菜单栏 template 图标

### 系统要求

- macOS 14.0 或更高版本
- Xcode Command Line Tools
- 屏幕录制权限
- OpenAI-compatible chat completions endpoint、API key 和 model

### 构建

```bash
bash scripts/build-local.sh
```

脚本默认会构建 `ShotLens.app` 到 `build/local`。如需部署到其他目录，可设置 `SHOTLENS_DEPLOY_DIR`。

打包朋友分享版 DMG：

```bash
bash scripts/package-dmg.sh
```

脚本会基于已有 `v*` tag 自动计算下一个版本，例如当前最新 tag 为 `v1.0` 时会输出 `build/release/ShotLens-v1.1.dmg`。如果要指定版本，可设置 `SHOTLENS_APP_VERSION=v1.1`。这个包没有 Apple 公证，适合发给朋友测试。对方安装后第一次打开时，需要右键点击 `ShotLens.app`，选择“打开”，再在 macOS 弹窗里确认“打开”。

### 验证

```bash
bash scripts/check-render-completeness.sh
bash scripts/check-workflow-requirements.sh
bash scripts/check-result-window-stability.sh
bash scripts/check-ocr-isolation.sh
bash scripts/check-preferences-edit-save.sh
bash scripts/check-release-requirements.sh
bash scripts/check-no-private-config.sh
```

### 创建发行版

命令行方式：

```bash
VERSION="$(bash scripts/next-release-version.sh)"
SHOTLENS_APP_VERSION="$VERSION" bash scripts/package-dmg.sh
git tag "$VERSION"
git push origin "$VERSION"
gh release create "$VERSION" "build/release/ShotLens-$VERSION.dmg" \
  --title "ShotLens $VERSION" \
  --notes "Friend-share DMG build. Install ShotLens.app into Applications, then use right-click Open on first launch because this package is not Apple-notarized."
```

也可以在已提交、干净的工作区里一键创建 GitHub Release：

```bash
bash scripts/release-github.sh
```

网页方式：打开 GitHub 仓库页面，进入 `Releases`，点击 `Draft a new release`，创建或选择 `scripts/next-release-version.sh` 输出的 tag，填写标题和说明，上传 `build/release/ShotLens-$VERSION.dmg`，最后发布。Release 说明里请注明首次启动需要右键选择“打开”。

### 说明

ShotLens 会把 OCR 识别出的文字发送给你配置的 API 服务商。截图像素仅用于本地 OCR 和覆盖渲染。

构建产物、本地 brainstorm 产物、内部计划文档和 DerivedData 不纳入版本控制。

### 许可证

MIT

---

## English

ShotLens is a lightweight macOS menu bar app for translating text in screenshots.

It freezes the current screen, lets you select a region, runs OCR in a helper process, translates the detected text through an OpenAI-compatible API, and renders the translated text back over the captured image.

### Features

- Menu bar utility with global shortcut support
- Frozen-screen region selection
- OCR helper process based on Apple's Vision framework
- OpenAI-compatible translation API configuration
- Layout-aware rendering for UI text, menus, paragraphs, articles, and mixed screenshots
- Draggable result overlay with retry, original/translation toggle, and clipboard screenshot save
- Minimal control console for permissions, shortcut, and API settings
- App icon and template menu bar icon

### Requirements

- macOS 14.0 or later
- Xcode Command Line Tools
- Screen Recording permission
- An OpenAI-compatible chat completions endpoint, API key, and model

### Build

```bash
bash scripts/build-local.sh
```

The script builds `ShotLens.app` into `build/local` by default. Set `SHOTLENS_DEPLOY_DIR` if you want to deploy it elsewhere.

To package a friend-share DMG:

```bash
bash scripts/package-dmg.sh
```

The script computes the next release version from existing `v*` tags. For example, if the latest tag is `v1.0`, it writes `build/release/ShotLens-v1.1.dmg`. Set `SHOTLENS_APP_VERSION=v1.1` to override the version. This build is not Apple-notarized and is intended for sharing with friends. On first launch, install the app and use right-click Open on `ShotLens.app`, then confirm Open in the macOS dialog.

### Verification

```bash
bash scripts/check-render-completeness.sh
bash scripts/check-workflow-requirements.sh
bash scripts/check-result-window-stability.sh
bash scripts/check-ocr-isolation.sh
bash scripts/check-preferences-edit-save.sh
bash scripts/check-release-requirements.sh
bash scripts/check-no-private-config.sh
```

### Create A Release

With the GitHub CLI:

```bash
VERSION="$(bash scripts/next-release-version.sh)"
SHOTLENS_APP_VERSION="$VERSION" bash scripts/package-dmg.sh
git tag "$VERSION"
git push origin "$VERSION"
gh release create "$VERSION" "build/release/ShotLens-$VERSION.dmg" \
  --title "ShotLens $VERSION" \
  --notes "Friend-share DMG build. Install ShotLens.app into Applications, then use right-click Open on first launch because this package is not Apple-notarized."
```

You can also create the GitHub Release in one command from a committed, clean worktree:

```bash
bash scripts/release-github.sh
```

From the GitHub website: open the repository, go to `Releases`, click `Draft a new release`, create or select the tag printed by `scripts/next-release-version.sh`, fill in the title and notes, upload `build/release/ShotLens-$VERSION.dmg`, then publish it. Mention in the release notes that first launch requires right-click Open.

### Notes

ShotLens sends recognized text to the API provider you configure. Screenshot pixels are used locally for OCR and overlay rendering.

Generated builds, local brainstorm artifacts, internal planning documents, and derived data are intentionally excluded from version control.

### License

MIT
