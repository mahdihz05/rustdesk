$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-E2ERunner {
    if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted' -or
        -not $env:RUNNER_TEMP -or -not $env:GITHUB_RUN_ID) {
        throw 'Restricted to disposable GitHub-hosted runners; no local installation is permitted.'
    }
}

function Write-E2EJson($Value, [string]$Path) {
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Wait-E2EArtifact([string]$Name, [string]$Destination) {
    $deadline = [DateTime]::UtcNow.AddMinutes(9)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    while ([DateTime]::UtcNow -lt $deadline) {
        $raw = & gh api "repos/$env:GITHUB_REPOSITORY/actions/runs/$env:GITHUB_RUN_ID/artifacts?per_page=100" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $items = @((($raw -join "`n") | ConvertFrom-Json).artifacts | Where-Object { $_.name -ceq $Name -and -not $_.expired })
            if ($items.Count -eq 1) {
                # gh keeps Authorization in its environment; no token in arguments or URLs.
                & gh run download $env:GITHUB_RUN_ID --repo $env:GITHUB_REPOSITORY --name $Name --dir $Destination 2>$null
                if ($LASTEXITCODE -eq 0) { return }
            }
        }
        Start-Sleep -Seconds 5
    }
    throw "Timed out waiting for same-run artifact: $Name"
}

function Invoke-E2EApp([string]$Exe, [string]$Arguments, [string]$PrivateDirectory, [switch]$AllowInstallerTermination) {
    $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -WorkingDirectory (Split-Path $Exe) -PassThru -WindowStyle Hidden -RedirectStandardOutput "$PrivateDirectory/stdout" -RedirectStandardError "$PrivateDirectory/stderr"
    if (-not $p.WaitForExit(60000)) { $p.Kill(); throw 'Native command timed out (arguments suppressed).' }
    # Commands can print credentials on failure. Never publish their output.
    if ($p.ExitCode -ne 0 -and -not $AllowInstallerTermination) { throw 'Native command failed (output suppressed).' }
}

function Initialize-E2ENative {
    Add-Type -AssemblyName System.Drawing, System.Windows.Forms
    if ('E2ENative' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class E2ENative {
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder b, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr p, IntPtr after, string cls, string title);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, StringBuilder b);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string s);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect r);
    public struct Rect { public int Left, Top, Right, Bottom; }
    public struct Point { public int X, Y; }
    public static IntPtr SessionWindow(string id) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h,p) => {
            var b = new StringBuilder(512); GetWindowText(h,b,512);
            string t = b.ToString();
            if (t.Contains(id) && t.IndexOf("AbritDesk", StringComparison.OrdinalIgnoreCase) >= 0) found = h;
            return true;
        }, IntPtr.Zero);
        return found;
    }
    // Sparse pixel comparison tolerates small codec errors, but not missing text.
    // No OCR/clipboard/API backchannel is accepted as remote display evidence.
    public static bool ContainsTemplate(System.Drawing.Bitmap screen, System.Drawing.Bitmap template) {
        int ink = 0, ax = -1, ay = -1;
        for (int y=0;y<template.Height;y+=2) for(int x=0;x<template.Width;x+=2) {
            var c=template.GetPixel(x,y);
            if(c.R<180 && c.G<180 && c.B<180) { ink++; if(ax<0) { ax=x; ay=y; } }
        }
        if(ink<40) throw new Exception("Display template has insufficient text contrast");
        var anchor=template.GetPixel(ax,ay);
        for(int y=0;y<=screen.Height-template.Height;y++) for(int x=0;x<=screen.Width-template.Width;x++) {
            var candidate=screen.GetPixel(x+ax,y+ay);
            if(Math.Abs(anchor.R-candidate.R)+Math.Abs(anchor.G-candidate.G)+Math.Abs(anchor.B-candidate.B)>90) continue;
            int bad=0, count=0;
            for(int ty=0;ty<template.Height;ty+=2) {
                for(int tx=0;tx<template.Width;tx+=2) {
                    var a=template.GetPixel(tx,ty); var b=screen.GetPixel(x+tx,y+ty); count++;
                    if(Math.Abs(a.R-b.R)+Math.Abs(a.G-b.G)+Math.Abs(a.B-b.B)>90) bad++;
                    if(bad>12) break;
                }
                if(bad>12) break;
            }
            if(bad<=12 && count>100) return true;
        }
        return false;
    }
}
'@ -ReferencedAssemblies System.Drawing
}

function Save-E2EScreen([string]$Path, [IntPtr]$Window = [IntPtr]::Zero) {
    if ($Window -eq [IntPtr]::Zero) { $r = [Windows.Forms.Screen]::PrimaryScreen.Bounds }
    else {
        $wr = New-Object E2ENative+Rect
        if (-not [E2ENative]::GetWindowRect($Window, [ref]$wr)) { throw 'Window bounds unavailable.' }
        $r = New-Object Drawing.Rectangle($wr.Left, $wr.Top, ($wr.Right-$wr.Left), ($wr.Bottom-$wr.Top))
    }
    $bitmap = New-Object Drawing.Bitmap($r.Width, $r.Height)
    $g = [Drawing.Graphics]::FromImage($bitmap)
    try { $g.CopyFromScreen($r.Location, [Drawing.Point]::Empty, $r.Size); $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png) }
    finally { $g.Dispose(); $bitmap.Dispose() }
}
