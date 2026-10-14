# Safe local fixtures: no executable invocation, install, service mutation or desktop input.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
foreach ($file in (Get-ChildItem "$PSScriptRoot/e2e*.ps1")) {
    $tokens=$null; $errors=$null
    $null = [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw "PowerShell syntax failure: $($file.Name): $errors" }
    "PASS syntax: $($file.Name)"
}
. "$PSScriptRoot/e2e-common.ps1"
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) "opencode/e2e-fixture-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    Invoke-E2EApp "$env:windir/System32/cmd.exe" '/c exit 0' $fixtureRoot
    $rejected=$false
    try { Invoke-E2EApp "$env:windir/System32/cmd.exe" '/c exit 7' $fixtureRoot } catch { $rejected=$true }
    if (-not $rejected) { throw 'Nonzero native process exit falsely accepted.' }
    'PASS redirected native process fixture: zero accepted, nonzero rejected'
} finally { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
Initialize-E2ENative
$sender = New-Object Security.Cryptography.RSACryptoServiceProvider(3072)
$receiver = New-Object Security.Cryptography.RSACryptoServiceProvider
$sender.PersistKeyInCsp=$false; $receiver.PersistKeyInCsp=$false
try {
    $publicXml=$sender.ToXmlString($false)
    if ($publicXml -match '<(P|Q|D|DP|DQ|InverseQ)>') { throw 'Private RSA material in public key.' }
    $receiver.FromXmlString($publicXml)
    $password='0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'
    $cipher=$receiver.Encrypt([Text.Encoding]::UTF8.GetBytes($password),$true)
    if ([Text.Encoding]::UTF8.GetString($sender.Decrypt($cipher,$true)) -cne $password) { throw 'Credential round trip failed.' }
    'PASS RSA public-only OAEP credential round trip'
} finally { $sender.Dispose(); $receiver.Dispose() }
$template = New-Object Drawing.Bitmap(350,24)
$screen = New-Object Drawing.Bitmap(500,100)
$g=[Drawing.Graphics]::FromImage($template)
$sg=[Drawing.Graphics]::FromImage($screen)
try {
    $g.Clear([Drawing.Color]::White)
    $g.DrawString('DISPLAY_a19c71237eed44b9af228050e2123416',[Drawing.SystemFonts]::DefaultFont,[Drawing.Brushes]::Black,0,0)
    $sg.Clear([Drawing.Color]::White)
    if ([E2ENative]::ContainsTemplate($screen,$template)) { throw 'Blank screen falsely accepted.' }
    $sg.DrawImageUnscaled($template,37,29)
    if (-not [E2ENative]::ContainsTemplate($screen,$template)) { throw 'Visible template rejected.' }
    $sg.Clear([Drawing.Color]::White)
    $sg.DrawString('DISPLAY_ff302abe16ad45c39985d3a5b876beef',[Drawing.SystemFonts]::DefaultFont,[Drawing.Brushes]::Black,37,29)
    if ([E2ENative]::ContainsTemplate($screen,$template)) { throw 'Wrong marker falsely accepted.' }
    'PASS display fixtures: blank and wrong text rejected; visible text accepted'
} finally { $g.Dispose(); $sg.Dispose(); $template.Dispose(); $screen.Dispose() }
$workflow=Get-Content "$PSScriptRoot/../../.github/workflows/abritdesk-connection-e2e.yml" -Raw
if ($workflow -match '(?m)^\s+needs:' -or $workflow -notmatch 'role: \[receiver, sender\]' -or
    $workflow -notmatch 'fail-fast: false' -or $workflow -notmatch 'runs-on: windows-2022' -or
    $workflow -notmatch 'timeout-minutes: 20' -or $workflow -match '\$\{\{\s*secrets\.') { throw 'Workflow topology/security fixture failed.' }
if ($workflow -match '(?m)^\s+path:.*(?:private|abrit-e2e/\s*$)') { throw 'Broad/private artifact upload forbidden.' }
'PASS workflow static fixtures: independent jobs, restricted evidence paths, no secrets'
$source = Get-Content "$PSScriptRoot/e2e.ps1" -Raw
if ($source -match '\.(computer) -ceq \$env:COMPUTERNAME' -or $source -notmatch 'Win32_ComputerSystemProduct' -or $source -notmatch '\$pub.machine_id -ceq \$machineId') {
    throw 'Independent VM identity must not rely on cloned hostnames.'
}
'PASS VM identity fixture: hardware UUID, not hostname'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    $rejected=$false
    try { Assert-E2ERunner } catch { $rejected=$true }
    if (-not $rejected) { throw 'Local-run guard failed.' }
    'PASS developer-machine safety guard'
}
