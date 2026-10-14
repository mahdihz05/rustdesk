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
$machineId = (Get-CimInstance Win32_ComputerSystemProduct).UUID
if (-not $machineId -or $machineId -eq '00000000-0000-0000-0000-000000000000') { throw 'VM hardware identity unavailable.' }

if ($Phase -eq 'Initialize') {
    if (Test-Path -LiteralPath $root) { throw 'Test directory already exists.' }
    foreach ($dir in @($root,$private,$evidence,$control,"$root/public")) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path -LiteralPath (Split-Path $installed))) { throw 'Existing AbritDesk installation; refusing to modify it.' }
    if (-not (Test-Path -LiteralPath $exe)) { throw 'Expected complete native build bundle missing.' }
    Write-E2EJson ([ordered]@{
        role=$Role; computer=$env:COMPUTERNAME; machine_id=$machineId; run=$env:GITHUB_RUN_ID; attempt=$env:GITHUB_RUN_ATTEMPT
        source_run=$env:E2E_BUILD_RUN; source_sha=$env:E2E_BUILD_SHA
        executable_sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
        native_library_sha256=(Get-FileHash -LiteralPath (Join-Path (Split-Path $exe) 'librustdesk.dll') -Algorithm SHA256).Hash
        observed_utc=[DateTime]::UtcNow.ToString('o')
        server_addresses=@([Net.Dns]::GetHostAddresses($expectedDomain) | ForEach-Object { $_.ToString() })
        local_addresses=@(Get-NetIPAddress | Select-Object IPAddress,AddressFamily,InterfaceAlias)
    }) "$evidence/provenance.json"
    if ($Role -eq 'sender') {
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider(3072)
        $rsa.PersistKeyInCsp = $false
        try {
            $rsa.ToXmlString($true) | Set-Content -LiteralPath "$private/key.xml"
            Write-E2EJson @{ run=$attempt; public_key=$rsa.ToXmlString($false); input_marker="INPUT_$([Guid]::NewGuid().ToString('N'))"; computer=$env:COMPUTERNAME; machine_id=$machineId } "$root/public/public.json"
        } finally { $rsa.Dispose() }
    }
    return
}

