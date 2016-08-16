Include ".\helpers.ps1"

properties {

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

    # MSBuild is still the best tool for building .NET projects
    # TODO: Consider case when MSBuild is not available on machine... Get from NuGet repo???
    # msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
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

    # TODO: Check what other options in NUnit test runner are available
    Exec { &$nunitExe $testAssemblies --result=$NUnitTestResultsDirectory\NUnit.xml }

    if ($env:APPVEYOR -eq $true) {
        Upload-TestResults "https://ci.appveyor.com/api/testresults/nunit3/$($env:APPVEYOR_JOB_ID)" (Resolve-Path $NUnitTestResultsDirectory\NUnit.xml)
    }
}

task TestxUnit `
    -depends Compile `
    -description "Run xUnit tests" `
    -precondition { return Test-Path $publishedxUnitTestsDirectory } `
    -requiredVariable publishedxUnitTestsDirectory, xUnitTestResultsDirectory `
{
    $testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
                                    -publishedTestsDirectory $publishedxUnitTestsDirectory `
                                    -testResultsDirectory $xUnitTestResultsDirectory

    # TODO: Check what other options in xUnit test runner are available
    Exec { &$xUnitExe $testAssemblies -xml $xUnitTestResultsDirectory\xUnit.xml -nologo -noshadow }

    if ($env:APPVEYOR -eq $true) {
        Upload-TestResults "https://ci.appveyor.com/api/testresults/xunit/$($env:APPVEYOR_JOB_ID)" (Resolve-Path $xUnitTestResultsDirectory\xUnit.xml)
    }
}

task Test `
    -depends Compile, TestNUnit, TestxUnit `
    -description "Run unit tests"
{
    Write-Host 'Executed Test!'
}

task Clean -description "Remove temporary files" {
  Write-Host 'Executed Clean!'
}