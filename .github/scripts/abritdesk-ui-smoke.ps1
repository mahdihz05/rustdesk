$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class AbritPreviewWindow {
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hwnd, int x, int y, int width, int height, bool repaint);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
  public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
$out = Join-Path $PWD 'abritdesk-qa'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$exe = Join-Path $PWD 'flutter/build/windows/x64/runner/Release/abritDesk.exe'
$report = @{ process_started = $false; home_window = $false; captures = @(); errors = @() }
$process = $null
try {
  $process = Start-Process $exe -PassThru -WorkingDirectory (Split-Path $exe)
  $report.process_started = $true
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    $process.Refresh()
    if ($process.HasExited) { throw "Preview exited before showing a window, code $($process.ExitCode)" }
    if ($process.MainWindowHandle -ne 0) { break }
  }
  if ($process.MainWindowHandle -eq 0) { throw 'No native main window was observed on this runner' }
  $report.home_window = $true
  $report.window_title = $process.MainWindowTitle
  foreach ($size in @(@(1200, 860), @(900, 700))) {
    [AbritPreviewWindow]::MoveWindow($process.MainWindowHandle, 0, 0, $size[0], $size[1], $true) | Out-Null
    [AbritPreviewWindow]::SetForegroundWindow($process.MainWindowHandle) | Out-Null
    Start-Sleep -Seconds 5
    $rect = New-Object AbritPreviewWindow+RECT
    [AbritPreviewWindow]::GetWindowRect($process.MainWindowHandle, [ref]$rect) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap ($rect.Right - $rect.Left), ($rect.Bottom - $rect.Top)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { $printed = [AbritPreviewWindow]::PrintWindow($process.MainWindowHandle, $dc, 2) }
    finally { $graphics.ReleaseHdc($dc) }
    if (-not $printed) { $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size) }
    $file = Join-Path $out "home-$($size[0])x$($size[1]).png"
    $bitmap.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    $report.captures += (Split-Path $file -Leaf)
  }
} catch { $report.errors += $_.Exception.Message }
finally {
  if ($null -ne $process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force }
  $report | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $out 'smoke.json') -Encoding UTF8
  Get-Content (Join-Path $out 'smoke.json')
}
# Capture quality and connections must be assessed separately; a headless runner is not manual QA.
