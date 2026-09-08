# new

基于 WKWebView 的轻量 iOS 浏览器，支持手势导航、下拉刷新、常驻书签栏，通过 GitHub Actions 云端自动构建 IPA。

## 功能特性

- **左滑返回 / 右滑前进**：自定义手势导航，与页面滚动共存
- **下拉刷新**：集成 UIRefreshControl
- **常驻顶部书签栏**：固定在安全区顶部，快捷访问常用网站
- **加载进度条**：页面顶部实时显示加载进度
- **新窗口自动内开**：target="_blank" 链接在当前 WebView 打开
- **GitHub Actions 自动构建**：推送代码即触发云端构建，无需本地 Xcode

## 构建与安装

### 云端构建（推荐）

1. 推送代码到 GitHub 仓库
2. GitHub Actions 自动触发 `Build iOS IPA` 工作流
3. 构建完成后在 Actions 页面下载 IPA 产物

### 安装方式

- **TrollStore**：直接导入 IPA 安装（永久签名）
- **AltStore / Sideloadly**：自签名后安装
- **爱思助手**：侧载安装

### 带证书签名（可选）

如需生成可直接安装的签名 IPA，在 GitHub Secrets 中配置：

- `IOS_CERTIFICATE`：.p12 证书 base64
- `IOS_CERTIFICATE_PWD`：证书密码
- `IOS_PROVISION_PROFILE`：描述文件 base64
- `KEYCHAIN_PASSWORD`：自定义钥匙串密码

配置后工作流自动切换为签名模式。

## 项目结构

```
new/
├── WebViewBrowser/              # 主项目源码
│   ├── AppDelegate.swift        # 应用入口
│   ├── SceneDelegate.swift      # 场景管理
│   ├── ViewController.swift     # 核心逻辑（WebView/手势/书签）
│   ├── Info.plist               # 应用配置
│   ├── Base.lproj/
│   │   └── LaunchScreen.storyboard
│   └── Assets.xcassets/
├── WebViewBrowser.xcodeproj/    # Xcode 工程文件
└── .github/workflows/
    └── build.yml                # GitHub Actions 构建工作流
```

## 技术要求

- 最低 iOS 版本：15.0
- 构建环境：Xcode 15+（GitHub Actions 自动提供）
- 本地开发：仅修改代码时任意编辑器即可，本地编译需 macOS + Xcode

## 更新日志

### v1.0.0（2026-09-09）

- 初始版本发布
- 基于 WKWebView 的轻量浏览器内核
- 左滑返回 / 右滑前进手势导航
- 下拉刷新页面
- 常驻顶部双书签栏
- 加载进度条显示
- 新窗口链接自动内开
- GitHub Actions 云端自动构建 IPA（无签名模式）
- 支持 TrollStore / AltStore / Sideloadly 侧载安装
