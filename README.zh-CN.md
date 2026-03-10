# Yatagarasu

[English](./README.md)

Yatagarasu 是一个使用 SwiftUI 构建的原生 macOS 包管理前端。它的目标不是简单地把终端命令包一层界面，而是把 Homebrew 与 GitHub 开源软件的发现、查看与管理，组织成一个更自然、更统一、更符合 macOS 使用习惯的体验。

这个项目希望解决两个长期存在的问题：一是命令行包管理工具对很多用户仍然有门槛；二是开源软件的分发入口过于分散，用户往往需要在 Homebrew、GitHub Releases、项目主页之间来回切换。Yatagarasu 希望把这些流程收拢到一个清晰、原生、可视化的桌面应用中。

## 设计理念

Yatagarasu 的核心理念很明确：

- **原生优先。** 优先使用 SwiftUI、SwiftData、Observation、Swift Concurrency 等 Apple 技术栈，而不是做一个“看起来像桌面端”的跨平台壳。
- **降低门槛，但不掩盖真实系统。** 它让 Homebrew 和 GitHub 工作流更易用，但不会假装底层机制不存在。
- **操作过程应当可理解。** 安装、升级、卸载的进度、日志与当前状态都应该是可见的。
- **开源软件值得更好的发现方式。** 不应该只靠记住包名或在 GitHub 上手动翻找。
- **重视架构。** 这个项目从一开始就偏向可扩展、可维护的工程设计，而不是把功能堆到一个大 View 里。

## 当前已经实现的内容

Yatagarasu 目前处于持续开发中的 MVP 阶段，但核心链路已经具备可用性。

### Homebrew 管理

- 自动检测本机 Homebrew 安装位置
- 通过 `brew info --json=v2` 读取已安装 formulae 与 casks
- 在界面中触发安装、升级、卸载
- 用浮动命令控制台展示实时输出与阶段性进度
- 已对 Installed 列表做显式安装过滤：**仅作为依赖安装的 formula 默认不展示；若用户曾手动安装过，则依然展示**

### GitHub 开源集成

- 提供独立的 **Open Source** 页面，用于展示精选 GitHub 项目
- 拉取仓库元数据、README 与 Releases
- 在原生 SwiftUI 详情页中展示 README 内容
- 解析适合 macOS 的 Release 资产，优先识别 `.dmg`、`.pkg`、`.zip`
- 当仓库没有适合当前机器的二进制发布时，明确提示用户可从源码构建

### Installed 统一视图

- 在同一个页面中展示 Homebrew 已安装包与 GitHub 来源记录
- 保留安装来源语义，例如 GitHub Release 入口或 Source Build 入口
- 支持识别可更新的 Homebrew 包，并提供批量更新入口

### 原生 macOS 体验

- 基于 `NavigationSplitView` 的主界面布局
- 使用 `ultraThinMaterial`、卡片式分层和 SF Symbols 构建偏原生的视觉风格
- 支持英文、简体中文、繁体中文、日文
- 设置页提供语言切换、Homebrew 重新检测、解析校验、命令控制台开关等能力

## 当前范围

已经具备实际功能的区域：

- **Discover**
- **Open Source**
- **Installed**
- **Settings**

仍在完善中的区域：

- **Categories** 的内容组织
- **Developer / Dev-Space** 的实际能力
- 对 HTML-heavy README 的更强兼容方案
- GitHub Release 安装链路的进一步自动化

## 技术栈

Yatagarasu 使用的是一套非常明确的原生技术栈：

- **语言：** Swift
- **界面：** SwiftUI
- **持久化：** SwiftData
- **状态管理：** Observation（`@Observable`）
- **并发模型：** Swift Concurrency（`async/await`、actor、`AsyncThrowingStream`）
- **网络：** `URLSession`
- **Markdown 渲染：** [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)

## 架构概览

### UI 层

- `ContentView` 负责整体应用壳与主导航。
- 主要功能页面使用 SwiftUI 组件化组织，包括 Discover、Installed、Open Source 与 Settings。

### 状态与编排层

- `PackageWorkspace` 负责 Homebrew 包状态与刷新逻辑。
- `OpenSourceCatalogWorkspace` 负责 GitHub 仓库缓存、刷新与选择状态。
- `InstallationManager` 负责安装任务队列、进度估算、日志记录与控制台历史。

### 服务层

- `ShellExecutor`：异步执行 shell 命令，并将 stdout / stderr 流式回传
- `BrewInfoService`：解析 Homebrew JSON 输出
- `BrewPackageManager`：封装安装、升级、卸载等 Homebrew 操作
- `GitHubRepositoryService`：拉取仓库信息、README 与 Release 资产

### 数据层

- 使用 SwiftData 缓存 GitHub 仓库、Release、README 与安装来源记录

## 项目结构

```text
.
├── yatagarasu/
│   ├── yatagarasu.xcodeproj
│   └── yatagarasu/
│       ├── ContentView.swift
│       ├── PackageWorkspace.swift
│       ├── OpenSourceCatalogWorkspace.swift
│       ├── Services/
│       └── Models/
```

当前仓库采用嵌套结构：Xcode 工程与应用源码都位于顶层 `yatagarasu/` 目录之下。

## 如何开始

### 环境要求

- 一套较新的 Xcode 开发环境
- macOS 开发机器
- 如果你要使用 Homebrew 管理功能，需要本机已经安装 Homebrew

### 构建

在仓库根目录执行：

```bash
cd yatagarasu
xcodebuild -project yatagarasu.xcodeproj -scheme yatagarasu -configuration Debug -destination 'platform=macOS' build
```

也可以直接用 Xcode 打开 `yatagarasu/yatagarasu.xcodeproj`，运行 `yatagarasu` scheme。

### 测试状态

当前仓库还没有完全配置好的自动化测试 action，因此现阶段主要以 `xcodebuild` 构建通过作为基线校验。

## 目前的限制与后续方向

这个项目已经有了完整的核心方向，但仍然处于早期阶段，以下内容还在演进中：

- 部分侧边栏入口目前仍是占位或过渡状态
- 对复杂 HTML README 的专门回退渲染方案尚未接入
- GitHub 集成目前更偏向“发现、查看、记录来源”，而不是对所有项目都提供端到端的托管安装
- Homebrew 相关能力依赖本机 Homebrew 可用

## 为什么要做这个项目

包管理工具本身很强大，但整体体验长期割裂：

- Homebrew 很高效，但主要面向终端用户
- GitHub Releases 很灵活，但项目之间差异巨大
- 很多优秀开源软件并不容易被普通用户发现或理解

Yatagarasu 想做的，是在不牺牲原有能力的前提下，把这些工作流重新组织成一个更自然、可视化、可维护的原生桌面体验。

## 贡献

欢迎围绕以下方向贡献：

- SwiftUI 交互与视觉打磨
- Homebrew / GitHub 集成的边界情况处理
- 包元数据建模与缓存设计
- 本地化
- 自动化测试与开发工具链

如果你要提交 Pull Request，建议先用 `xcodebuild` 确认项目能够正常构建。

## License

本项目使用 [MIT License](./LICENSE)。
