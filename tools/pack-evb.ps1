<#
.SYNOPSIS
    بسته‌بندی نسخهٔ ویندوز دارویار به یک فایل exe تک‌فایل با Enigma Virtual Box.

.DESCRIPTION
    یک پروژهٔ .evb (فرمت XML با کدگذاری UTF-16) برای همهٔ فایل‌های پوشهٔ ریلیز
    می‌سازد، خودِ exe ورودی را از فهرست کنار می‌گذارد (خروجی، خودِ exe است) و
    سپس پروژه را با enigmavbconsole.exe پردازش می‌کند.

    پیش‌نیاز: Enigma Virtual Box نصب شده باشد (به‌صورت پیش‌فرض از مسیر
    نصب استاندارد جست‌وجو می‌شود؛ در غیر این صورت -EvbConsole را بدهید).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\pack-evb.ps1
#>
[CmdletBinding()]
param(
    # پوشهٔ خروجی ریلیز ویندوز (flutter build windows)
    [string]$ReleaseDir = "",
    # مسیر خروجی نهایی exe تک‌فایل
    [string]$OutputExe = "",
    # مسیر کنسول Enigma Virtual Box
    [string]$EvbConsole = ""
)

$ErrorActionPreference = "Stop"

# مسیر ریشهٔ پروژه (این فایل در tools\ قرار دارد)
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $ReleaseDir) {
    $ReleaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
}
if (-not $OutputExe) {
    $OutputExe = Join-Path $projectRoot "نسخه های ریلیز شده\Darooyar.exe"
}

# --- 1) پیدا کردن enigmavbconsole.exe ---
if (-not $EvbConsole) {
    $candidates = @(
        "${env:ProgramFiles}\Enigma Virtual Box\enigmavbconsole.exe",
        "${env:ProgramFiles(x86)}\Enigma Virtual Box\enigmavbconsole.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $EvbConsole = $c; break }
    }
}
if (-not $EvbConsole -or -not (Test-Path $EvbConsole)) {
    throw "enigmavbconsole.exe پیدا نشد. با پارامتر -EvbConsole مسیر آن را بدهید."
}

# --- 2) اعتبارسنجی ورودی‌ها ---
$ReleaseDir = (Resolve-Path $ReleaseDir).Path
$inputExe = Get-ChildItem -Path $ReleaseDir -Filter "*.exe" -File |
    Sort-Object Length -Descending | Select-Object -First 1
if (-not $inputExe) {
    throw "هیچ فایل exe در $ReleaseDir پیدا نشد. اول build windows را اجرا کنید."
}
$inputExe = $inputExe.FullName

$outputDir = Split-Path -Parent $OutputExe
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$outputExeFull = [System.IO.Path]::GetFullPath($OutputExe)

# --- 3) تولید گره‌های XML بازگشتی برای درخت پوشه ---
$exclude = @($inputExe.ToLowerInvariant())

# Enigma Virtual Box در مسیرهای غیرASCII (فارسی) نام خروجی را نمی‌سازد؛
# خروجی ابتدا در مسیر انگلیسی ساخته و سپس به مقصد نهایی کپی می‌شود.
$asciiOutput = Join-Path ([System.IO.Path]::GetTempPath()) "darooyar_boxed.exe"

function Escape-Xml([string]$s) {
    return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

function Get-ChildrenXml([string]$dir) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($item in (Get-ChildItem -Path $dir -Force | Sort-Object Name)) {
        if ($exclude -contains $item.FullName.ToLowerInvariant()) { continue }
        $name = Escape-Xml $item.Name
        if ($item.PSIsContainer) {
            $inner = Get-ChildrenXml $item.FullName
            $parts.Add("<File><Type>3</Type><Name>$name</Name><Action>0</Action><OverwriteDateTime>false</OverwriteDateTime><OverwriteAttributes>false</OverwriteAttributes><Files>$inner</Files></File>")
        } else {
            $src = Escape-Xml $item.FullName
            $parts.Add("<File><Type>2</Type><Name>$name</Name><File>$src</File><ActiveX>false</ActiveX><ActiveXInstall>false</ActiveXInstall><Action>0</Action><OverwriteDateTime>false</OverwriteDateTime><OverwriteAttributes>false</OverwriteAttributes><PassCommandLine>false</PassCommandLine></File>")
        }
    }
    return ($parts -join "")
}

