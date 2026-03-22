# Mac Junk Scanner

<p align="center">
  <img src="https://raw.githubusercontent.com/tanruidd/MacJunkScanner/main/Assets/Branding/logo.png" alt="Mac Junk Scanner Logo" width="160" />
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/tanruidd/MacJunkScanner/main/Assets/Branding/release-preview.png" alt="Mac Junk Scanner Preview" width="900" />
</p>

一个原生 SwiftUI macOS 应用，用来扫描 Mac 上常见的垃圾文件位置，并提供按应用过滤、白名单保护、删除前确认、移到废纸篓和权限引导。

## 功能

- 原生 macOS 图形界面
- 扫描常见垃圾目录
- 扫描已卸载应用残留
- 风险分级和逐项勾选
- 默认移到废纸篓
- 废纸篓彻底清空
- 权限不足分类单独展示
- 首次启动权限引导

## 安装与启动

1. 下载并解压发布包。
2. 将 `MacJunkScanner.app` 拖到 `Applications`，或放到任意你习惯的位置。
3. 双击启动应用。
4. 如果 macOS 首次拦截，右键应用后选择“打开”。

## 使用说明

### 1. 开始扫描

- 打开应用后点击 `开始扫描`
- 左侧会显示分类列表，右侧显示当前分类详情
- 勾选 `扫描已卸载应用残留` 后，会额外显示疑似残留文件

### 2. 筛选扫描结果

- `应用关键字`：只看指定应用相关缓存或残留
- `白名单`：输入关键字或绝对路径，避免误选
- `显示数量`：控制每个分类展示的一级目录数量
- `显示不存在的目录`：把空目录或不存在的目标也显示出来，方便排查路径问题

### 3. 选择要清理的项目

- 所有项目都需要你手动勾选后才会加入清理队列
- 普通项目显示 `加入清理`
- 高风险项目显示 `允许清理`
- `只全选低风险项` 只会勾选当前分类中的低风险项目

### 4. 执行清理

- 默认操作是 `移到废纸篓`
- 顶部会先显示 `已选中待清理` 的总大小
- 点击 `移到废纸篓` 后，会再次确认应用名、路径和总大小

### 5. 清空废纸篓

- 选中左侧 `废纸篓` 分类时，会显示 `彻底清空废纸篓`
- 这个操作会直接删除废纸篓内容，无法像“移到废纸篓”那样再恢复
- 建议执行前先确认废纸篓里没有需要保留的文件

## 默认扫描范围

- `~/Library/Caches`
- `~/Library/Logs`
- `~/.Trash`
- `~/Library/Developer/Xcode/DerivedData`
- `~/Library/Developer/Xcode/Archives`
- `~/Library/Developer/CoreSimulator/Devices`
- `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads`
- `~/Library/Application Support/MobileSync/Backup`

## 权限说明

- 某些目录需要 `完全磁盘访问` 才能读取
- 如果应用检测到权限不足，会把相关分类单独列为 `需要授权`
- 首次启动或首次扫描受限时，会弹出权限引导页
- 开启路径：`系统设置` -> `隐私与安全性` -> `完全磁盘访问`

## 风险提示

- `缓存`、`日志`、`DerivedData` 通常适合清理，但下次打开应用或编译项目时可能需要重新生成
- `iOS 模拟器`、`Xcode Archives`、`iPhone 备份` 这类数据影响更大，清理前请务必确认
- `移到废纸篓` 相对安全，`彻底清空废纸篓` 属于不可恢复操作
