# Mac Junk Scanner

## 本版亮点

- 新增原生 macOS 中文界面
- 支持扫描常见垃圾目录和已卸载应用残留
- 支持按应用关键字过滤、白名单保护和逐项勾选
- 默认清理动作改为“移到废纸篓”，降低误删风险
- 新增“彻底清空废纸篓”操作
- 新增权限引导，会单独标记“需要授权”的分类

## 下载与安装

- 下载 `MacJunkScanner.dmg`
- 将 `MacJunkScanner.app` 拖到 `Applications`
- 首次运行如被 macOS 拦截，可右键应用后点“打开”

## 使用建议

- 日常优先清理：缓存、日志、DerivedData
- 谨慎处理：模拟器数据、Xcode 归档、设备备份
- 如果某些分类显示“需要授权”，请给应用开启“完全磁盘访问”后重新扫描

## 已知说明

- GitHub Releases 产物默认为未公证分发包
- 若未使用 Developer ID 签名和 notarization，首次启动可能会被 Gatekeeper 提示
- 某些系统目录是否可扫描，取决于当前 macOS 隐私权限