$entries = Get-ChildrenXml $ReleaseDir

# پنج کلید رجیستری پیش‌فرض — دقیقاً مطابق خروجی GUI
$defaultRegistries = "<Registry><Type>1</Type><Virtual>true</Virtual><Name>Classes</Name><ValueType>0</ValueType><Value/><Registries/></Registry>" +
    "<Registry><Type>1</Type><Virtual>true</Virtual><Name>User</Name><ValueType>0</ValueType><Value/><Registries/></Registry>" +
    "<Registry><Type>1</Type><Virtual>true</Virtual><Name>Machine</Name><ValueType>0</ValueType><Value/><Registries/></Registry>" +
    "<Registry><Type>1</Type><Virtual>true</Virtual><Name>Users</Name><ValueType>0</ValueType><Value/><Registries/></Registry>" +
    "<Registry><Type>1</Type><Virtual>true</Virtual><Name>Config</Name><ValueType>0</ValueType><Value/><Registries/></Registry>"

$project = @"
<?xml encoding="utf-16"?>
<>
<InputFile>$([System.Security.SecurityElement]::Escape($inputExe))</InputFile>
<OutputFile>$([System.Security.SecurityElement]::Escape($asciiOutput))</OutputFile>
<Files>
<Enabled>true</Enabled>
<DeleteExtractedOnExit>true</DeleteExtractedOnExit>
<CompressFiles>true</CompressFiles>
<Files>
<File>
<Type>3</Type>
<Name>%DEFAULT FOLDER%</Name>
<Action>0</Action>
<OverwriteDateTime>false</OverwriteDateTime>
<OverwriteAttributes>false</OverwriteAttributes>
<Files>$entries</Files>
</File>
</Files>
</Files>
<Registries>
<Enabled>false</Enabled>
<Registries>$defaultRegistries</Registries>
</Registries>
<Packaging>
<Enabled>false</Enabled>
</Packaging>
<Options>
<ShareVirtualSystem>false</ShareVirtualSystem>
<MapExecutableWithTemporaryFile>true</MapExecutableWithTemporaryFile>
<AllowRunningOfVirtualExeFiles>true</AllowRunningOfVirtualExeFiles>
</Options>
</>
"@

# --- 4) نوشتن پروژه (UTF-16 با BOM، همان‌طور که GUI می‌نویسد) ---
$projectPath = Join-Path ([System.IO.Path]::GetTempPath()) "darooyar.evb"
[System.IO.File]::WriteAllText($projectPath, $project, [System.Text.Encoding]::Unicode)
Write-Host "پروژه: $projectPath"

# --- 5) پردازش با کنسول Enigma ---
if (Test-Path $asciiOutput) { Remove-Item -Force $asciiOutput }
& $EvbConsole $projectPath
if ($LASTEXITCODE -ne 0) {
    throw "Enigma Virtual Box با کد $LASTEXITCODE خارج شد."
}
if (-not (Test-Path $asciiOutput)) {
    throw "خروجی ساخته نشد: $asciiOutput"
}

# کپی خروجی به مقصد نهایی (مسیر فارسی توسط خود Enigma ساخته نمی‌شود)
Copy-Item -Force -Path $asciiOutput -Destination $outputExeFull
Remove-Item -Force $asciiOutput

$outSize = (Get-Item $outputExeFull).Length
$inSize = (Get-Item $inputExe).Length
if ($outSize -le $inSize) {
    throw "خروجی ($outSize بایت) از ورودی ($inSize بایت) بزرگ‌تر نیست؛ بسته‌بندی ناموفق است."
}

Write-Host ("بسته‌بندی موفق: {0} ({1:N1} MB) — ورودی: {2:N1} MB" -f `
    $outputExeFull, ($outSize / 1MB), ($inSize / 1MB))
