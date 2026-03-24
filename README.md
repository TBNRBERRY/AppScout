# WinApp-GUI-Reporter
A lightweight, standalone PowerShell script that audits your Windows system for installed software. It bypasses the "noise" of system drivers and SDKs, providing a clean, categorized list of your actual applications and games.

## ✨ Features
- **Smart Categorization**: Automatically groups items into `STEAM GAMES`, `DEV TOOLS`, `DRIVERS`, and `APPLICATIONS`.
- **Dual-Architecture Scanning**: Scans both 64-bit and 32-bit registry hives (`HKLM` and `HKCU`).
- **Built-in Editor**: A GUI window allows you to live-edit the list before saving.
- **Advanced Tools**: 
  - `Ctrl + F` to Find.
  - `Ctrl + H` to Find and Replace.
  - `Copy All` to clipboard functionality.
- **Clean Output**: Automatically excludes Windows updates, redistributables, and development "packs."

## 🚀 How to Use
1. Download the `AppInventory.ps1` file.
2. Right-click the file and select **Run with PowerShell**.
3. (Optional) If you get an execution policy error, run this command in PowerShell first:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
