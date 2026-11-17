![Portable Rust + MinGW-w64 Setup](banner.svg)
<div align="center">

# 🦀 Portable Rust + MinGW-w64 Setup

**1-Click Windows Setup • Zero Visual Studio C++ Build Tools • 100% Portable**

</div>
# Portable Rust + MinGW-w64 Setup for Windows

🌐 **Language / Sprache:** [English](#-english) | [Deutsch](#-deutsch)

---

## 🇬🇧 English

A lightweight, **1-click batch installer** (`setup_rust_mingw.bat`) that sets up a fully portable **Rust + MinGW-w64 (MSVCRT)** toolchain on Windows—completely eliminating the need for multi-gigabyte Visual Studio C++ Build Tools.

📖 **Full Documentation:** [Read the complete English Guide (`README.en.md`)](README.en.md)

### Key Features
* **Zero Visual Studio Dependency:** Uses WinLibs MinGW-w64 (POSIX-SEH / MSVCRT) combined with Rust's `x86_64-pc-windows-gnullvm` target.
* **Fully Portable & Relocatable:** Install to any directory (defaults to `%USERPROFILE%\RustMinGW`). Moving the folder or reinstalling Windows? Run the script with **`[U]`** to re-link all environment variables and `config.toml` in seconds without re-downloading.
* **Fast Extraction & Smart Fallbacks:** Uses Windows' built-in `tar.exe` for rapid extraction and includes an automatic **Browser Fallback** if strict firewalls or antivirus tools block background downloads.
* **Pre-Configured Linker Setup:** Automatically bridges `libunwind.a` (`libgcc_eh.a`), wires `ld.lld.exe` to MinGW startup objects (`crt2.o`, `crtbegin.o`), and writes a clean UTF-8 (no BOM) `.cargo/config.toml`.

### Quick Start
1. Download `setup_rust_mingw.bat`.
2. Double-click **`setup_rust_mingw.bat`** and press **Enter** (or enter a custom path without spaces).
3. Select **`[N]`** for a fresh installation.
4. Open a new terminal and verify with `cargo new hello_rust && cd hello_rust && cargo run`.

---

## 🇩🇪 Deutsch

Ein schlanker **1-Klick-Batch-Installer** (`setup_rust_mingw.bat`), der eine vollständig portable **Rust + MinGW-w64 (MSVCRT)** Entwicklungsumgebung unter Windows einrichtet – ganz ohne die Installation der mehrere Gigabyte großen Visual Studio C++ Build Tools.

📖 **Ausführliche Anleitung:** [Zur vollständigen deutschen Dokumentation (`README.de.md`)](README.de.md)

### Hauptfunktionen
* **Keine Visual Studio Build Tools nötig:** Nutzt WinLibs MinGW-w64 (POSIX-SEH / MSVCRT) in Kombination mit dem Rust-Target `x86_64-pc-windows-gnullvm`.
* **100 % portabel & umziehbar:** Installation in jeden beliebigen Ordner (Standard: `%USERPROFILE%\RustMinGW`). Nach einem Ordner-Umzug oder einer Windows-Neuinstallation genügt Option **`[U]`**, um alle Pfade und die `config.toml` ohne erneuten Download neu zu verknüpfen.
* **Schnelles Entpacken & Browser-Fallback:** Entpackt Archive mit dem Windows-eigenen `tar.exe` in wenigen Sekunden und öffnet bei blockierten Hintergrund-Downloads automatisch den **Browser-Fallback**.
* **Fertige Linker-Konfiguration:** Überbrückt `libunwind.a` (`libgcc_eh.a`), verbindet `ld.lld.exe` mit den MinGW-Startobjekten (`crt2.o`, `crtbegin.o`) und schreibt eine saubere `.cargo/config.toml` (UTF-8 ohne BOM).

### Schnellstart
1. `setup_rust_mingw.bat` herunterladen.
2. **`setup_rust_mingw.bat`** per Doppelklick starten und **Enter** drücken (oder einen eigenen Pfad ohne Leerzeichen angeben).
3. **`[N]`** für eine Neuinstallation wählen.
4. Neues Terminal öffnen und mit `cargo new hello_rust && cd hello_rust && cargo run` testen.
