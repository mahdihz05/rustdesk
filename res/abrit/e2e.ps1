param(
    [Parameter(Mandatory=$true)][ValidateSet('Initialize','StartReceiver','ReceiverAgent','Exercise','Cleanup')][string]$Phase,
    [Parameter(Mandatory=$true)][ValidateSet('receiver','sender')][string]$Role
)
. "$PSScriptRoot/e2e-common.ps1"
Assert-E2ERunner
$root = Join-Path $env:RUNNER_TEMP 'abrit-e2e'
$private = Join-Path $root 'private'
$evidence = Join-Path $root 'evidence'
$control = Join-Path $root 'control'
$exe = Join-Path $env:GITHUB_WORKSPACE 'existing-build/AbritDesk.exe'
$installed = Join-Path $env:ProgramFiles 'AbritDesk/AbritDesk.exe'
$attempt = "$env:GITHUB_RUN_ID-$env:GITHUB_RUN_ATTEMPT"
$expectedDomain = 'serverdesk.abrit.cloud'
$expectedKey = 'XDQrtTIvt+ISB6Zp8iqpjNpwmjRmkfpLHilOsBmrZHM='

if ($Phase -eq 'Initialize') {
    if (Test-Path -LiteralPath $root) { throw 'Test directory already exists.' }
    foreach ($dir in @($root,$private,$evidence,$control,"$root/public")) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath (Split-Path $installed))) { throw 'Existing AbritDesk installation; refusing to modify it.' }
    if (-not (Test-Path -LiteralPath $exe)) { throw 'Expected complete native build bundle missing.' }
    Write-E2EJson ([ordered]@{
        role=$Role; computer=$env:COMPUTERNAME; run=$env:GITHUB_RUN_ID; attempt=$env:GITHUB_RUN_ATTEMPT
        source_run=$env:E2E_BUILD_RUN; source_sha=$env:E2E_BUILD_SHA
        executable_sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
        native_library_sha256=(Get-FileHash -LiteralPath (Join-Path (Split-Path $exe) 'librustdesk.dll') -Algorithm SHA256).Hash
        observed_utc=[DateTime]::UtcNow.ToString('o')
    }) "$evidence/provenance.json"
    if ($Role -eq 'sender') {
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider(3072)
        $rsa.PersistKeyInCsp = $false
        try {
            $rsa.ToXmlString($true) | Set-Content -LiteralPath "$private/key.xml"
            Write-E2EJson @{ run=$attempt; public_key=$rsa.ToXmlString($false); input_marker="INPUT_$([Guid]::NewGuid().ToString('N'))"; computer=$env:COMPUTERNAME } "$root/public/public.json"
        } finally { $rsa.Dispose() }
    }
    return
}

if ($Phase -eq 'StartReceiver') {
    # Start-Process, not Start-Job: the monitor must outlive this Actions step.
    $p = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Phase ReceiverAgent -Role receiver" -PassThru -WindowStyle Hidden -RedirectStandardOutput "$private/agent.stdout" -RedirectStandardError "$private/agent.stderr"
    $p.Id | Set-Content "$private/agent.pid"
    $deadline = [DateTime]::UtcNow.AddMinutes(11)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path "$private/control-ready") { return }
        if ($p.HasExited) { throw 'Receiver agent failed before control was ready; private logs suppressed.' }
        Start-Sleep -Seconds 2
    }
    throw 'Receiver control preparation timed out.'
}

