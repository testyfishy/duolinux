param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Rest
)

$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "toolkit\duo.py"
$env:PYTHONUNBUFFERED = "1"

$py = Get-Command python -ErrorAction SilentlyContinue
if ($py) {
    & $py.Source $script @Rest
    exit $LASTEXITCODE
}
$py = Get-Command py -ErrorAction SilentlyContinue
if ($py) {
    & $py.Source -3 $script @Rest
    exit $LASTEXITCODE
}
Write-Error "Python 3 not found. Install it from python.org or the Microsoft Store."
exit 1
