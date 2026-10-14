param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$Output,
    [Parameter(Mandatory=$true)][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][string]$ExpectedKey,
    [string]$ExpectedRelay,
    [switch]$StartServer,
    [ValidateSet('Registration', 'Restart', 'Reboot', 'OfflineRestart', 'OfflineReboot')]
    [string]$Phase = 'Registration',
    [string]$Baseline,
    [ValidateRange(10, 600)][int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Network/reboot orchestration belongs to the caller on a disposable runner.
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Connection acceptance is restricted to disposable GitHub-hosted runners.'
}
if ([string]::IsNullOrWhiteSpace($ExpectedDomain) -or [string]::IsNullOrWhiteSpace($ExpectedKey)) {
    throw 'Expected domain and public server key must be nonempty.'
}
if (-not $ExpectedRelay) { $ExpectedRelay = $ExpectedDomain }
$exe = (Resolve-Path -LiteralPath $Executable).Path
$outputPath = [IO.Path]::GetFullPath($Output)
$bootUtc = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
$baselineId = $null
if ($Phase -ne 'Registration' -and -not $Baseline) {
    throw 'Restart/reboot evidence requires a prior successful registration JSON baseline.'
}
if ($Baseline) {
    $prior = Get-Content -LiteralPath $Baseline -Raw | ConvertFrom-Json
    if ($prior.ipc_ok -ne $true -or $prior.latency -le 0 -or $prior.key_confirmed -ne $true -or
        [string]::IsNullOrWhiteSpace($prior.id) -or $prior.server -cne $ExpectedDomain -or
        $prior.relay -cne $ExpectedRelay -or $prior.key -cne $ExpectedKey) {
        throw 'Baseline is not successful registration evidence for the expected server.'
    }
    $baselineId = $prior.id
    if ($Phase -in @('Reboot', 'OfflineReboot') -and
        ($prior.computer_name -cne $env:COMPUTERNAME -or
         [DateTime]::Parse($prior.boot_utc).ToUniversalTime() -ge [DateTime]::Parse($bootUtc).ToUniversalTime() -or
         [DateTime]::Parse($prior.observed_utc).ToUniversalTime() -ge [DateTime]::Parse($bootUtc).ToUniversalTime())) {
        throw 'Reboot evidence requires a later Windows boot on the same runner than the baseline observation.'
    }
}
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$offline = $Phase.StartsWith('Offline')
$ownedServer = $null
$probe = $null
$stdout = Join-Path $outputPath "$Phase.probe.stdout.txt"
$stderr = Join-Path $outputPath "$Phase.probe.stderr.txt"
$evidence = Join-Path $outputPath "$Phase.json"
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
try {
    if ($StartServer) {
        # Never attach ownership to an existing listener or stop an installed service.
        $identity = Start-Process -FilePath $exe -ArgumentList '--connection-status-json' -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $probe = $identity
        if (-not $probe.WaitForExit(10000)) { throw 'Preflight diagnostic timed out.' }
        $preflight = Get-Content -LiteralPath $stdout -Raw | ConvertFrom-Json
        if ($preflight.ipc_ok -ne $false -or $preflight.error -cne 'ipc_connect_failed') {
            throw 'An IPC listener exists or its absence cannot be verified; refusing to start a second server.'
        }
        $ownedServer = Start-Process -FilePath $exe -ArgumentList '--server' -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden -PassThru
    }
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($ownedServer -and $ownedServer.HasExited) { throw 'Owned standalone server exited before acceptance.' }
        $probe = Start-Process -FilePath $exe -ArgumentList '--connection-status-json' -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $remaining = [int][Math]::Max(1, [Math]::Min(10000, ($deadline - [DateTime]::UtcNow).TotalMilliseconds))
        if (-not $probe.WaitForExit($remaining)) { throw 'Connection diagnostic timed out.' }
        if ($probe.ExitCode -ne 0) { throw "Connection diagnostic exited with code $($probe.ExitCode)." }
        $snapshot = Get-Content -LiteralPath $stdout -Raw | ConvertFrom-Json
        # Save only the diagnostic allowlist, never passwords, config dumps or logs.
        $safe = [ordered]@{
            ipc_ok = $snapshot.ipc_ok; latency = $snapshot.latency
            key_confirmed = $snapshot.key_confirmed; id = $snapshot.id
            temporary_password_ready = $snapshot.temporary_password_ready
            server = $snapshot.server; relay = $snapshot.relay; key = $snapshot.key
            error = $snapshot.error; phase = $Phase; observed_utc = [DateTime]::UtcNow.ToString('o')
            baseline_id = $baselineId; boot_utc = $bootUtc; computer_name = $env:COMPUTERNAME
        }
        $safe | ConvertTo-Json | Set-Content -LiteralPath $evidence -Encoding UTF8
        $configurationOk = $snapshot.server -ceq $ExpectedDomain -and $snapshot.relay -ceq $ExpectedRelay -and $snapshot.key -ceq $ExpectedKey
        $identityOk = -not [string]::IsNullOrWhiteSpace($snapshot.id) -and (-not $baselineId -or $snapshot.id -ceq $baselineId)
        $stateOk = if ($offline) { $null -ne $snapshot.latency -and $snapshot.latency -le 0 } else { $snapshot.latency -gt 0 -and $snapshot.key_confirmed -eq $true }
        if ($snapshot.ipc_ok -eq $true -and $snapshot.temporary_password_ready -eq $true -and $configurationOk -and $identityOk -and $stateOk) {
            $label = if ($offline) { 'offline ID stability' } else { 'live server registration' }
            "PASS: $label ($Phase). This does not prove a remote desktop session. Evidence: $evidence"
            return
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Acceptance timed out for $Phase; last diagnostic: $evidence"
} finally {
    # These Process objects are exclusively children started by this invocation.
    foreach ($process in @($probe, $ownedServer)) {
        if ($process -and -not $process.HasExited) { $process.Kill(); $null = $process.WaitForExit(10000) }
    }
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
}
