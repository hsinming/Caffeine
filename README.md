# Caffeine (咖啡因)

輕量、簡潔 Windows 防睡眠工具，讓您的電腦隨時保持清醒！

---

## 繁體中文版 (Traditional Chinese)

### 這是什麼？
**Caffeine** 是一款專為 Windows 設計的輕量免安裝工具。就像給電腦喝了咖啡一樣，它能防止您的電腦進入睡眠、休眠或自動關閉螢幕。非常適合在進行簡報、下載大檔案、等待漫長程式運行或觀看影片時使用。

### 核心功能
* **一鍵防止睡眠**：開啟程式即自動生效，防止螢幕變暗與電腦睡眠。
* **豐富的時間預設**：
  * **無限期保持清醒** (預設)。
  * **定時防睡眠**：可選擇保持清醒 1、2、3 或 4 小時。
  * **自訂倒數**：自訂希望清醒的小時與分鐘（例如：1 小時 30 分鐘）。
  * **自訂目標時間**：設定電腦保持清醒直到指定的時刻（例如：下午 17:30）。
* **直觀的狀態指示燈**：托盤圖示會根據當前狀態變更，一眼就能看出電腦會不會睡著：
  * 🔴 **啟動中 (Active)**：顯示裝滿紅色熱咖啡的咖啡杯圖示（`on.ico`），代表防睡眠正在生效（象徵電腦注入咖啡因保持清醒）。
  * ⚪ **停用中 (Inactive)**：顯示空咖啡杯的黑色輪廓圖示（`off.ico`），代表防睡眠已暫停（象徵電腦沒咖啡了），電腦會恢復正常的省電睡眠設定。
* **無感暫停 (Inactive 狀態)**：想要暫時讓電腦恢復正常睡眠？免關閉程式，只需在選單點擊 **Inactive** 即可輕鬆暫停防睡眠！
* **倒數結束自動通知**：當設定的定時時間結束後，程式會自動切換為 Inactive (停用) 狀態，並發出托盤通知提醒您。

### 如何使用？
1. **啟動程式**：
   * 雙擊執行 `Caffeine.exe`（或在已安裝 AutoHotkey 的環境下雙擊 `caffeine.ahk` 腳本）。
2. **尋找圖示**：
   * 啟動後，電腦右下角的系統工作列（工作列托盤）會出現 Caffeine 的圖示。
3. **切換與設定**：
   * **右鍵點擊**托盤圖示，即可自由選擇保持清醒的時間。
   * 將滑鼠懸停在圖示上，會顯示當前防睡眠剩餘的精確時間。
   * 想要暫停防睡眠，請在右鍵選單點選 **Inactive**。
   * 想要徹底關閉程式，請點選 **Stop & Exit**。

### 常見問題 (FAQ)
* **Q：這會修改我的 Windows 系統設定嗎？**
  * **A**：完全不會。本程式只在運行且處於「Active」狀態時，暫時阻擋系統進入睡眠。一旦您將其切換為「Inactive」或徹底關閉程式，Windows 就會立刻恢復您原本設定的省電與睡眠模式。
* **Q：如果我的電腦沒有附帶圖示檔案（.ico），程式還能跑嗎？**
  * **A**：可以。本程式的主程式圖示已完美嵌入在 `Caffeine.exe` 中，並且內建了自動防護機制。即使外部的狀態圖示（`on.ico`/`off.ico`）不小心被刪除，程式依然能流暢運行，不會發生閃退或報錯。

---

## English Version

### What is Caffeine?
**Caffeine** is a lightweight, zero-installation utility designed for Windows. Just like giving your computer a shot of espresso, it temporarily blocks your PC from going to sleep, hibernating, or turning off the screen. Perfect for presentations, long downloads, waiting for render/compilation tasks, or watching media.

### Key Features
* **Instant Sleep Prevention**: Activates immediately upon launch to keep your screen bright and PC awake.
* **Flexible Durations**:
  * **Keep Awake Indefinitely** (Default).
  * **Preset Timers**: Keep awake for exactly 1, 2, 3, or 4 hours.
  * **Custom Countdown**: Define your own countdown duration (e.g., 1 hour and 30 minutes).
  * **Custom Target Time**: Keep awake until a specific wall-clock time (e.g., 17:30).
* **Intuitive Visual Feedback**: The system tray icon dynamically changes to reflect the current state:
  * 🔴 **Active**: Shows the active cup icon (`on.ico`, a coffee cup filled with hot red coffee), indicating sleep prevention is currently active (symbolizing the PC is caffeinated).
  * ⚪ **Inactive**: Shows the inactive cup icon (`off.ico`, a black outline of an empty coffee cup), indicating sleep prevention is paused and Windows will sleep normally (symbolizing the cup is empty).
* **Seamless Pausing**: Want to let your computer sleep normally without closing the app? Simply select **Inactive** from the tray menu to pause sleep prevention.
* **Auto-Notification**: When a timed session expires, Caffeine automatically transitions to the Inactive state and displays a tray tip to let you know.

### How to Use?
1. **Launch the App**:
   * Double-click `Caffeine.exe` (or double-click `caffeine.ahk` if you have AutoHotkey v2 installed).
2. **Locate the Icon**:
   * Once launched, look for the Caffeine icon in your system tray (bottom-right of your taskbar).
3. **Control Status**:
   * **Right-click** the tray icon to choose your preferred awake duration.
   * **Hover** your mouse over the icon to view the exact remaining active time.
   * Select **Inactive** to temporarily pause sleep prevention.
   * Select **Stop & Exit** to completely close the app and restore normal power behavior.

### Frequently Asked Questions (FAQ)
* **Q: Does this modify my Windows power configurations?**
  * **A**: Not at all. It temporarily overrides power behaviors in real-time. As soon as you select "Inactive" or exit the program, your Windows sleep and display-off timers return to normal immediately.
* **Q: Will the app work if the external icon (.ico) files are missing?**
  * **A**: Yes. The main icon is embedded directly inside `Caffeine.exe`. The application features smart fallback guards, meaning it will continue to run flawlessly even if the external `on.ico` and `off.ico` files are moved or deleted.

---

## 特別鳴謝 (Acknowledgements)

本專案的靈感與核心設計深受部落格文章 [Caffeinate Windows](https://den.dev/blog/caffeinate-windows/) 的啟發。特別感謝作者 **Den** 分享了如此實用且棒的思維與設計概念！

This project was inspired by and built upon the wonderful ideas from the blog post: [Caffeinate Windows](https://den.dev/blog/caffeinate-windows/) by **Den**. Special thanks to the author for sharing such a great concept and practical approach!