if ($Phase -eq 'Cleanup') {
    if (-not (Test-Path $private)) { return }
    # Never infer ownership merely from an existing service. Marker predates install.
    foreach ($pidFile in @('agent.pid','notepad.pid','ui.pid')) {
        if (Test-Path "$private/$pidFile") {
            $ownedPid = [int](Get-Content "$private/$pidFile" -Raw)
            Stop-Process -Id $ownedPid -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path "$private/install-owned") {
        $service = Get-CimInstance Win32_Service -Filter "Name='AbritDesk'"
        if ($service -and $service.PathName -ine ('"' + $installed + '" --service')) { throw 'Service path changed; refusing cleanup.' }
        if (Test-Path $installed) {
            # Native uninstall may terminate its own caller, so check its effects.
            $p = Start-Process $installed -ArgumentList '--uninstall' -PassThru -WindowStyle Hidden -RedirectStandardOutput "$private/uninstall.stdout" -RedirectStandardError "$private/uninstall.stderr"
            $null = $p.WaitForExit(60000)
            $deadline = [DateTime]::UtcNow.AddSeconds(45)
            while (((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path $installed)) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Seconds 1 }
        }
        if ((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path $installed)) { throw 'Owned service or executable remains after cleanup.' }
    }
    Remove-Item -LiteralPath $private -Recurse -Force
    Write-E2EJson @{ status='PASS'; scope='owned test processes and installation only' } "$evidence/cleanup.json"
    return
}

Initialize-E2ENative
$result = [ordered]@{
    role=$Role; computer=$env:COMPUTERNAME; run=$attempt
    registration='NOT_RUN'; connection='NOT_PROVEN'; display='NOT_PROVEN'; input='NOT_PROVEN'
    forced_relay='NOT_PROVEN'; network_recovery='SKIP'; network_recovery_reason='No safe two-runner recovery orchestration in this acceptance.'
    status='FAIL'; stage='start'; observed_utc=[DateTime]::UtcNow.ToString('o')
}
try {
    if ($Phase -eq 'ReceiverAgent') {
        $result.stage='wait_sender_public_key'
        Wait-E2EArtifact "e2e-public-key-$env:GITHUB_RUN_ATTEMPT" "$private/public-key"
        $pub = Get-Content "$private/public-key/public.json" -Raw | ConvertFrom-Json
        if ($pub.run -cne $attempt -or $pub.computer -ceq $env:COMPUTERNAME -or $pub.input_marker -notmatch '^INPUT_[a-f0-9]{32}$') { throw 'Invalid sender control or not two independent machines.' }
        if ((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path (Split-Path $installed))) { throw 'Receiver install preflight changed.' }
        $result.stage='receiver_native_install'
        'owned' | Set-Content "$private/install-owned"
        Invoke-E2EApp $exe '--silent-install printer=0' $private
        $service = Get-CimInstance Win32_Service -Filter "Name='AbritDesk'"
        if (-not $service -or $service.PathName -ine ('"' + $installed + '" --service') -or $service.StartName -ne 'LocalSystem') { throw 'Native installation identity mismatch.' }
        (Get-Service AbritDesk).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        $result.stage='receiver_registration'
        & "$PSScriptRoot/test_connection_windows.ps1" -Executable $installed -Output "$evidence/registration" -ExpectedDomain $expectedDomain -ExpectedKey $expectedKey
        $reg = Get-Content "$evidence/registration/Registration.json" -Raw | ConvertFrom-Json
        $result.registration = 'PASS'
        $bytes = New-Object byte[] 32
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        $password = [BitConverter]::ToString($bytes).Replace('-','')
        $result.stage='receiver_authorization'
        Invoke-E2EApp $installed "--password $password" $private
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
        $rsa.PersistKeyInCsp = $false
        try {
            $rsa.FromXmlString($pub.public_key)
            $cipher = [Convert]::ToBase64String($rsa.Encrypt([Text.Encoding]::UTF8.GetBytes($password), $true))
        } finally { $rsa.Dispose(); $password=$null; [Array]::Clear($bytes,0,$bytes.Length) }
        $result.stage='receiver_safe_screen'
        $notepad = Start-Process "$env:windir/System32/notepad.exe" -PassThru
        $notepad.Id | Set-Content "$private/notepad.pid"
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        do { $notepad.Refresh(); $hwnd=$notepad.MainWindowHandle; Start-Sleep -Milliseconds 250 } while ($hwnd -eq 0 -and [DateTime]::UtcNow -lt $deadline)
        $edit = [E2ENative]::FindWindowEx($hwnd,[IntPtr]::Zero,'Edit',$null)
        if ($edit -eq [IntPtr]::Zero) { throw 'Classic Notepad EDIT control unavailable.' }
        $visual = "DISPLAY_$([Guid]::NewGuid().ToString('N'))"
        # Repeat only the safe visual challenge, never the sender's input marker.
        # Its lower lines remain visible when native-scale view clips the top edge.
        $safeText = (@($visual) * 12) -join "`r`n"
        $null = [E2ENative]::SendMessage($edit,0x000C,[IntPtr]::Zero,$safeText)
        $null = [E2ENative]::ShowWindow($hwnd,3)
        $null = [E2ENative]::SetForegroundWindow($hwnd)
        Start-Sleep -Seconds 2
        if ([E2ENative]::GetForegroundWindow() -ne $hwnd) { throw 'Receiver Notepad is not foreground.' }
        Save-E2EScreen "$evidence/receiver-before-input.png" $hwnd
        # Capture a safe text strip away from the remote viewport's top edge.
        $origin = New-Object E2ENative+Point
        $null = [E2ENative]::ClientToScreen($edit,[ref]$origin)
        $bitmap = New-Object Drawing.Bitmap(350,24)
        $g = [Drawing.Graphics]::FromImage($bitmap)
        try { $g.CopyFromScreen($origin.X,($origin.Y+96),0,0,$bitmap.Size); $bitmap.Save("$control/display-template.png") }
        finally { $g.Dispose(); $bitmap.Dispose() }
        Write-E2EJson @{ run=$attempt; id=$reg.id; password_ciphertext=$cipher; encryption='RSA-3072 OAEP-SHA1'; computer=$env:COMPUTERNAME; visual_marker=$visual } "$control/control.json"
        'ready' | Set-Content "$private/control-ready"
        $result.stage='receiver_observe_wm_gettext'
        $deadline = [DateTime]::UtcNow.AddMinutes(7)
        while ([DateTime]::UtcNow -lt $deadline) {
            $text = New-Object Text.StringBuilder(4096)
            $null = [E2ENative]::SendMessage($edit,0x000D,[IntPtr]4096,$text)
            if ($text.ToString().Contains($pub.input_marker)) {
                $result.connection='PASS'; $result.input='PASS'; $result.status='PASS'
                $result['input_marker']=$pub.input_marker; $result['visual_marker']=$visual
                $result['wm_gettext']=$text.ToString(); $result['sender_computer']=$pub.computer
                Save-E2EScreen "$evidence/receiver-notepad.png" $hwnd
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if ($result.status -ne 'PASS') { throw 'Receiver did not observe remote marker via WM_GETTEXT.' }
        $result.stage='complete_receiver_observation'
    } elseif ($Role -eq 'receiver') {
        $deadline = [DateTime]::UtcNow.AddMinutes(8)
        while (-not (Test-Path "$private/agent-done") -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Seconds 2 }
        if (-not (Test-Path "$private/agent-done")) { throw 'Receiver monitor did not finish.' }
        $agentResult = Get-Content "$evidence/result.json" -Raw | ConvertFrom-Json
        if ($agentResult.status -ne 'PASS') { throw 'Receiver observation failed.' }
        return
    } else {
        $result.stage='wait_receiver_ciphertext'
        Wait-E2EArtifact "e2e-receiver-control-$env:GITHUB_RUN_ATTEMPT" "$private/receiver-control"
        $coord = Get-Content "$private/receiver-control/control.json" -Raw | ConvertFrom-Json
        if ($coord.run -cne $attempt -or $coord.computer -ceq $env:COMPUTERNAME -or $coord.id -notmatch '^\d+$') { throw 'Invalid receiver coordination.' }
        $result.stage='sender_decrypt'
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
        $rsa.PersistKeyInCsp = $false
        try {
            $rsa.FromXmlString((Get-Content "$private/key.xml" -Raw))
            $password = [Text.Encoding]::UTF8.GetString($rsa.Decrypt([Convert]::FromBase64String($coord.password_ciphertext),$true))
        } finally { $rsa.Dispose() }
        if ($password -notmatch '^[A-F0-9]{64}$') { throw 'Invalid decrypted credential.' }
        Write-Host "::add-mask::$password"
        $pub = Get-Content "$root/public/public.json" -Raw | ConvertFrom-Json
        # Sender installation permits the existing diagnostic to attest its defaults.
        if ((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path (Split-Path $installed))) { throw 'Sender install preflight changed.' }
        $result.stage='sender_native_install'
        'owned' | Set-Content "$private/install-owned"
        Invoke-E2EApp $exe '--silent-install printer=0' $private
        (Get-Service AbritDesk).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        $result.stage='sender_registration'
        & "$PSScriptRoot/test_connection_windows.ps1" -Executable $installed -Output "$evidence/registration" -ExpectedDomain $expectedDomain -ExpectedKey $expectedKey
        $result.registration='PASS'
        # A new peer file on this disposable sender only; server/key defaults stay untouched.
        $peers = Join-Path $env:APPDATA 'AbritDesk/config/peers'
        New-Item -ItemType Directory -Path $peers -Force | Out-Null
        $peerFile = Join-Path $peers "$($coord.id).toml"
        if (Test-Path $peerFile) { throw 'Receiver peer config already exists; refusing overwrite.' }
        "view_style = 'original'`nimage_quality = 'best'" | Set-Content -LiteralPath $peerFile -Encoding ASCII
        $result.stage='sender_connect_and_display'
        $ui = Start-Process $installed -ArgumentList "--connect $($coord.id)/r --password $password" -PassThru -RedirectStandardOutput "$private/ui.stdout" -RedirectStandardError "$private/ui.stderr"
        $ui.Id | Set-Content "$private/ui.pid"
        $password=$null
        $template = New-Object Drawing.Bitmap("$private/receiver-control/display-template.png")
        $deadline = [DateTime]::UtcNow.AddMinutes(4)
        $session = [IntPtr]::Zero
        try {
            while ([DateTime]::UtcNow -lt $deadline) {
                $session = [E2ENative]::SessionWindow($coord.id)
                if ($session -ne [IntPtr]::Zero) {
                    $null = [E2ENative]::ShowWindow($session,3)
                    $null = [E2ENative]::SetForegroundWindow($session)
                    Start-Sleep -Seconds 2
                    if ([E2ENative]::GetForegroundWindow() -ne $session) { continue }
                    Save-E2EScreen "$private/sender-screen.png" $session
                    $screen = New-Object Drawing.Bitmap("$private/sender-screen.png")
                    try { $visible = [E2ENative]::ContainsTemplate($screen,$template) } finally { $screen.Dispose() }
                    if ($visible) { $result.display='PASS'; break }
                }
                Start-Sleep -Seconds 3
            }
        } finally { $template.Dispose() }
        if ($result.display -ne 'PASS') { throw 'Remote text pixels not observed at native scale in the sender session window.' }
        Copy-Item "$private/sender-screen.png" "$evidence/sender-display.png"
        $result.connection='PASS'
        $result['receiver_computer']=$coord.computer; $result['receiver_id']=$coord.id
        $result['visual_marker']=$coord.visual_marker; $result['input_marker']=$pub.input_marker
        $result['connect_argument']="$($coord.id)/r"
        $result.stage='sender_relay_endpoint'
        $relayAddresses = @([Net.Dns]::GetHostAddresses($expectedDomain) | ForEach-Object { $_.ToString() })
        $appPids = @(Get-Process AbritDesk -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
        $tcp = @(Get-NetTCPConnection -State Established | Where-Object { $_.OwningProcess -in $appPids -and $_.RemotePort -eq 21117 -and $_.RemoteAddress -in $relayAddresses } | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess)
        Write-E2EJson $tcp "$evidence/relay-tcp.json"
        if ($tcp.Count -eq 0) { throw 'No established AbritDesk TCP endpoint on expected relay port 21117; relay unproven.' }
        $result.forced_relay='PASS'
        if ([E2ENative]::GetForegroundWindow() -ne $session) { throw 'Sender session lost foreground before input.' }
        # Only native keyboard events enter the remote session; never paste a clipboard.
        $result.stage='sender_native_input'
        [Windows.Forms.SendKeys]::SendWait('^{END}')
        [Windows.Forms.SendKeys]::SendWait('{ENTER}' + $pub.input_marker)
        $result.input='SENT_NOT_YET_OBSERVED'
        Start-Sleep -Seconds 4
        Save-E2EScreen "$evidence/sender-after-input.png" $session
        # Receiver evidence is uploaded at job end; require its independent observation.
        $result.stage='sender_wait_independent_input_proof'
        Wait-E2EArtifact "e2e-receiver-evidence-$env:GITHUB_RUN_ATTEMPT" "$private/receiver-evidence"
        $receiver = Get-Content "$private/receiver-evidence/result.json" -Raw | ConvertFrom-Json
        if ($receiver.status -ne 'PASS' -or $receiver.input -ne 'PASS' -or $receiver.input_marker -cne $pub.input_marker -or $receiver.computer -cne $coord.computer) { throw 'Receiver did not independently confirm this input marker.' }
        $result.input='PASS'; $result.status='PASS'; $result.stage='complete'
    }
} catch {
    # Do not serialize exceptions/native logs: they can contain command credentials.
    $result['failure']='Acceptance failed; inspect sanitized stage fields. Private command output intentionally withheld.'
    throw 'Two-machine acceptance failed. See sanitized result.json; no credential-bearing output published.'
} finally {
    $result.observed_utc=[DateTime]::UtcNow.ToString('o')
    # The foreground receiver waiter must not overwrite its agent's evidence.
    if ($Phase -eq 'ReceiverAgent' -or $Role -eq 'sender' -or -not (Test-Path "$evidence/result.json")) {
        Write-E2EJson $result "$evidence/result.json"
    }
    if ($Phase -eq 'ReceiverAgent') { 'done' | Set-Content "$private/agent-done" }
}
