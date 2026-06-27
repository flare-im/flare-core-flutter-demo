# Flare IM Flutter App

这是 `flare_core_flutter_sdk` 的生产级 Flutter IM 应用模板。它以原 `examples/flare-core-flutter` 的完整业务能力为基底，保留 shared、theme、widgets、DDD/Riverpod 状态层、会话列表、聊天页、消息组件、媒体预览、表情贴纸面板和业务消息扩展，同时底层 SDK 接入切换为 `packages/flare-core-flutter-sdk`。

## 技术栈

- Riverpod / Hooks Riverpod：应用状态与页面状态
- GoRouter：登录、会话、聊天、SDK 能力中心路由
- get_it：SDK、Dio、Retrofit API 等基础服务注册
- Freezed：SDK 运行态快照模型
- Retrofit + Dio：网络配置接口模板
- cached_network_image：头像与远程图片缓存
- flutter_slidable：会话列表侧滑置顶/删除
- flare_core_flutter_sdk：IM Core Flutter SDK

## 目录结构

```text
lib/
├── app.dart
├── main.dart
├── application/      # Riverpod providers、服务编排、SDK 事件桥接
├── domain/           # 会话、消息、用户实体和值对象
├── infrastructure/   # SDK 适配器、仓储、媒体资源、存储、mapper
├── interface/        # 路由、页面、主题、可复用 IM UI 组件
└── shared/           # 配置、DI、网络、主题 token、日志
```

## UI 与跨端对齐

- 设计 token：`lib/shared/theme/flare_theme_tokens.dart`、`lib/interface/theme/flare_im_design.dart`
- 中英 i18n：`lib/shared/i18n/`（键与 `flare-core-vue-im-ui` 对齐）
- 会话筛选：全部 / 未读 / @我 / 置顶 / 免打扰 / 归档 / 草稿（`listConversationsByQuery`）
- 详细说明：`docs/UI_AND_I18N.md`

## 已覆盖能力

- SDK 初始化、登录、登出、测试 Token
- 会话列表、筛选、单聊打开、置顶、删除、草稿、已读、同步
- 消息列表、分页、服务端同步、文本/表情/贴纸/图片/视频/音频/文件/位置/名片/任务/日程/引用/转发/投票等消息构建入口
- 发送成功、失败、重发、撤回、编辑、删除、反应、标记、置顶消息
- 连接、会话、消息、同步、输入状态、未读数等 SDK 事件桥接
- Presence 订阅与批量查询
- Media cache 统计与清理
- Capability 查询与当前用户能力查询
- SDK 能力中心：`/sdk-lab`
- 表情和贴纸资源使用压缩 WebP 与 manifest

## 运行

先同步最新 `flare-im-core-sdk` Rust FFI 产物：

```bash
cd ../../../flare-im-core-sdk
cargo xtask build host wasm ios-universal
```

`cargo xtask build host wasm ios-universal` 会生成 host FFI、wasm 与 iOS Simulator universal 产物。macOS 上 `host` 输出 `arm64+x86_64` universal dylib 并放到 `macos/Runner/`；iOS Simulator universal 静态库会放到 `ios/FFI/build/`。移动端产物使用同一入口按需生成：`cargo xtask build ios-universal`、`cargo xtask build ios-device`、`cargo xtask build android`。

安装依赖、检查并运行：

```bash
cd ../../../flare-im-core-client-sdk/examples/flare-core-flutter-app
flutter pub get
flutter analyze --no-fatal-infos
flutter build macos --debug
flutter test
flutter run -d macos
```

macOS Xcode/Flutter build 默认优先复用 `macos/Runner/libflare_im_core_sdk_ffi.dylib`，开发阶段不会每次重编 Rust。需要在 Xcode build script 内强制重编时设置：

```bash
FLARE_BUILD_RUST_FFI=1 flutter build macos --debug
```

iOS simulator 本地运行前建议安装 Pods：

```bash
cd ios && pod install && cd ..
```

iOS 真机包需执行：

```bash
cd ../../../flare-im-core-sdk
cargo xtask build ios-device
```

Android 包需先设置 NDK 并同步 JNI library：

```bash
cd ../../../flare-im-core-sdk
export ANDROID_NDK_ROOT=/path/to/android/ndk
cargo xtask build android
```

`cargo xtask build android` 会同步 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三套 JNI library；Gradle 构建阶段会通过 `cargo xtask build android-verify` 校验三套 ABI 都已存在。iOS Xcode 构建阶段会通过 `cargo xtask build ios-verify` 校验当前 SDK 对应的静态库架构：真机为 `arm64`，模拟器为 `arm64+x86_64` universal。

## 开发

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze --no-fatal-infos
flutter test
```

当前模板保留旧完整 app 的 lint 信息，便于后续逐步收敛代码风格；阻断性编译/测试问题应保持为零。
