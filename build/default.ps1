Include ".\helpers.ps1"

properties {
    $testMessage = 'Executed Test!'
    $cleanMessage = 'Executed Clean!'

    $solutionDirectory = (Get-Item $solutionFile).DirectoryName
    $outputDirectory= "$solutionDirectory\.build"
    $temporaryOutputDirectory = "$outputDirectory\temp"

    $publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
    $publishedxUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedxUnitTests"

    $testResultsDirectory = "$outputDirectory\TestResults"
    $NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
    $xUnitTestResultsDirectory = "$testResultsDirectory\xUnit"

    $buildConfiguration = "Release"
    $buildPlatform = "Any CPU"

    $packagesPath = "$solutionDirectory\packages"
    $NUnitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner" ) + "\tools\nunit3-console.exe"
    $xUnitExe = (Find-PackagePath $packagesPath "xUnit.Runner.Console" ) + "\Tools\xunit.console.exe"
}

task default -depends Test

FormatTaskName "`r`n`r`n-------- Executing {0} Task --------"

task Init `
    -description "Initialises the build by removing previous artifacts and creating output directories" `
    -requiredVariables outputDirectory, temporaryOutputDirectory `
{
    Assert ("Debug", "Release" -contains $buildConfiguration) `
           "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

    Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
           "Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

    # Check that all tools are available
    Write-Host "Checking that all required tools are available"
 
    Assert (Test-Path $NUnitExe) "NUnit Console could not be found"
    Assert (Test-Path $xUnitExe) "xUnit Console could not be found"

    # Remove previous build results
    if (Test-Path $outputDirectory) 
    {
        Write-Host "Removing output directory located at $outputDirectory"
        Remove-Item $outputDirectory -Force -Recurse
    }

    Write-Host "Creating output directory located at $outputDirectory"
    New-Item $outputDirectory -ItemType Directory | Out-Null

    Write-Host "Creating temporary output directory located at $temporaryOutputDirectory" 
    New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}
 
task Compile `
    -depends Init `
    -description "Compile the code" `
    -requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{ 
    Write-Host "Building solution $solutionFile"
    #msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"

    Exec { msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory" }
}

task TestNUnit `
    -depends Compile `
    -description "Run NUnit tests" `
    -precondition { return Test-Path $publishedNUnitTestsDirectory } `
    -requiredVariable publishedNUnitTestsDirectory, NUnitTestResultsDirectory `
{
    $testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
                                    -publishedTestsDirectory $publishedNUnitTestsDirectory `
                                    -testResultsDirectory $NUnitTestResultsDirectory

    Exec { &$nunitExe $testAssemblies --result=$NUnitTestResultsDirectory\NUnit.xml }
}

task TestXUnit `
    -depends Compile `
    -description "Run xUnit tests" `
    -precondition { return Test-Path $publishedxUnitTestsDirectory } `
    -requiredVariable publishedxUnitTestsDirectory, xUnitTestResultsDirectory `
{
    $testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
                                    -publishedTestsDirectory $publishedxUnitTestsDirectory `
                                    -testResultsDirectory $xUnitTestResultsDirectory

    Exec { &$xUnitExe $testAssemblies /xml $xUnitTestResultsDirectory\xUnit.xml }
}

task Test `
    -depends Compile, TestNUnit, TestXUnit `
    -description "Run unit tests"
{
    Write-Host $testMessage
    if ($env:APPVEYOR -eq "True")
    {
        Write-Host "Upload test results to AppVeyor"
        $wc = New-Object 'System.Net.WebClient'
        $wc.UploadFile("https://ci.appveyor.com/api/testresults/xunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $xUnitTestResultsDirectory\xUnit.xml))
    }
}

task Clean -description "Remove temporary files" {
  Write-Host $cleanMessage
}