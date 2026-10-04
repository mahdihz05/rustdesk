param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$Output
)
$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path -LiteralPath $Executable).Path
$outputPath = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
try {
    foreach ($language in @('fa', 'en')) {
        foreach ($theme in @('light', 'dark')) {
            $casePath = Join-Path $outputPath "$language-$theme"
            New-Item -ItemType Directory -Path $casePath -Force | Out-Null
            $env:ABRIT_UI_SMOKE_DIR = $casePath
            $env:ABRIT_UI_SMOKE_LANG = $language
            $env:ABRIT_UI_SMOKE_THEME = $theme
            $app = Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru -WindowStyle Hidden
            try {
                $deadline = [DateTime]::UtcNow.AddSeconds(90)
                while (-not (Test-Path (Join-Path $casePath 'complete.json'))) {
                    if (Test-Path (Join-Path $casePath 'errors.txt')) {
                        throw (Get-Content (Join-Path $casePath 'errors.txt') -Raw)
                    }
                    $app.Refresh()
                    if ($app.HasExited) { throw "Preview exited before rendering: $language/$theme ($($app.ExitCode))" }
                    if ([DateTime]::UtcNow -gt $deadline) { throw "Preview render timed out: $language/$theme" }
                    Start-Sleep -Seconds 1
                }
                if (Test-Path (Join-Path $casePath 'errors.txt')) { throw (Get-Content (Join-Path $casePath 'errors.txt') -Raw) }
                $images = @(Get-ChildItem $casePath -Filter '*.png')
                if ($images.Count -ne 14) { throw "Expected 14 actual application screenshots, received $($images.Count)" }
                Write-Output "Actual release UI passed: $language/$theme ($($images.Count) screenshots)"
            } finally {
                if (-not $app.HasExited) { Stop-Process -Id $app.Id -Force }
                Start-Sleep -Seconds 2
            }
        }
    }
} finally {
    Remove-Item Env:ABRIT_UI_SMOKE_DIR, Env:ABRIT_UI_SMOKE_LANG, Env:ABRIT_UI_SMOKE_THEME -ErrorAction SilentlyContinue
}
