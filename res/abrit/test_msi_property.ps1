$ErrorActionPreference = 'Stop'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'test_windows_identity.ps1'), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-MsiProperty' }, $true)
if (-not $function) { throw 'Get-MsiProperty not found.' }
. ([scriptblock]::Create($function.Extent.Text))

class MsiRecordStub {
    [string]$Value
    MsiRecordStub([string]$value) { $this.Value = $value }
    [string] StringData([int]$index) { return $this.Value }
}
class MsiViewStub {
    [MsiRecordStub]$Record
    [bool]$Closed
    MsiViewStub([string]$value) { $this.Record = [MsiRecordStub]::new($value) }
    [object] Execute() { return $null }
    [object] Fetch() { return $this.Record }
    [object] Close() { $this.Closed = $true; return $null }
}
class MsiDatabaseStub {
    [MsiViewStub]$View
    MsiDatabaseStub([string]$value) { $this.View = [MsiViewStub]::new($value) }
    [object] OpenView([string]$query) { return $this.View }
}
foreach ($expected in @('abritdesk', 'Abrit')) {
    $database = [MsiDatabaseStub]::new($expected)
    $actual = Get-MsiProperty $database 'ProductName'
    if ($actual -isnot [string] -or $actual -cne $expected -or -not $database.View.Closed) {
        throw 'MSI property must be a scalar string and the view must close.'
    }
}
# COM void methods emit nulls into PowerShell's success stream unless suppressed.
$original = $function.Extent.Text.Replace('$null = $view.Execute()', '$view.Execute()').Replace('$null = $view.Close()', '$view.Close()')
. ([scriptblock]::Create($original))
$broken = Get-MsiProperty ([MsiDatabaseStub]::new('abritdesk')) 'ProductName'
if ($broken -isnot [object[]] -or @($broken).Count -ne 3 -or -not ($broken -cne 'abritdesk')) {
    throw 'Regression fixture did not reproduce the original failure.'
}
'PASS: MSI scalar property regression (not live connection evidence).'
