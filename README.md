# word_search_game

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Wireless Debug
### 查詢手機 IP
到手機的 「設定」>「關於手機」>「狀態」 或點擊目前的 Wi-Fi 連線名稱查看 IP 位址（例如 192.168.1.100）。
### 建立連線
```
adb devices
adb tcpip 5555
adb connect 192.168.1.117:5555
```
### 強制讓 Flutter 重新偵測
在 VS Code 中按下 Cmd + Shift + P 打開指令面板，輸入並選擇：Flutter: Select Device