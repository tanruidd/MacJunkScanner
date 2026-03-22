# Mac Junk Scanner

一个原生 SwiftUI macOS 应用，用来扫描 Mac 上常见的垃圾文件位置，并提供按应用过滤、白名单保护、删除前确认、移到废纸篓和权限引导。

## 当前能力

- 原生 macOS 图形界面
- 扫描常见垃圾目录
- 扫描已卸载应用残留
- 风险分级和逐项勾选
- 默认移到废纸篓
- 废纸篓彻底清空
- 权限不足分类单独展示
- 首次启动权限引导

## 工程结构

- `Package.swift`: Swift Package 清单，可直接被 Xcode 打开
- `Sources/`: SwiftUI 应用源码
- `Assets/`: 图标资源
- `scripts/build_release_app.sh`: Release 构建 `.app`
- `scripts/sign_app.sh`: 使用 `Developer ID Application` 证书签名
- `scripts/package_dmg.sh`: 打包 DMG
- `scripts/notarize_dmg.sh`: 提交公证并 stapler
- `scripts/verify_distribution.sh`: 验证签名和 Gatekeeper
- `scripts/release.sh`: 一键串起完整官网分发流程
- `.github/workflows/release.yml`: 推送 `v*` tag 后自动构建 GitHub Release
- `.github/workflows/gitleaks.yml`: push 和 PR 自动扫描敏感信息
- `RELEASE_NOTES.md`: GitHub Release 默认说明

## 开发运行

方式一：用 Xcode

1. 用 Xcode 打开当前目录，或直接打开 `Package.swift`
2. 选择 `MacJunkScanner` 运行

方式二：本地生成调试 `.app`

```bash
chmod +x build_app.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./build_app.sh
open /Users/trtan/Documents/Codex/Mac/tool/Scan/MacJunkScanner.app
```

## 官网分发

推荐使用 `Developer ID + notarization` 做 App Store 外分发。Apple 官方参考：

- [Distributing software on macOS](https://developer.apple.com/macos/distribution/)
- [Developer ID](https://developer.apple.com/developer-id/)
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Submitting apps for notarization](https://developer.apple.com/help/app-store-connect/manage-builds/submit-builds-for-notarization/)

### 1. 准备证书

你需要：

- Apple Developer Program 账号
- `Developer ID Application` 证书
- Xcode 已安装并可用

可以先查看本机可用签名身份：

```bash
security find-identity -v -p codesigning
```

### 2. Release 构建

```bash
chmod +x scripts/*.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build_release_app.sh
```

产物位置：

- `dist/MacJunkScanner.app`

### 3. Developer ID 签名

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
./scripts/sign_app.sh
```

### 4. 打包 DMG

```bash
./scripts/package_dmg.sh
```

产物位置：

- `dist/MacJunkScanner.dmg`

### 5. 配置 notarization 凭据

先在 keychain 中保存 notarytool 凭据：

```bash
xcrun notarytool store-credentials "macjunkscanner-notary" \
  --apple-id "<APPLE_ID>" \
  --team-id "<TEAM_ID>" \
  --password "<APP_SPECIFIC_PASSWORD>"
```

然后设置：

```bash
export NOTARY_PROFILE="macjunkscanner-notary"
```

### 6. 提交公证并 stapler

```bash
./scripts/notarize_dmg.sh
```

### 7. 验证分发产物

```bash
./scripts/verify_distribution.sh
```

### 8. 一键跑完整发布链路

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="macjunkscanner-notary"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/release.sh
```

## 默认扫描范围

- `~/Library/Caches`
- `~/Library/Logs`
- `~/.Trash`
- `~/Library/Developer/Xcode/DerivedData`
- `~/Library/Developer/Xcode/Archives`
- `~/Library/Developer/CoreSimulator/Devices`
- `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads`
- `~/Library/Application Support/MobileSync/Backup`

## 说明

- `移到废纸篓` 是默认清理动作
- `彻底清空废纸篓` 会直接删除废纸篓内容
- 如果出现权限受限，应用会把相关分类单独列为“需要授权”

## GitHub Releases 分发

如果只是想把应用发布到 GitHub，可以直接使用未签名的 DMG 或 ZIP：

```bash
chmod +x scripts/*.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/build_release_app.sh
./scripts/package_dmg.sh
cd dist
ditto -c -k --sequesterRsrc --keepParent MacJunkScanner.app MacJunkScanner.app.zip
```

产物位置：

- `dist/MacJunkScanner.dmg`
- `dist/MacJunkScanner.app.zip`

GitHub Actions 已配置好自动发布：

- 推送 tag，例如 `v0.1.0`
- 自动构建 `.dmg`、`.app.zip`
- 自动生成 `sha256`
- 自动创建 GitHub Release

注意：

- 这条 GitHub Releases 流程默认不做 Developer ID 签名和 notarization
- 用户首次运行时，macOS 可能要求右键“打开”
