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
if ($global:MfgRunnerCalls[0].testCodeunitRange -ne '<>97613' -or $global:MfgRunnerCalls[0].testRunnerCodeunitId -ne '130450') { throw 'Default isolation must cover all other codeunits.' }
if ($global:MfgRunnerCalls[1].testCodeunitRange -ne '97613..97613' -or $global:MfgRunnerCalls[1].testRunnerCodeunitId -ne '130451') { throw 'Only 97613 requires Disabled isolation.' }
foreach ($call in $global:MfgRunnerCalls) {
    if ($call.JUnitResultFileName -ne 'results.xml' -or !$call.AppendToJUnitResultFile -or $call.GitHubActions -ne 'error') { throw 'Preserve result aggregation and failure gates.' }
    if ($call.testCodeunit -ne '*') { throw 'Do not filter loaded test methods.' }
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