if ($Phase -eq 'StartReceiver') {
    # CMD owns real log file handles. Parent PowerShell redirection uses managed
    # pipes whose callbacks disappear when this Actions step exits.
    $p = Start-E2EFileLoggedProcess $PSCommandPath '-Phase ReceiverAgent -Role receiver' $private
    Write-E2EJson @{ pid=$p.Id; started_utc=$p.StartTime.ToUniversalTime().ToString('o') } "$private/cmd-owner.json"
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
    if (Test-Path "$private/cmd-owner.json") {
        $owner=Get-Content "$private/cmd-owner.json" -Raw | ConvertFrom-Json
        $owned=Get-Process -Id $owner.pid -ErrorAction SilentlyContinue
        if ($owned -and $owned.StartTime.ToUniversalTime().ToString('o') -ceq $owner.started_utc) {
            & taskkill.exe /PID $owner.pid /T /F *> $null
        }
    }
    # Never infer ownership merely from an existing service. Marker predates install.
    foreach ($pidFile in @('notepad.pid','ui.pid')) {
        if ((Test-Path "$private/$pidFile") -and (Test-Path "$private/$pidFile.started")) {
            $ownedPid = [int](Get-Content "$private/$pidFile" -Raw)
            $owned=Get-Process -Id $ownedPid -ErrorAction SilentlyContinue
            $started=(Get-Content "$private/$pidFile.started" -Raw).Trim()
            if ($owned -and $owned.StartTime.ToUniversalTime().ToString('o') -ceq $started) { Stop-Process -Id $ownedPid -Force -ErrorAction SilentlyContinue }
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
    role=$Role; computer=$env:COMPUTERNAME; machine_id=$machineId; run=$attempt
    registration='NOT_RUN'; connection='NOT_PROVEN'; display='NOT_PROVEN'; input='NOT_PROVEN'
    forced_relay='NOT_PROVEN'; network_recovery='SKIP'; network_recovery_reason='No safe two-runner recovery orchestration in this acceptance.'
    status='FAIL'; failure_class='HARNESSERROR'; stage='start'; observed_utc=[DateTime]::UtcNow.ToString('o')
}
try {
    if ($Phase -eq 'ReceiverAgent') {
        $agentStarted=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
        Write-E2EJson @{ agent_pid=$PID; agent_started_utc=$agentStarted; observed_utc=[DateTime]::UtcNow.ToString('o'); stage='starting' } "$evidence/receiver-heartbeat.json"
        $result.stage='wait_sender_public_key'
        Wait-E2EArtifact "e2e-public-key-$env:GITHUB_RUN_ATTEMPT" "$private/public-key"
        $pub = Get-Content "$private/public-key/public.json" -Raw | ConvertFrom-Json
        # Hosted Windows images can share a hostname; compare VM hardware UUIDs.
        if ($pub.run -cne $attempt -or -not $pub.machine_id -or $pub.machine_id -ceq $machineId -or $pub.input_marker -notmatch '^INPUT_[a-f0-9]{32}$') { throw 'Invalid sender control or not two independent machines.' }
        if ((Get-Service AbritDesk -ErrorAction SilentlyContinue) -or (Test-Path (Split-Path $installed))) { throw 'Receiver install preflight changed.' }
        $result.stage='receiver_native_install'
        'owned' | Set-Content "$private/install-owned"
        # The installer terminates AbritDesk processes, including its caller.
        # Validate the resulting service/path and live registration instead.
        Invoke-E2EApp $exe '--silent-install printer=0' $private -AllowInstallerTermination
        $service = Get-CimInstance Win32_Service -Filter "Name='AbritDesk'"
        if (-not $service -or $service.PathName -ine ('"' + $installed + '" --service') -or $service.StartName -ne 'LocalSystem') { throw 'Native installation identity mismatch.' }
        (Get-Service AbritDesk).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        $result.stage='receiver_registration'
        Invoke-E2ERegistration $installed $private "$evidence/registration" $expectedDomain $expectedKey
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
        $notepad.StartTime.ToUniversalTime().ToString('o') | Set-Content "$private/notepad.pid.started"
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
        function Save-ReceiverHeartbeat {
            $result['receiver_valid']=$false
            $snapshot=Get-E2ERegistrationSnapshot $installed $private
            $liveService=Get-CimInstance Win32_Service -Filter "Name='AbritDesk'"
            $serviceAlive=$false
            if ($liveService -and $liveService.State -eq 'Running' -and $liveService.ProcessId -gt 0) {
                $serviceAlive=$null -ne (Get-Process -Id $liveService.ProcessId -ErrorAction SilentlyContinue)
            }
            $notepadAlive=-not $notepad.HasExited -and [E2ENative]::IsWindow($edit)
            $valid=(Test-E2ERegistration $snapshot $expectedDomain $expectedKey) -and $snapshot.id -ceq $reg.id -and $serviceAlive -and $notepadAlive
            $heartbeat=[ordered]@{
                run=$attempt; machine_id=$machineId; agent_pid=$PID; agent_started_utc=$agentStarted
                observed_utc=[DateTime]::UtcNow.ToString('o'); stage=$result.stage; receiver_valid=$valid
                registration=$snapshot; service_alive=$serviceAlive
                service_pid=if($liveService){$liveService.ProcessId}else{0}
                service_state=if($liveService){$liveService.State}else{'Absent'}
                notepad_alive=$notepadAlive
            }
            Write-E2EJson $heartbeat "$evidence/receiver-heartbeat.json"
            ConvertTo-Json -InputObject $heartbeat -Depth 8 -Compress | Add-Content "$evidence/receiver-samples.jsonl" -Encoding UTF8
            $result.receiver_valid=$valid
            if (-not $valid) { throw 'Receiver readiness lost: service, registration identity or EDIT unavailable.' }
        }
        Save-ReceiverHeartbeat
        Write-E2EJson (Get-Content "$evidence/receiver-heartbeat.json" -Raw | ConvertFrom-Json) "$control/registration-before-connect.json"
        Write-E2EJson @{ run=$attempt; id=$reg.id; password_ciphertext=$cipher; encryption='RSA-3072 OAEP-SHA1'; computer=$env:COMPUTERNAME; machine_id=$machineId; visual_marker=$visual } "$control/control.json"
        'ready' | Set-Content "$private/control-ready"
        $result.stage='receiver_observe_wm_gettext'
        $deadline = [DateTime]::UtcNow.AddMinutes(7)
        $nextHeartbeat=[DateTime]::UtcNow
        while ([DateTime]::UtcNow -lt $deadline) {
            if ([DateTime]::UtcNow -ge $nextHeartbeat) { Save-ReceiverHeartbeat; $nextHeartbeat=[DateTime]::UtcNow.AddSeconds(10) }
            $text = [E2ENative]::ReadEdit($edit)
            if ($text.Contains($pub.input_marker)) {
                Save-ReceiverHeartbeat
                $result.connection='PASS'; $result.input='PASS'; $result.status='PASS'
                $result.failure_class='NONE'
                $result['input_marker']=$pub.input_marker; $result['visual_marker']=$visual
                $result['wm_gettext']=$text; $result['sender_computer']=$pub.computer
                Save-E2EScreen "$evidence/receiver-notepad.png" $hwnd
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if ($result.status -ne 'PASS') {
            Save-ReceiverHeartbeat
            $result.failure_class='ACCEPTANCE_NOT_PROVEN'
            $result['failure_reason']='REMOTE_INPUT_NOT_OBSERVED'
            throw 'Receiver did not observe remote marker via bounded WM_GETTEXT.'
        }
        $result.stage='complete_receiver_observation'
    } elseif ($Role -eq 'receiver') {
        $result.stage='receiver_cross_step_liveness'
        $deadline = [DateTime]::UtcNow.AddMinutes(8)
        $waiter=[ordered]@{ check_count=0; alive_check_count=0; cross_step_agent_alive=$false; failure_reason=$null }
        while (-not (Test-Path "$private/agent-done") -and [DateTime]::UtcNow -lt $deadline) {
            $heartbeat=Get-Content "$evidence/receiver-heartbeat.json" -Raw | ConvertFrom-Json
            $agent=Get-Process -Id $heartbeat.agent_pid -ErrorAction SilentlyContinue
            $alive=$agent -and $agent.StartTime.ToUniversalTime().ToString('o') -ceq $heartbeat.agent_started_utc
            $age=([DateTime]::UtcNow-[DateTime]::Parse($heartbeat.observed_utc).ToUniversalTime()).TotalSeconds
            $waiter.check_count++
            if ($alive) { $waiter.alive_check_count++; $waiter.cross_step_agent_alive=$true }
            $waiter['agent_alive_now']=[bool]$alive
            $waiter['agent_pid']=$heartbeat.agent_pid; $waiter['agent_started_utc']=$heartbeat.agent_started_utc
            $waiter['heartbeat_age_seconds']=$age; $waiter['observed_utc']=[DateTime]::UtcNow.ToString('o')
            if (-not $alive) { $waiter.failure_reason='AGENT_EXITED_WITHOUT_COMPLETION' }
            elseif ($age -gt 35) { $waiter.failure_reason='AGENT_HEARTBEAT_STALE' }
            Write-E2EJson $waiter "$evidence/receiver-waiter.json"
            if ($waiter.failure_reason) {
                Start-Sleep -Seconds 2
                if (-not (Test-Path "$private/agent-done")) { $result['failure_reason']=$waiter.failure_reason; throw 'Receiver agent liveness invalid.' }
                $waiter.failure_reason=$null
                Write-E2EJson $waiter "$evidence/receiver-waiter.json"
            }
            Start-Sleep -Seconds 2
        }
        if (-not (Test-Path "$private/agent-done")) { $result['failure_reason']='AGENT_COMPLETION_TIMEOUT'; throw 'Receiver monitor did not finish.' }
        $agentResult = Get-Content "$evidence/result.json" -Raw | ConvertFrom-Json
        if ($agentResult.status -ne 'PASS') { throw 'Receiver observation failed.' }
        return
    } else {
        $result.stage='wait_receiver_ciphertext'
        Wait-E2EArtifact "e2e-receiver-control-$env:GITHUB_RUN_ATTEMPT" "$private/receiver-control"
        $coord = Get-Content "$private/receiver-control/control.json" -Raw | ConvertFrom-Json
        if ($coord.run -cne $attempt -or -not $coord.machine_id -or $coord.machine_id -ceq $machineId -or $coord.id -notmatch '^\d+$') { throw 'Invalid receiver coordination.' }
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
        Invoke-E2EApp $exe '--silent-install printer=0' $private -AllowInstallerTermination
        (Get-Service AbritDesk).WaitForStatus('Running', [TimeSpan]::FromSeconds(30))
        $result.stage='sender_registration'
        Invoke-E2ERegistration $installed $private "$evidence/registration" $expectedDomain $expectedKey
        $result.registration='PASS'
        # A new peer file on this disposable sender only; server/key defaults stay untouched.
        $peers = Join-Path $env:APPDATA 'AbritDesk/config/peers'
        New-Item -ItemType Directory -Path $peers -Force | Out-Null
        $target = "$($coord.id)/r"
        $peerId=$coord.id
        if ($env:E2E_ROUTING -eq 'ExplicitUri') { $target="$($coord.id)/r@$expectedDomain"; $peerId="$($coord.id)@$expectedDomain" }
        $peerFile = Join-Path $peers "$peerId.toml"
        if (Test-Path $peerFile) { throw 'Receiver peer config already exists; refusing overwrite.' }
        "view_style = 'original'`nimage_quality = 'best'" | Set-Content -LiteralPath $peerFile -Encoding ASCII
        $beforeConnect=Get-Content "$private/receiver-control/registration-before-connect.json" -Raw | ConvertFrom-Json
        if (-not $beforeConnect.receiver_valid -or $beforeConnect.registration.id -cne $coord.id -or $beforeConnect.machine_id -cne $coord.machine_id) { throw 'Invalid receiver readiness snapshot.' }
        Write-E2EJson $beforeConnect "$evidence/receiver-before-connect.json"
        $result['routing']='default_id'; $result['connect_argument']=$target
        $arguments="--connect $target --password $password"
        if ($env:E2E_ROUTING -eq 'ExplicitUri') {
            # Flutter handleUriLink parses this positional URI directly. Do not
            # feed a ?key ID to --connect, whose core URI builder adds another ?.
            $uri=New-E2EConnectUri $coord.id $expectedDomain $expectedKey $password
            $arguments='"' + $uri + '"'
            $result.routing='explicit_trusted_key_positional_uri'
            $result['default_id_routing']='NOT_TESTED_IN_THIS_RUN'
        }
        $result.stage='sender_connect_and_display'
        $ui = Start-Process $installed -ArgumentList $arguments -PassThru -RedirectStandardOutput "$private/ui.stdout" -RedirectStandardError "$private/ui.stderr"
        $ui.Id | Set-Content "$private/ui.pid"
        $null=$ui.Handle
        $ui.StartTime.ToUniversalTime().ToString('o') | Set-Content "$private/ui.pid.started"
        $password=$null; $arguments=$null; $uri=$null
        $template = New-Object Drawing.Bitmap("$private/receiver-control/display-template.png")
        $deadline = [DateTime]::UtcNow.AddMinutes(4)
        $session = [IntPtr]::Zero
        $result['session_window_seen']=$false; $result['session_foreground_seen']=$false
        try {
            while ([DateTime]::UtcNow -lt $deadline) {
                $session = [E2ENative]::SessionWindow($coord.id)
                if ($session -ne [IntPtr]::Zero) {
                    $result.session_window_seen=$true
                    $null = [E2ENative]::ShowWindow($session,3)
                    $null = [E2ENative]::SetForegroundWindow($session)
                    Start-Sleep -Seconds 2
                    if ([E2ENative]::GetForegroundWindow() -ne $session) { continue }
                    $result.session_foreground_seen=$true
                    Save-E2EScreen "$private/sender-screen.png" $session
                    # This is only the ID-specific Remote Desktop window, not the
                    # local dashboard which can display a temporary password.
                    Copy-Item "$private/sender-screen.png" "$evidence/sender-session.png"
                    $screen = New-Object Drawing.Bitmap("$private/sender-screen.png")
                    try { $visible = [E2ENative]::ContainsTemplate($screen,$template) } finally { $screen.Dispose() }
                    if ($visible) { $result.display='PASS'; break }
                }
                Start-Sleep -Seconds 3
            }
        } finally { $template.Dispose() }
        if ($result.display -ne 'PASS') {
            $result.stage='sender_validate_receiver_after_display_failure'
            Wait-E2EArtifact "e2e-receiver-evidence-$env:GITHUB_RUN_ATTEMPT" "$private/receiver-evidence"
            $receiver=Get-Content "$private/receiver-evidence/result.json" -Raw | ConvertFrom-Json
            $waiter=Get-Content "$private/receiver-evidence/receiver-waiter.json" -Raw | ConvertFrom-Json
            $hasValidity=$null -ne $receiver.PSObject.Properties['receiver_valid']
            $result['receiver_valid']=$hasValidity -and $receiver.receiver_valid -eq $true -and $receiver.machine_id -ceq $coord.machine_id -and $waiter.cross_step_agent_alive -and -not $waiter.failure_reason -and $waiter.alive_check_count -gt 3
            if ($result.receiver_valid) { $result.failure_class='ACCEPTANCE_NOT_PROVEN'; $result['failure_reason']='REMOTE_DISPLAY_NOT_OBSERVED_WITH_LIVE_RECEIVER' }
            else { $result['failure_reason']='RECEIVER_LIVENESS_OR_READINESS_INVALID' }
            throw 'Remote display acceptance failed; receiver validity recorded separately.'
        }
        Copy-Item "$private/sender-screen.png" "$evidence/sender-display.png"
        $result.connection='PASS'
        $result['receiver_computer']=$coord.computer; $result['receiver_id']=$coord.id
        $result['visual_marker']=$coord.visual_marker; $result['input_marker']=$pub.input_marker
        $result['connect_argument']=$target
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
        $bounds = New-Object E2ENative+Rect
        $null = [E2ENative]::GetWindowRect($session,[ref]$bounds)
        $null = [E2ENative]::SetCursorPos(($bounds.Left+[E2ENative]::MatchX+20),($bounds.Top+[E2ENative]::MatchY+8))
        [E2ENative]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
        [E2ENative]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
        Start-Sleep -Milliseconds 300
        [Windows.Forms.SendKeys]::SendWait('^{END}')
        [Windows.Forms.SendKeys]::SendWait('{ENTER}' + $pub.input_marker)
        $result.input='SENT_NOT_YET_OBSERVED'
        Start-Sleep -Seconds 4
        Save-E2EScreen "$evidence/sender-after-input.png" $session
        # Receiver evidence is uploaded at job end; require its independent observation.
        $result.stage='sender_wait_independent_input_proof'
        Wait-E2EArtifact "e2e-receiver-evidence-$env:GITHUB_RUN_ATTEMPT" "$private/receiver-evidence"
        $receiver = Get-Content "$private/receiver-evidence/result.json" -Raw | ConvertFrom-Json
        $waiter=Get-Content "$private/receiver-evidence/receiver-waiter.json" -Raw | ConvertFrom-Json
        $receiverCleanup=Get-Content "$private/receiver-evidence/cleanup.json" -Raw | ConvertFrom-Json
        if ($receiver.status -ne 'PASS' -or $receiver.receiver_valid -ne $true -or $receiver.input -ne 'PASS' -or $receiver.input_marker -cne $pub.input_marker -or $receiver.machine_id -cne $coord.machine_id -or $waiter.alive_check_count -lt 1 -or $waiter.failure_reason -or $receiverCleanup.status -ne 'PASS') { throw 'Receiver did not independently confirm valid input, lifetime and cleanup.' }
        $result.input='PASS'; $result.status='PASS'; $result.failure_class='NONE'; $result.stage='complete'
    }
} catch {
    # Do not serialize exceptions/native logs: they can contain command credentials.
    $result['failure_type']=$_.Exception.GetType().FullName
    $result['failure_line']=$_.InvocationInfo.ScriptLineNumber
    $result['failure']='Acceptance failed; inspect sanitized stage fields. Private command output intentionally withheld.'
    throw 'Two-machine acceptance failed. See sanitized result.json; no credential-bearing output published.'
} finally {
    if ($Role -eq 'sender' -or $Phase -eq 'ReceiverAgent') {
        try {
            $pids = @(Get-Process AbritDesk -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
            $connections = @(Get-NetTCPConnection -State Established | Where-Object { $_.OwningProcess -in $pids -and $_.RemotePort -in @(21115,21116,21117) } | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess)
            Write-E2EJson $connections "$evidence/server-tcp-final.json"
            Write-E2EJson @([Net.Dns]::GetHostAddresses($expectedDomain) | ForEach-Object { $_.ToString() }) "$evidence/expected-server-addresses.json"
        } catch { $result['endpoint_diagnostic']='UNAVAILABLE' }
    }
    $result.observed_utc=[DateTime]::UtcNow.ToString('o')
    # The foreground receiver waiter must not overwrite its agent's evidence.
    if ($Phase -eq 'ReceiverAgent' -or $Role -eq 'sender' -or -not (Test-Path "$evidence/result.json")) {
        Write-E2EJson $result "$evidence/result.json"
    }
    if ($Phase -eq 'ReceiverAgent') { 'done' | Set-Content "$private/agent-done" }
}
