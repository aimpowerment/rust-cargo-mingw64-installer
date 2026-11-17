@echo off
title Portables Rust + MinGW-w64 Setup (1-Klick mit Browser-Fallback)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$raw = Get-Content -LiteralPath '%~f0' -Raw; $idx = $raw.LastIndexOf('###PS_START###'); if ($idx -lt 0) { Write-Host '[FEHLER] Marker nicht gefunden!'; exit 1 }; $code = $raw.Substring($idx + 14); Invoke-Expression $code"
pause
goto :EOF

###PS_START###
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Host "============================================================================"
    Write-Host " Portables Setup: MinGW64 + Rustup + Cargo (ohne Visual Studio Build Tools)"
    Write-Host "============================================================================"
    Write-Host ""

    # 1. Zielpfad abfragen (Standard: %USERPROFILE%\RustMinGW)
    $defaultDir = Join-Path $env:USERPROFILE "RustMinGW"
    while ($true) {
        Write-Host "Wohin sollen MinGW64, Rustup und Cargo installiert werden?"
        Write-Host "(Hinweis: Pfad darf keine Leerzeichen oder Sonderzeichen wie ! oder & enthalten)"
        $inputDir = Read-Host "Zielordner [Enter fuer $defaultDir]"
        $base = if ([string]::IsNullOrWhiteSpace($inputDir)) { $defaultDir } else { $inputDir.Trim().Trim('"').TrimEnd('\') }

        if ($base -match '[\s!&]') {
            Write-Host "[WARNUNG] Der Pfad enthaelt Leerzeichen oder Sonderzeichen! Bitte sauberen Pfad waehlen (z. B. C:\RustMinGW oder D:\_DEV\_LIB)." -ForegroundColor Yellow
            continue
        }
        break
    }

    Write-Host "`n[INFO] Zielordner: $base`n"

    # 2. Bestehende Installation erkennen
    if ($env:RUSTUP_HOME -and (Test-Path $env:RUSTUP_HOME)) { Write-Host "[HINWEIS] Aktive RUSTUP_HOME: $env:RUSTUP_HOME" }
    if ($env:CARGO_HOME -and (Test-Path $env:CARGO_HOME)) { Write-Host "[HINWEIS] Aktive CARGO_HOME: $env:CARGO_HOME" }
    if ((Test-Path "$base\.cargo\bin\cargo.exe") -or (Test-Path "$base\mingw64\bin\gcc.exe")) {
        Write-Host "[HINWEIS] Im Zielordner '$base' liegen bereits Dateien!"
    }

    Write-Host "`nWas moechtest du tun?"
    Write-Host "  [N] MinGW64 + Rustup + Cargo neu herunterladen und unter '$base' installieren"
    Write-Host "  [U] Nur Pfade und config.toml auf '$base' erneuern (kein Download)"
    Write-Host "  [A] Abbrechen`n"

    $mode = "INSTALL"
    while ($true) {
        $choice = (Read-Host "Bitte waehle [N], [U] oder [A]").Trim().ToUpper()
        if ($choice -eq 'A') { Write-Host "Abgebrochen."; return }
        if ($choice -eq 'U') { $mode = "RELINK"; break }
        if ($choice -eq 'N') { $mode = "INSTALL"; break }
    }

    if ($mode -eq "RELINK" -and (-not (Test-Path "$base\mingw64\bin\gcc.exe") -or -not (Test-Path "$base\.cargo\bin\cargo.exe"))) {
        throw "Fuer [U] fehlen gcc.exe oder cargo.exe im Zielordner. Bitte starte erneut mit [N]."
    }

    [System.IO.Directory]::CreateDirectory("$base\.cargo") | Out-Null
    $downloadsDir = Join-Path $env:USERPROFILE 'Downloads'

    # 3. MinGW64 laden und per tar.exe entpacken (inkl. Downloads- & Browser-Fallback)
    if ($mode -eq "INSTALL") {
        if (Test-Path "$base\mingw64\bin\gcc.exe") {
            Write-Host "`n[1/5] MinGW64 liegt bereits unter $base\mingw64 bereit."
        } else {
            Write-Host "`n[1/5] Pruefe und lade WinLibs MinGW64 (MSVCRT)..."
            $zip = Join-Path $env:TEMP 'winlibs_mingw64.zip'
            if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }

            $localMingw = Get-ChildItem $downloadsDir -Filter 'winlibs-*msvcrt*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($localMingw) {
                Copy-Item -Path $localMingw.FullName -Destination $zip -Force
                Write-Host ("      [OK] Vorhandenes Archiv aus Downloads uebernommen: " + $localMingw.Name)
            } else {
                try {
                    $page = Invoke-WebRequest -Uri 'https://winlibs.com' -UseBasicParsing -UserAgent 'Mozilla/5.0'
                    $links = [regex]::Matches($page.Content, 'https://github\.com/brechtsanders/winlibs_mingw/releases/download/[^"''\s<>]+\.zip') | ForEach-Object { $_.Value }
                    $downloadUrl = $links | Where-Object { $_ -like '*x86_64*' -and $_ -like '*posix-seh*' -and $_ -like '*msvcrt*' -and $_ -notlike '*llvm*' -and $_ -notlike '*clang*' } | Select-Object -First 1
                    if ($downloadUrl) {
                        Write-Host ("      Lade herunter: " + (Split-Path $downloadUrl -Leaf))
                        & curl.exe -fsSL "$downloadUrl" -o "$zip"
                    }
                } catch {}
            }

            while (-not (Test-Path $zip) -or ((Get-Item $zip).Length -lt 50000000)) {
                if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
                Write-Host "`n[BROWSER-FALLBACK] Automatischer MinGW64-Download wurde blockiert." -ForegroundColor Yellow
                Write-Host "  Bitte lade auf der geoeffneten Seite unter 'MSVCRT runtime' das Win64 ZIP-Archiv"
                Write-Host "  (ohne LLVM/Clang) in deinen Downloads-Ordner herunter."
                Start-Process 'https://winlibs.com'
                Read-Host "Sobald der Download im Browser fertig ist, druecke [Enter]"

                $localMingw = Get-ChildItem $downloadsDir -Filter 'winlibs-*msvcrt*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($localMingw) { Copy-Item -Path $localMingw.FullName -Destination $zip -Force }
            }

            if (Test-Path "$base\mingw64") { Remove-Item "$base\mingw64" -Recurse -Force }
            Write-Host "      Entpacke MinGW64 nach $base\mingw64 (per tar.exe)..."
            $extTemp = Join-Path $env:TEMP ("winlibs_" + [System.Guid]::NewGuid().ToString("N"))
            [System.IO.Directory]::CreateDirectory($extTemp) | Out-Null

            & tar.exe -xf $zip -C $extTemp
            if ($LASTEXITCODE -ne 0) { throw "Entpacken mit tar.exe fehlgeschlagen!" }
            Remove-Item $zip -Force -ErrorAction SilentlyContinue

            if (Test-Path "$extTemp\mingw64\bin\gcc.exe") { Move-Item "$extTemp\mingw64" "$base\mingw64" -Force }
            elseif (Test-Path "$extTemp\bin\gcc.exe") { Move-Item "$extTemp" "$base\mingw64" -Force }
            else { throw "gcc.exe im Archiv nicht gefunden!" }
            Remove-Item $extTemp -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "      [OK] MinGW64 bereit."
        }
    }

    # 4. Umgebungsvariablen und Path setzen
    Write-Host "[2/5] Setze Umgebungsvariablen (RUSTUP_HOME, CARGO_HOME, Path)..."
    [Environment]::SetEnvironmentVariable('RUSTUP_HOME', "$base\.rustup", 'User')
    [Environment]::SetEnvironmentVariable('CARGO_HOME', "$base\.cargo", 'User')

    $rawPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $cur = if ([string]::IsNullOrWhiteSpace($rawPath)) { @() } else { $rawPath -split ';' | Where-Object { $_ -ne '' -and $_ -notlike '*\.cargo\bin' -and $_ -notlike '*\mingw64\bin' } }
    $clean = ($cur + @("$base\.cargo\bin", "$base\mingw64\bin") | Select-Object -Unique) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $clean, 'User')

    $env:RUSTUP_HOME = "$base\.rustup"
    $env:CARGO_HOME = "$base\.cargo"
    $env:Path = "$base\.cargo\bin;$base\mingw64\bin;" + $env:Path

    # 5. Rustup und Cargo laden (inkl. Downloads- & Browser-Fallback)
    if ($mode -eq "INSTALL") {
        Write-Host "[3/5] Pruefe und lade rustup-init.exe..."
        $rustupExe = Join-Path $base 'rustup-init.exe'
        $dlFile = Join-Path $downloadsDir 'rustup-init.exe'
        $rustupUrl = 'https://rust-lang.org'

        if ((Test-Path $dlFile) -and ((Get-Item $dlFile).Length -gt 1000000)) {
            Copy-Item -Path $dlFile -Destination $rustupExe -Force
            Write-Host "      [OK] Vorhandene rustup-init.exe aus Downloads uebernommen."
        }

        if (-not (Test-Path $rustupExe) -or ((Get-Item $rustupExe).Length -lt 1000000)) {
            if (Test-Path $rustupExe) { Remove-Item $rustupExe -Force -ErrorAction SilentlyContinue }
            try {
                Import-Module BitsTransfer -ErrorAction SilentlyContinue
                Start-BitsTransfer -Source $rustupUrl -Destination $rustupExe -ErrorAction Stop
            } catch {}
        }

        while (-not (Test-Path $rustupExe) -or ((Get-Item $rustupExe).Length -lt 1000000)) {
            if (Test-Path $rustupExe) { Remove-Item $rustupExe -Force -ErrorAction SilentlyContinue }
            Write-Host "`n[BROWSER-FALLBACK] Automatischer Rustup-Download wurde blockiert." -ForegroundColor Yellow
            Write-Host "  Der Download von rustup-init.exe wurde jetzt im Browser gestartet."
            Start-Process $rustupUrl
            Read-Host "Sobald rustup-init.exe im Downloads-Ordner fertig ist, druecke [Enter]"

            if ((Test-Path $dlFile) -and ((Get-Item $dlFile).Length -gt 1000000)) {
                Copy-Item -Path $dlFile -Destination $rustupExe -Force
            }
        }

        Unblock-File -Path $rustupExe -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Write-Host "      Installiere Rustup und Cargo nach $base (Host: x86_64-pc-windows-gnu)..."
        & $rustupExe --default-host x86_64-pc-windows-gnu --no-modify-path -y
        if ($LASTEXITCODE -ne 0) { throw "rustup-init.exe Fehlercode: $LASTEXITCODE" }
        Remove-Item $rustupExe -Force -ErrorAction SilentlyContinue
        Write-Host "      [OK] Rustup und Cargo unter $base\.cargo installiert."
    } else {
        Write-Host "[3/5] Ueberspringe Rustup-Installation..."
    }

    # 6. gnullvm-Target & libunwind.a Fix
    Write-Host "[4/5] Richte gnullvm-Target und libunwind.a ein..."
    & "$base\.cargo\bin\rustup.exe" target add x86_64-pc-windows-gnullvm
    if ($LASTEXITCODE -ne 0) { throw "rustup target add fehlgeschlagen!" }

    $gccEh = Get-ChildItem "$base\mingw64" -Filter 'libgcc_eh.a' -Recurse | Select-Object -First 1 -ExpandProperty FullName
    $targetDir = "$base\.rustup\toolchains\stable-x86_64-pc-windows-gnu\lib\rustlib\x86_64-pc-windows-gnullvm\lib"
    if (-not $gccEh -or -not (Test-Path $targetDir)) { throw "libgcc_eh.a oder Zielverzeichnis nicht gefunden!" }
    Copy-Item -Path $gccEh -Destination "$targetDir\libunwind.a" -Force

    # 7. Globale config.toml ohne BOM schreiben
    Write-Host "[5/5] Schreibe globale config.toml (UTF-8 ohne BOM)..."
    $bFwd = $base -replace '\\', '/'
    $lld = "$bFwd/.rustup/toolchains/stable-x86_64-pc-windows-gnu/lib/rustlib/x86_64-pc-windows-gnu/bin/gcc-ld/ld.lld.exe"
    $crt2 = (Get-ChildItem "$base\mingw64" -Filter 'crt2.o' -Recurse | Select-Object -First 1 -ExpandProperty FullName) -replace '\\', '/'
    $crtB = (Get-ChildItem "$base\mingw64" -Filter 'crtbegin.o' -Recurse | Select-Object -First 1 -ExpandProperty FullName) -replace '\\', '/'
    if (-not $crt2 -or -not $crtB) { throw "Startup-Dateien crt2.o oder crtbegin.o fehlen!" }

    $tomlContent = @"
