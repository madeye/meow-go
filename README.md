# Meow(Go)

![Feature Graphic](fastlane/metadata/android/en-US/images/featureGraphic.png)

A Clash/mihomo Android client with Flutter UI, powered by upstream [mihomo](https://github.com/MetaCubeX/mihomo) (Go) and netstack-smoltcp tun2socks (Rust).

> This is the **Go-engine** fork of [Meow](https://github.com/madeye/meow), with the proxy engine swapped from `mihomo-rust` to the upstream MetaCubeX/mihomo (Go) build. The Rust layer is now a pure tun2socks + DoH forwarder.

## Download

[<img src="https://img.shields.io/badge/Download_from-GitHub-333?style=for-the-badge&logo=github&logoColor=white" alt="Download from GitHub" height="80">](https://github.com/madeye/meow-go/releases/latest)

## Architecture

```
Flutter UI (Dart)
    |  MethodChannel / EventChannel
    v
Android Native (Kotlin)
    |  VpnService + AIDL IPC
    |  JNI (two native libraries)
    |
    |---> libmihomo_android_ffi.so (Rust)
    |         netstack-smoltcp tun2socks
    |         DoH forwarder for UDP:53
    |         TCP -> SOCKS5 127.0.0.1:7890
    |
    |---> libmihomo.so             (Go)
              upstream MetaCubeX/mihomo engine
              mixed listener, rules, proxy adapters
              per-socket VpnService.protect() via dialer hook
    v
Network
```

## Features

- **Proxy Protocols**: Shadowsocks, Trojan, Direct
  - Shadowsocks plugins: built-in `simple-obfs` (HTTP/TLS) and `v2ray-plugin`
    (WebSocket, optional TLS) — no external SIP003 binary required
- **Rule Engine**: Domain, IP, port, geo-based routing, rule-providers
- **tun2socks**: Pure Rust via netstack-smoltcp (no C dependencies)
- **DNS**: DoH forwarding through proxy chain
- **Socket Protection**: Per-socket `VpnService.protect(fd)` via JNI callback
- **Flutter UI**: Shadowrocket-style tab view
  - Home: VPN toggle, proxy node selection, connection status
  - Subscribe: Add/edit/remove subscriptions, view proxy nodes, YAML editor
  - Traffic: Real-time speed chart, session upload/download stats
  - Settings: Version, network config, per-app VPN proxy/bypass, about
- **i18n**: English, Chinese (zh_CN)
- **E2E Tests**: Automated with ssserver + Android emulator

## Building

### Prerequisites

- Android SDK (API 36) with NDK
- Rust toolchain with Android targets:
  ```
  rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
  ```
- Go 1.23+ (used to cross-compile the upstream mihomo engine)
- Flutter SDK (3.x)
- JDK 17

### Build

```bash
# Generate Flutter module files
cd flutter_module && flutter pub get && cd ..

# Build debug APK (arm64 only, release native libraries)
export JAVA_HOME=/path/to/jdk17
./gradlew :mobile:assembleDebug -PTARGET_ABI=arm64 -PCARGO_PROFILE=release -PGO_PROFILE=release
```

The APK is at `mobile/build/outputs/apk/debug/mobile-arm64-v8a-debug.apk`.

### E2E Test

```bash
# Requires: ssserver, Android emulator, adb
./test-e2e.sh
```

## Project Structure

```
core/                           Android library module
  src/main/java/                Kotlin: VPN service, AIDL, Room DB
  src/main/rust/
    mihomo-android-ffi/         Rust FFI crate (JNI + netstack-smoltcp tun2socks + DoH)
  src/main/go/
    mihomo-core/                Go module wrapping upstream MetaCubeX/mihomo
flutter_module/                 Flutter UI module
  lib/screens/                  Home, Subscriptions, Traffic, Settings
  lib/l10n/                     Localization (en, zh_CN)
mobile/                         Android app module (FlutterActivity host)
test-e2e.sh                     End-to-end test script
```

## License

[MIT](LICENSE) - Max Lv <max.c.lv@gmail.com>
