param([Hashtable] $Parameters)

# AC15 starts a background session in a fresh ordinary company. Only that codeunit
# needs Disabled isolation; retain the standard runner for every other test.
if ($Parameters.extensionId -ne '564eea9a-e27b-4358-bbae-28d380268382') {
    return (Run-TestsInBcContainer @Parameters)
}

$isolated = $Parameters.Clone()
$isolated.testCodeunit = '*'
# A codeunit range replaces extension selection in the BC command-line runner.
# Keep it inside this test app's assigned 97600..97699 range.
$isolated.testCodeunitRange = '97600..97612|97614..97699'
$isolated.testRunnerCodeunitId = '130450'
$isolatedPassed = Run-TestsInBcContainer @isolated

$background = $Parameters.Clone()
$background.testCodeunit = '*'
$background.testCodeunitRange = '97613..97613'
$background.testRunnerCodeunitId = '130451'
# Both invocations append into the same pipeline result file. Run the second even
# when the first returns false; preserve every failure and the complete test count.
$backgroundPassed = Run-TestsInBcContainer @background
return ($isolatedPassed -and $backgroundPassed)
