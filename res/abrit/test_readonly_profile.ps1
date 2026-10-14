$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'test_windows_identity.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ProfileSnapshot' }, $true)
if (-not $function) { throw 'Snapshot function missing' }
. ([scriptblock]::Create($function.Extent.Text))
$path = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString() + '.toml')
try {
    $absent = Get-ProfileSnapshot $path
    if (($absent | ConvertFrom-Json).exists) { throw 'Absent fixture exists' }
    'fixture-only' | Set-Content -LiteralPath $path
    $existing = Get-ProfileSnapshot $path
    if ($existing -cne (Get-ProfileSnapshot $path) -or $existing -ceq $absent) { throw 'Preexisting unchanged profile regression' }
    'changed-fixture' | Set-Content -LiteralPath $path
    if ($existing -ceq (Get-ProfileSnapshot $path)) { throw 'Mutation was not detected' }
    Remove-Item -LiteralPath $path
    if ($absent -cne (Get-ProfileSnapshot $path)) { throw 'Deletion/absence regression' }
} finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
'PASS: read-only profile snapshot fixture (not native acceptance evidence).'
