# iOS Rust FFI（`flare_sdk_create` 等）

## 你遇到的错误

**Flutter / Xcode：`Internal Inconsistency` / `Build operation failed without specifying any errors`**：常见根因仍是 **未在 `ios/FFI/build/` 放置 `libflare_im_core_sdk_ffi.a`**（链接阶段失败，错误被 Xcode 吞掉）。在 **`flare-im-core-client-sdk`** 执行 **`cargo xtask build ios-sim`** 后再 `flutter clean` 与 `pod install`。Runner 工程已增加 **Verify Rust FFI staticlib** 构建阶段，缺库时会直接 `exit 1` 并打印命令。

`dlsym(RTLD_DEFAULT, flare_sdk_create): symbol not found` 表示：**Dart 用 `DynamicLibrary.process()` 查符号，但主程序里没有链进 Rust 静态库**。  
仅写 Dart FFI 不够，必须把 `libflare_im_core_sdk_ffi.a` 链进 **Runner**，并用 **`-force_load`** 拉入全部目标文件（否则链接器会认为无人引用而把整库裁掉）。

## 本示例已做的集成

1. **Rust 静态库不在 Xcode 内编译**：在 monorepo 中进入 **`flare-im-core-client-sdk`**，执行 **`cargo xtask build ios-sim`**（模拟器默认 **arm64 sim**）或 **`cargo xtask build ios-device`**（真机），将 **`libflare_im_core_sdk_ffi.a`** 拷到 **`ios/FFI/build/`**。
2. **`ios/Flutter/Debug.xcconfig` / `Release.xcconfig`**：  
   `-Wl,-force_load,$(SRCROOT)/FFI/build/libflare_im_core_sdk_ffi.a -lc++`

## 你需要准备的环境

- 安装 [Rust](https://rustup.rs)，并确保 `cargo` 在 PATH 中（Xcode 构建时也会用 PATH）。
- 首次构建前建议手动安装 target（脚本里也会 `rustup target add`）：
  ```bash
  rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
  ```
- 在 **`flare-im-core-client-sdk`** 先执行 **`cargo xtask build ios-sim`**，保证 **`ios/FFI/build/libflare_im_core_sdk_ffi.a`** 存在后再 `flutter run`。

## 再试运行

```bash
cd flare-im-core-client-sdk && cargo xtask build ios-sim && cd -
cd flare-im-core-client-sdk/examples/flare-core-flutter-app
./scripts/setup_ios.sh   # 或手动: flutter pub get && cd ios && pod install
flutter run -d "iPhone 17 Pro"
```

若链接仍报错（缺系统库等），把 Xcode **Report navigator** 里完整 **Link** 日志贴出再补 `-framework Security` 等依赖。

## `未生成静态库` / `aws-lc-sys` CMake 报错

`bindings/c` 属于 **workspace**，Rust 产物在 **`flare-im-core-sdk/target/<triple>/release/`**；**`cargo xtask build ios-sim|ios-device|android`** 从该目录拷贝到 Flutter 工程。

若 `cargo` 在编译 `aws-lc-sys` 时失败（CMake 提示缺少 `tool` 目录、`go_tests.txt` 等），多半是 **中途失败留下的损坏 CMake 缓存**。在仓库根下执行：

```bash
rm -rf flare-im-core-sdk/target/aarch64-apple-ios-sim/release/build/aws-lc-sys-*
# Intel 模拟器则换 x86_64-apple-ios；真机换 aarch64-apple-ios
```

然后重新在 Xcode / `flutter run` 构建。仍失败时再执行 `cargo clean -p aws-lc-sys`（在 `flare-im-core-sdk` 目录）后重试。
