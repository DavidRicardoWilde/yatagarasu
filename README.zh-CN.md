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
- 展示阶段性进度；点击侧边栏的“活动”卡片可查看 `brew` 实时输出
- 已对 Installed 列表做显式安装过滤：**仅作为依赖安装的 formula 默认不展示；若用户曾手动安装过，则依然展示**

### GitHub 开源集成

- 精选 GitHub 项目显示在 **Discover** 中，并在统一的软件详情页打开
- 拉取仓库元数据、README 与 Releases
- 在原生 SwiftUI 详情页中展示 README 内容
- 解析适合 macOS 的 Release 资产，优先识别 `.dmg`、`.pkg`、`.zip`
- 当仓库没有适合当前机器的二进制发布时，明确提示用户可从源码构建

### 一个应用，多个来源

- 每个软件的详情页列出所有获取来源（Homebrew、官方网站、GitHub 发行版、源码构建），并针对所选来源给出安全检查
- **Setups** 可一次安装整套入门套件；设置中的 **专长** 决定优先展示哪些套件

### Installed 与 Updates

- **Installed** 在一个可展开的表格中展示 Homebrew 已安装包与 GitHub 来源记录
- **Updates** 将每个更新标记为主要 / 次要 / 补丁版本，主要版本更新默认不勾选

### 原生 macOS 体验

- 基于 `NavigationSplitView` 的主界面，采用安静、浅色优先的设计（Direction A），并适配深色模式
- 设计令牌与通用组件集中在 `DesignSystem/`
- 支持英文、简体中文、繁体中文、日文
- 标准的设置窗口（⌘,），包含通用、专长、来源、更新四个标签页

## 当前范围

已经具备实际功能的区域：

- **Discover**
- **Installed**
- **Updates**
- **Setups**
- **软件详情页**
- **Settings**

仍在完善中的区域（界面中以禁用的“即将提供”控件呈现，可在代码中搜索 `pendingFeature()`）：

- Brewfile 导入与导出
- 多版本并存、后台检查更新、通知
- GitHub 登录与全量 Homebrew 搜索
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

- `App/RootView` 承载 `NavigationSplitView` 主界面；`AppRouter` 管理侧边栏选择与页面栈。
- `AppModel` 是组合根，也是视图触发安装 / 更新 / 卸载的唯一入口。
- `Features/` 按页面拆分目录，统一使用 `DesignSystem/` 中的令牌与组件。

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

Yatagarasu 是一个基于 **Turborepo** 的 monorepo，各平台应用位于 `apps/` 下。

```text
.
├── apps/
│   ├── macos/              # 原生 macOS 应用（SwiftUI）
│   │   ├── package.json
│   │   ├── yatagarasu.xcodeproj
│   │   └── yatagarasu/
│   │       ├── App/            # 入口、AppModel、菜单命令、主窗口
│   │       ├── Navigation/     # 侧边栏目的地与路由
│   │       ├── DesignSystem/   # 设计令牌（颜色、字体、间距）与通用组件
│   │       ├── Catalog/        # 精选条目、入门套件、专长
│   │       ├── Features/       # Discover、Installed、Updates、Setups、PackageDetail、Settings、Sidebar
│   │       ├── Core/           # 模型、服务、工作区、Homebrew 检测、本地化
│   │       └── Resources/      # 资源与 Localizable.strings（en、ja、zh-Hans、zh-Hant）
│   ├── linux/              # Linux 应用（占位，即将开始）
│   └── windows/            # Windows 应用（占位，即将开始）
├── package.json            # 根工作区配置
├── turbo.json              # Turborepo 流水线
└── docs/                   # 架构与产品文档
```

### Monorepo 工具链

- **Turborepo** 编排跨应用构建
- 工作区包以 `@yatagarasu/<platform>` 命名
- 根目录执行 `npm run build` 构建全部应用；`npm run build:macos` 仅构建 macOS

## 如何开始

### 环境要求

- 一套较新的 Xcode 开发环境
- macOS 开发机器
- 如果你要使用 Homebrew 管理功能，需要本机已经安装 Homebrew

### 构建

在仓库根目录执行：

```bash
# 首次需要安装依赖
npm install

# 构建全部应用
npm run build

# 仅构建 macOS
npm run build:macos

# 或直接用 xcodebuild 构建
cd apps/macos
xcodebuild -project yatagarasu.xcodeproj -scheme yatagarasu -configuration Debug -destination 'platform=macOS' build
```

也可以直接用 Xcode 打开 `apps/macos/yatagarasu.xcodeproj`，运行 `yatagarasu` scheme。

### 测试状态

当前仓库还没有完全配置好的自动化测试 action，因此现阶段主要以 `xcodebuild` 构建通过作为基线校验。

## 目前的限制与后续方向

这个项目已经有了完整的核心方向，但仍然处于早期阶段，以下内容还在演进中：

- 设计中的部分控件在后端就绪前仍为占位（见 `pendingFeature()`）
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

如果你要提交 Pull Request，建议先用 `xcodebuild` 或 `npm run build` 确认项目能够正常构建。

## License

本项目使用 [MIT License](./LICENSE)。