[build]
target = "x86_64-pc-windows-gnullvm"

[target.x86_64-pc-windows-gnullvm]
linker = "$lld"
rustflags = [
  "-C", "linker-flavor=ld",
  "-C", "link-arg=$crt2",
  "-C", "link-arg=$crtB",
  "-L", "$bFwd/mingw64/x86_64-w64-mingw32/lib",
  "-L", "$bFwd/mingw64/lib",
  "-L", "$bFwd/.rustup/toolchains/stable-x86_64-pc-windows-gnu/lib/rustlib/x86_64-pc-windows-gnullvm/lib"
]

[env]
CC_x86_64-pc-windows-gnullvm = "$bFwd/mingw64/bin/gcc.exe"
AR_x86_64-pc-windows-gnullvm = "$bFwd/mingw64/bin/ar.exe"
"@
    [System.IO.File]::WriteAllText("$base\.cargo\config.toml", $tomlContent, [System.Text.UTF8Encoding]::new($false))

    Write-Host "`n============================================================================" -ForegroundColor Green
    Write-Host " Fertig! Aktive Versionen unter ${base}:" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    & "$base\.cargo\bin\rustup.exe" --version
    & "$base\.cargo\bin\rustc.exe" --version
    & "$base\.cargo\bin\cargo.exe" --version
    & "$base\mingw64\bin\gcc.exe" --version
    Write-Host "`nBitte oeffne ein neues Terminal, damit die Path-Variablen aktiv sind."
} catch {
    Write-Host "`n[FEHLER] $($_.Exception.Message)" -ForegroundColor Red
}
