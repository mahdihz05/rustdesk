param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$Output,
    [string]$Installer,
    [string]$Portable,
    [switch]$LiveConnection
)
$ErrorActionPreference = 'Stop'
# Installation tests must never run against a developer's existing installation.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'This install/uninstall acceptance test is restricted to disposable GitHub-hosted runners.'
}
$exe = (Resolve-Path -LiteralPath $Executable).Path
$outputPath = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$installPath = Join-Path $env:ProgramFiles 'AbritDesk'
$installedExe = Join-Path $installPath 'AbritDesk.exe'
if ((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath $installPath)) {
    throw 'An AbritDesk installation already exists; refusing to replace it.'
}

function Invoke-App([string]$Path, [string]$Arguments, [string]$Label) {
    $stdout = Join-Path $outputPath "$Label.stdout.txt"
    $stderr = Join-Path $outputPath "$Label.stderr.txt"
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -WorkingDirectory (Split-Path $Path) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(60000)) {
        Stop-Process -Id $process.Id -Force
        throw "Application command timed out: $Arguments"
    }
    # Uninstall can terminate its calling process; assert its effects separately.
    return Get-Content -LiteralPath $stdout -Raw
}

function Get-StockSnapshot {
    $service = Get-CimInstance Win32_Service -Filter "Name='RustDesk'"
    $files = [ordered]@{}
    foreach ($root in @(
        "$env:APPDATA\RustDesk", "$env:LOCALAPPDATA\rustdesk", "$env:ProgramFiles\RustDesk",
        "$env:windir\ServiceProfiles\LocalService\AppData\Roaming\RustDesk",
        "$env:windir\System32\config\systemprofile\AppData\Roaming\RustDesk"
    )) {
        if (Test-Path -LiteralPath $root) {
            foreach ($file in (Get-ChildItem -LiteralPath $root -File -Recurse | Sort-Object FullName)) {
                $files[$file.FullName] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
            }
        }
    }
    $registry = [ordered]@{}
    foreach ($key in @(
        'HKLM\Software\RustDesk',
        'HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk',
        'HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk',
        'HKLM\Software\Classes\rustdesk', 'HKCU\Software\RustDesk', 'HKCU\Software\Classes\rustdesk'
    )) {
        $value = & reg.exe query $key /s 2>$null
        $registry[$key] = if ($LASTEXITCODE -eq 0) { $value -join "`n" } else { $null }
    }
    [ordered]@{
        service = if ($service) { [ordered]@{
            name=$service.Name; display=$service.DisplayName; binary=$service.PathName
            account=$service.StartName; start=$service.StartMode; state=$service.State
        }} else { $null }
        files=$files; registry=$registry
    } | ConvertTo-Json -Depth 8 -Compress
}

function Assert-StockUnchanged([string]$Stage) {
    if ((Get-StockSnapshot) -cne $script:stockBefore) {
        Get-StockSnapshot | Set-Content (Join-Path $outputPath "stock-after-$Stage.json")
        throw "RustDesk service, files or registry changed during $Stage"
    }
}

