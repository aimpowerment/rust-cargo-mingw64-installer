@echo off
title Portable Rust + MinGW-w64 Setup (1-Click with Browser Fallback)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$raw = Get-Content -LiteralPath '%~f0' -Raw; $idx = $raw.LastIndexOf('###PS_START###'); if ($idx -lt 0) { Write-Host '[ERROR] Marker not found!'; exit 1 }; $code = $raw.Substring($idx + 14); Invoke-Expression $code"
pause
goto :EOF

###PS_START###
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Host "============================================================================"
    Write-Host " Portable Setup: MinGW64 + Rustup + Cargo (No Visual Studio Build Tools)"
    Write-Host "============================================================================"
    Write-Host ""

    # 1. Ask for target directory (Default: %USERPROFILE%\RustMinGW)
    $defaultDir = Join-Path $env:USERPROFILE "RustMinGW"
    while ($true) {
        Write-Host "Where should MinGW64, Rustup, and Cargo be installed?"
        Write-Host "(Note: Path must not contain spaces or special characters like ! or &)"
        $inputDir = Read-Host "Target directory [Press Enter for $defaultDir]"
        $base = if ([string]::IsNullOrWhiteSpace($inputDir)) { $defaultDir } else { $inputDir.Trim().Trim('"').TrimEnd('\') }

        if ($base -match '[\s!&]') {
            Write-Host "[WARNING] The path contains spaces or invalid special characters! Please choose a clean path (e.g., C:\RustMinGW or D:\_DEV\_LIB)." -ForegroundColor Yellow
            continue
        }
        break
    }

    Write-Host "`n[INFO] Target directory: $base`n"

    # 2. Detect existing installation
    if ($env:RUSTUP_HOME -and (Test-Path $env:RUSTUP_HOME)) { Write-Host "[NOTICE] Active RUSTUP_HOME detected: $env:RUSTUP_HOME" }
    if ($env:CARGO_HOME -and (Test-Path $env:CARGO_HOME)) { Write-Host "[NOTICE] Active CARGO_HOME detected: $env:CARGO_HOME" }
    if ((Test-Path "$base\.cargo\bin\cargo.exe") -or (Test-Path "$base\mingw64\bin\gcc.exe")) {
        Write-Host "[NOTICE] Existing files detected in target directory '$base'!"
    }

    Write-Host "`nWhat would you like to do?"
    Write-Host "  [N] Download and install fresh MinGW64 + Rustup + Cargo under '$base'"
    Write-Host "  [U] Update environment paths and config.toml for '$base' only (no download)"
    Write-Host "  [A] Abort`n"

    $mode = "INSTALL"
    while ($true) {
        $choice = (Read-Host "Please choose [N], [U], or [A]").Trim().ToUpper()
        if ($choice -eq 'A') { Write-Host "Aborted by user."; return }
        if ($choice -eq 'U') { $mode = "RELINK"; break }
        if ($choice -eq 'N') { $mode = "INSTALL"; break }
    }

    if ($mode -eq "RELINK" -and (-not (Test-Path "$base\mingw64\bin\gcc.exe") -or -not (Test-Path "$base\.cargo\bin\cargo.exe"))) {
        throw "gcc.exe or cargo.exe is missing in the target directory for [U]. Please restart and select [N]."
    }

    [System.IO.Directory]::CreateDirectory("$base\.cargo") | Out-Null
    $downloadsDir = Join-Path $env:USERPROFILE 'Downloads'

    # 3. Download and extract MinGW64 via tar.exe (with Downloads & Browser Fallback)
    if ($mode -eq "INSTALL") {
        if (Test-Path "$base\mingw64\bin\gcc.exe") {
            Write-Host "`n[1/5] MinGW64 is already present under $base\mingw64."
        } else {
            Write-Host "`n[1/5] Checking and downloading WinLibs MinGW64 (MSVCRT)..."
            $zip = Join-Path $env:TEMP 'winlibs_mingw64.zip'
            if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }

            $localMingw = Get-ChildItem $downloadsDir -Filter 'winlibs-*msvcrt*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($localMingw) {
                Copy-Item -Path $localMingw.FullName -Destination $zip -Force
                Write-Host ("      [OK] Using existing archive from Downloads: " + $localMingw.Name)
            } else {
                try {
                    $page = Invoke-WebRequest -Uri 'https://winlibs.com' -UseBasicParsing -UserAgent 'Mozilla/5.0'
                    $links = [regex]::Matches($page.Content, 'https://github\.com/brechtsanders/winlibs_mingw/releases/download/[^"''\s<>]+\.zip') | ForEach-Object { $_.Value }
                    $downloadUrl = $links | Where-Object { $_ -like '*x86_64*' -and $_ -like '*posix-seh*' -and $_ -like '*msvcrt*' -and $_ -notlike '*llvm*' -and $_ -notlike '*clang*' } | Select-Object -First 1
                    if ($downloadUrl) {
                        Write-Host ("      Downloading: " + (Split-Path $downloadUrl -Leaf))
                        & curl.exe -fsSL "$downloadUrl" -o "$zip"
                    }
                } catch {}
            }

            while (-not (Test-Path $zip) -or ((Get-Item $zip).Length -lt 50000000)) {
                if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
                Write-Host "`n[BROWSER FALLBACK] Automated MinGW64 download was blocked." -ForegroundColor Yellow
                Write-Host "  Please download the Win64 ZIP archive (without LLVM/Clang) under 'MSVCRT runtime'"
                Write-Host "  from the opened page into your Downloads folder."
                Start-Process 'https://winlibs.com'
                Read-Host "Once the download finishes in your browser, press [Enter]"

                $localMingw = Get-ChildItem $downloadsDir -Filter 'winlibs-*msvcrt*.zip' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($localMingw) { Copy-Item -Path $localMingw.FullName -Destination $zip -Force }
            }

            if (Test-Path "$base\mingw64") { Remove-Item "$base\mingw64" -Recurse -Force }
            Write-Host "      Extracting MinGW64 to $base\mingw64 (via tar.exe)..."
            $extTemp = Join-Path $env:TEMP ("winlibs_" + [System.Guid]::NewGuid().ToString("N"))
            [System.IO.Directory]::CreateDirectory($extTemp) | Out-Null

            & tar.exe -xf $zip -C $extTemp
            if ($LASTEXITCODE -ne 0) { throw "Extraction via tar.exe failed!" }
            Remove-Item $zip -Force -ErrorAction SilentlyContinue

            if (Test-Path "$extTemp\mingw64\bin\gcc.exe") { Move-Item "$extTemp\mingw64" "$base\mingw64" -Force }
            elseif (Test-Path "$extTemp\bin\gcc.exe") { Move-Item "$extTemp" "$base\mingw64" -Force }
            else { throw "gcc.exe was not found inside the archive!" }
            Remove-Item $extTemp -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "      [OK] MinGW64 ready."
        }
    }

    # 4. Set environment variables and Path
    Write-Host "[2/5] Setting environment variables (RUSTUP_HOME, CARGO_HOME, Path)..."
    [Environment]::SetEnvironmentVariable('RUSTUP_HOME', "$base\.rustup", 'User')
    [Environment]::SetEnvironmentVariable('CARGO_HOME', "$base\.cargo", 'User')

    $rawPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $cur = if ([string]::IsNullOrWhiteSpace($rawPath)) { @() } else { $rawPath -split ';' | Where-Object { $_ -ne '' -and $_ -notlike '*\.cargo\bin' -and $_ -notlike '*\mingw64\bin' } }
    $clean = ($cur + @("$base\.cargo\bin", "$base\mingw64\bin") | Select-Object -Unique) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $clean, 'User')

    $env:RUSTUP_HOME = "$base\.rustup"
    $env:CARGO_HOME = "$base\.cargo"
    $env:Path = "$base\.cargo\bin;$base\mingw64\bin;" + $env:Path

    # 5. Download and install Rustup and Cargo (with Downloads & Browser Fallback)
    if ($mode -eq "INSTALL") {
        Write-Host "[3/5] Checking and downloading rustup-init.exe..."
        $rustupExe = Join-Path $base 'rustup-init.exe'
        $dlFile = Join-Path $downloadsDir 'rustup-init.exe'
        $rustupUrl = 'https://rust-lang.org'

        if ((Test-Path $dlFile) -and ((Get-Item $dlFile).Length -gt 1000000)) {
            Copy-Item -Path $dlFile -Destination $rustupExe -Force
            Write-Host "      [OK] Using existing rustup-init.exe from Downloads."
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
            Write-Host "`n[BROWSER FALLBACK] Automated Rustup download was blocked." -ForegroundColor Yellow
            Write-Host "  The download for rustup-init.exe has been launched in your browser."
            Start-Process $rustupUrl
            Read-Host "Once rustup-init.exe finishes downloading into your Downloads folder, press [Enter]"

            if ((Test-Path $dlFile) -and ((Get-Item $dlFile).Length -gt 1000000)) {
                Copy-Item -Path $dlFile -Destination $rustupExe -Force
            }
        }

        Unblock-File -Path $rustupExe -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        Write-Host "      Installing Rustup and Cargo to $base (Host: x86_64-pc-windows-gnu)..."
        & $rustupExe --default-host x86_64-pc-windows-gnu --no-modify-path -y
        if ($LASTEXITCODE -ne 0) { throw "rustup-init.exe exited with error code: $LASTEXITCODE" }
        Remove-Item $rustupExe -Force -ErrorAction SilentlyContinue
        Write-Host "      [OK] Rustup and Cargo installed under $base\.cargo."
    } else {
        Write-Host "[3/5] Skipping Rustup installation..."
    }

    # 6. Configure gnullvm target & libunwind.a fix
    Write-Host "[4/5] Configuring gnullvm target and libunwind.a..."
    & "$base\.cargo\bin\rustup.exe" target add x86_64-pc-windows-gnullvm
    if ($LASTEXITCODE -ne 0) { throw "rustup target add failed!" }

    $gccEh = Get-ChildItem "$base\mingw64" -Filter 'libgcc_eh.a' -Recurse | Select-Object -First 1 -ExpandProperty FullName
    $targetDir = "$base\.rustup\toolchains\stable-x86_64-pc-windows-gnu\lib\rustlib\x86_64-pc-windows-gnullvm\lib"
    if (-not $gccEh -or -not (Test-Path $targetDir)) { throw "libgcc_eh.a or gnullvm target directory not found!" }
    Copy-Item -Path $gccEh -Destination "$targetDir\libunwind.a" -Force

    # 7. Write global config.toml without BOM
    Write-Host "[5/5] Writing global config.toml (UTF-8 without BOM)..."
    $bFwd = $base -replace '\\', '/'
    $lld = "$bFwd/.rustup/toolchains/stable-x86_64-pc-windows-gnu/lib/rustlib/x86_64-pc-windows-gnu/bin/gcc-ld/ld.lld.exe"
    $crt2 = (Get-ChildItem "$base\mingw64" -Filter 'crt2.o' -Recurse | Select-Object -First 1 -ExpandProperty FullName) -replace '\\', '/'
    $crtB = (Get-ChildItem "$base\mingw64" -Filter 'crtbegin.o' -Recurse | Select-Object -First 1 -ExpandProperty FullName) -replace '\\', '/'
    if (-not $crt2 -or -not $crtB) { throw "Startup objects crt2.o or crtbegin.o are missing!" }

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
    Write-Host " Done! Active versions under ${base}:" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    & "$base\.cargo\bin\rustup.exe" --version
    & "$base\.cargo\bin\rustc.exe" --version
    & "$base\.cargo\bin\cargo.exe" --version
    & "$base\mingw64\bin\gcc.exe" --version
    Write-Host "`nPlease open a new terminal window for the updated Path variables to take effect."
} catch {
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
}
