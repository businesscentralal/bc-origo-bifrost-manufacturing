$ErrorActionPreference = 'Stop'
$global:MfgRunnerCalls = @()
$global:MfgRunnerIsolatedResult = $false
function Run-TestsInBcContainer {
    param($extensionId, $testCodeunit, $testCodeunitRange, $testRunnerCodeunitId,
          $JUnitResultFileName, $AppendToJUnitResultFile, $GitHubActions)
    $global:MfgRunnerCalls += $PSBoundParameters
    if ($testRunnerCodeunitId -eq '130450') { return $global:MfgRunnerIsolatedResult }
    return $true
}
$params = @{
    extensionId = '564eea9a-e27b-4358-bbae-28d380268382'
    JUnitResultFileName = 'results.xml'
    AppendToJUnitResultFile = $true
    GitHubActions = 'error'
}
$hook = Join-Path $PSScriptRoot '../.AL-Go/RunTestsInBcContainer.ps1'
$result = & $hook -Parameters $params
if ($result -ne $false -or $global:MfgRunnerCalls.Count -ne 2) { throw 'Preserve the first failure and execute the background-session partition.' }
if ($global:MfgRunnerCalls[0].testCodeunitRange -ne '97600..97612|97614..97699' -or $global:MfgRunnerCalls[0].testRunnerCodeunitId -ne '130450') { throw 'Default isolation must cover all other Manufacturing codeunits without loading foreign apps.' }
if ($global:MfgRunnerCalls[1].testCodeunitRange -ne '97613..97613' -or $global:MfgRunnerCalls[1].testRunnerCodeunitId -ne '130451') { throw 'Only 97613 requires Disabled isolation.' }
foreach ($call in $global:MfgRunnerCalls) {
    if ($call.JUnitResultFileName -ne 'results.xml' -or !$call.AppendToJUnitResultFile -or $call.GitHubActions -ne 'error') { throw 'Preserve result aggregation and failure gates.' }
    if ($call.testCodeunit -ne '*') { throw 'Do not filter loaded test methods.' }
}
# BC uses this range instead of extensionId. Verify it against the actual test
# codeunits, and prove unrelated installed Microsoft tests cannot enter the run.
$scriptRange = $global:MfgRunnerCalls[0].testCodeunitRange
function Test-InManufacturingRange([int] $Id) {
    foreach ($part in $scriptRange.Split('|')) {
        if ($part -notmatch '^(\d+)\.\.(\d+)$') { throw 'Expected explicit bounded ranges.' }
        if ($Id -ge [int]$Matches[1] -and $Id -le [int]$Matches[2]) { return $true }
    }
    return $false
}
$testRoot = Join-Path $PSScriptRoot '../test'
$codeunits = @(Get-ChildItem $testRoot -Recurse -Filter '*.al' | ForEach-Object {
    $source = Get-Content $_.FullName -Raw
    if ($source -match 'Subtype\s*=\s*Test' -and $source -match 'codeunit\s+(\d+)') { [int]$Matches[1] }
})
if ($codeunits.Count -lt 1) { throw 'No actual test codeunits found.' }
foreach ($id in $codeunits) {
    if ((Test-InManufacturingRange $id) -ne ($id -ne 97613)) { throw "Incorrect Manufacturing coverage for $id." }
}
foreach ($id in @(97599, 97700, 133740, 144741, 149109)) {
    if (Test-InManufacturingRange $id) { throw "Foreign codeunit $id must not be selected." }
}
if ($params.ContainsKey('testRunnerCodeunitId') -or $params.ContainsKey('testCodeunitRange')) { throw 'Do not mutate the caller parameters.' }
$global:MfgRunnerCalls = @()
$global:MfgRunnerIsolatedResult = $true
if ((& $hook -Parameters $params) -ne $true -or $global:MfgRunnerCalls.Count -ne 2) { throw 'Combine both successful partitions.' }
$global:MfgRunnerCalls = @()
$foreign = @{extensionId='another-test-app'}
if ((& $hook -Parameters $foreign) -ne $true -or $global:MfgRunnerCalls.Count -ne 1 -or $global:MfgRunnerCalls[0].ContainsKey('testRunnerCodeunitId')) { throw 'Other test apps must pass through unchanged.' }
Write-Host 'Manufacturing runner partition tests passed: coverage, isolation, failure propagation, result aggregation and passthrough.'

Remove-Variable MfgRunnerCalls, MfgRunnerIsolatedResult -Scope Global