function Assert-InstalledService([switch]$Msi) {
    $service = Get-CimInstance Win32_Service -Filter "Name='AbritDesk'"
    if (-not $service -or $service.DisplayName -cne 'AbritDesk Service' -or
        $service.PathName -ine ('"' + $installedExe + '" --service') -or
        $service.StartName -ne 'LocalSystem') {
        throw 'AbritDesk SCM identity or executable association is incorrect.'
    }
    if (-not (Test-Path -LiteralPath $installedExe)) { throw 'AbritDesk.exe was not installed.' }
    if (-not $Msi -and (Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\AbritDesk').InstallLocation.TrimEnd('\') -ine $installPath) {
        throw 'AbritDesk uninstall registration points to the wrong installation.'
    }
    $protocol = (Get-Item 'Registry::HKEY_CLASSES_ROOT\abritdesk\shell\open\command').GetValue('')
    if ($protocol -notlike "*$installedExe*") { throw 'AbritDesk URI registration points to the wrong executable.' }
}

function Invoke-Msi([string]$Arguments, [string]$Label) {
    $log = Join-Path $outputPath "$Label.log"
    $process = Start-Process msiexec.exe -ArgumentList "$Arguments /qn /norestart /l*v `"$log`"" -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(120000)) { throw "MSI operation timed out: $Label" }
    if ($process.ExitCode -notin @(0, 3010)) { throw "MSI operation failed: $Label ($($process.ExitCode)); see $log" }
}

function Get-MsiProperty($Database, [string]$Name) {
    $view = $Database.OpenView("SELECT Value FROM Property WHERE Property='$Name'")
    $null = $view.Execute()
    $record = $view.Fetch()
    if (-not $record) { throw "Missing MSI property: $Name" }
    $value = $record.StringData(1)
    $null = $view.Close()
    return $value
}

function Assert-LiveConnection([string]$Path, [string]$Stage, [switch]$Standalone, [string]$Baseline) {
    $parameters = @{
        Executable = $Path
        Output = (Join-Path $outputPath $Stage)
        ExpectedDomain = 'serverdesk.abrit.cloud'
        ExpectedKey = 'XDQrtTIvt+ISB6Zp8iqpjNpwmjRmkfpLHilOsBmrZHM='
        StartServer = $Standalone
    }
    if ($Baseline) { $parameters.Phase = 'Restart'; $parameters.Baseline = $Baseline }
    & "$PSScriptRoot/test_connection_windows.ps1" @parameters
}

$sentinelCreated = $false
try {
    if ($Portable) {
        $resource = (Get-Item -LiteralPath $Portable).VersionInfo
        if ($resource.ProductName -cne 'abritdesk' -or
            $resource.FileDescription -cne 'abritdesk Remote Desktop' -or
            $resource.OriginalFilename -cne 'AbritDesk.exe' -or $resource.CompanyName -cne 'Abrit') {
            throw 'Portable EXE metadata still uses an incorrect brand.'
        }
    }
    # A stopped stock-named sentinel catches the original rename/reconfigure/delete bug.
    # It is not a real RustDesk binary and does not prove two active remote sessions.
    if (-not (Get-Service RustDesk -ErrorAction SilentlyContinue)) {
        & sc.exe create RustDesk binPath= "$env:windir\System32\cmd.exe" start= demand DisplayName= 'RustDesk Service'
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the isolated RustDesk service sentinel.' }
        $sentinelCreated = $true
    }
    $script:stockBefore = Get-StockSnapshot
    $script:stockBefore | Set-Content (Join-Path $outputPath 'stock-before.json')
    $identity = Invoke-App $exe '--identity-json' 'identity' | ConvertFrom-Json
    if ($identity.app_name -cne 'AbritDesk' -or $identity.service_name -cne 'AbritDesk' -or
        $identity.service_display_name -cne 'AbritDesk Service' -or
        $identity.service_executable -ine $installedExe -or
        $identity.ipc -ine '\\.\pipe\AbritDesk\query' -or
        $identity.service_ipc -ine '\\.\pipe\AbritDesk\query_service' -or
        $identity.uri_prefix -cne 'abritdesk://' -or
        $identity.window_class -cne 'ABRITDESK_FLUTTER_RUNNER_WIN32_WINDOW' -or
        $identity.tray_mutex -cne 'Local\AbritDesk_tray' -or
        $identity.broker -cne 'RuntimeBroker_abritdesk.exe' -or
        $identity.config_file -notlike "$env:APPDATA\AbritDesk\config\AbritDesk.toml") {
        throw 'The compiled native identity is not independent from RustDesk.'
    }
    if ($LiveConnection) {
        Assert-LiveConnection $exe 'portable-registration' -Standalone
        Assert-LiveConnection $exe 'portable-restart' -Standalone -Baseline (Join-Path $outputPath 'portable-registration/Registration.json')
    }
    & "$PSScriptRoot/smoke_windows.ps1" -Executable $exe -Output $outputPath
    Assert-StockUnchanged 'portable'
    Invoke-App $exe '--silent-install printer=0' 'install' | Out-Null
    Assert-InstalledService
    $service = Get-Service AbritDesk
    $service.WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
    if ($LiveConnection) { Assert-LiveConnection $installedExe 'installed-registration' }
    if ($LiveConnection) {
        $installedStatus = Invoke-App $installedExe '--connection-status-json' 'installed-before-coexistence' | ConvertFrom-Json
        $serviceConfig = "$env:windir\ServiceProfiles\LocalService\AppData\Roaming\AbritDesk\config\AbritDesk.toml"
        $serviceHash = (Get-FileHash -LiteralPath $serviceConfig -Algorithm SHA256).Hash
        $portableIdentity = Invoke-App $exe '--identity-json' 'portable-coexistence-identity' | ConvertFrom-Json
        if ($portableIdentity.app_name -cne 'AbritDesk' -or $portableIdentity.uri_prefix -cne 'abritdesk://' -or
            $portableIdentity.ipc -notlike '\\.\pipe\AbritDesk-Portable-*\query' -or
            $portableIdentity.config_file -like "$env:APPDATA\AbritDesk\config\*" -or
            $portableIdentity.window_class -eq $identity.window_class -or
            $portableIdentity.tray_mutex -eq $identity.tray_mutex) {
            throw 'Portable runtime does not isolate IPC, configuration, window class and tray while preserving the visible identity.'
        }
        Assert-LiveConnection $exe 'portable-coexistence' -Standalone
        Assert-LiveConnection $exe 'portable-coexistence-restart' -Standalone -Baseline (Join-Path $outputPath 'portable-coexistence/Registration.json')
        $installedAfter = Invoke-App $installedExe '--connection-status-json' 'installed-after-coexistence' | ConvertFrom-Json
        if ($installedAfter.ipc_ok -ne $true -or $installedAfter.id -cne $installedStatus.id -or
            $installedAfter.temporary_password_ready -ne $true -or
            (Get-FileHash -LiteralPath $serviceConfig -Algorithm SHA256).Hash -cne $serviceHash) {
            throw 'Portable execution changed the installed identity/key configuration or broke its IPC/password.'
        }
        Assert-StockUnchanged 'portable-coexistence'
    }
    Assert-StockUnchanged 'install'
    Stop-Service AbritDesk
    (Get-Service AbritDesk).WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    Assert-StockUnchanged 'stop'
    Start-Service AbritDesk
    (Get-Service AbritDesk).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
    if ($LiveConnection) {
        Assert-LiveConnection $installedExe 'installed-restart' -Baseline (Join-Path $outputPath 'installed-registration/Registration.json')
    }
    Assert-StockUnchanged 'start'
    Invoke-App $installedExe '--uninstall' 'uninstall' | Out-Null
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    # The uninstall command kills its caller before the elevated batch removes files.
    while (((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or
            (Test-Path -LiteralPath $installedExe)) -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 500
    }
    if (Get-Service AbritDesk -ErrorAction SilentlyContinue) { throw 'AbritDesk service remains after uninstall.' }
    if (Test-Path -LiteralPath $installedExe) { throw 'AbritDesk executable remains after uninstall.' }
    Assert-StockUnchanged 'uninstall'
    if ($Installer) {
        $msiPath = (Resolve-Path -LiteralPath $Installer).Path
        $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
        $database = $windowsInstaller.OpenDatabase($msiPath, 0)
        $productName = Get-MsiProperty $database 'ProductName'
        $manufacturer = Get-MsiProperty $database 'Manufacturer'
        "MSI ProductName='$productName'; Manufacturer='$manufacturer'" |
            Tee-Object -FilePath (Join-Path $outputPath 'msi-properties.txt') | Write-Host
        if ($productName -cne 'abritdesk' -or $manufacturer -cne 'Abrit') {
            throw "MSI product name or manufacturer is incorrect: ProductName='$productName'; Manufacturer='$manufacturer'."
        }
        $productCode = Get-MsiProperty $database 'ProductCode'
        $database = $null
        Invoke-Msi "/i `"$msiPath`" PRINTER=0 LAUNCH_TRAY_APP=0" 'msi-install'
        Assert-InstalledService -Msi
        (Get-Service AbritDesk).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        if ($LiveConnection) { Assert-LiveConnection $installedExe 'msi-registration' }
        Assert-StockUnchanged 'msi-install'
        Stop-Service AbritDesk
        (Get-Service AbritDesk).WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
        Assert-StockUnchanged 'msi-stop'
        Start-Service AbritDesk
        (Get-Service AbritDesk).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        if ($LiveConnection) {
            Assert-LiveConnection $installedExe 'msi-restart' -Baseline (Join-Path $outputPath 'msi-registration/Registration.json')
        }
        Assert-StockUnchanged 'msi-start'
        Invoke-Msi "/x $productCode" 'msi-uninstall'
        if (Get-Service AbritDesk -ErrorAction SilentlyContinue) { throw 'MSI uninstall left the AbritDesk service.' }
        if (Test-Path -LiteralPath $installedExe) { throw 'MSI uninstall left the AbritDesk executable.' }
        Assert-StockUnchanged 'msi-uninstall'
    }
    'PASS: native identity, portable UI, install, service stop/start and uninstall leave RustDesk unchanged.' |
        Set-Content (Join-Path $outputPath 'identity-acceptance.txt')
} finally {
    if ($sentinelCreated) { & sc.exe delete RustDesk | Out-Null }
}
