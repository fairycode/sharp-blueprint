Include ".\helpers.ps1"

properties {

    $solutionDirectory = (Get-Item $solutionFile).DirectoryName
    $outputDirectory= "$solutionDirectory\.build"
    $temporaryOutputDirectory = "$outputDirectory\temp"

    $publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
    $publishedxUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedxUnitTests"
    $publishedLibrariesDirectory = "$temporaryOutputDirectory\_PublishedLibraries"

    $testResultsDirectory = "$outputDirectory\TestResults"
    $NUnitTestResultsDirectory = "$testResultsDirectory\NUnit"
    $xUnitTestResultsDirectory = "$testResultsDirectory\xUnit"
    $packagesOutputDirectory = "$outputDirectory\Packages"

    $testCoverageDirectory = "$outputDirectory\TestCoverage"
    $testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
    # exclude nunit, xunit and our own test assemblies
    $testCoverageFilter = "+[*]* -[nunit.*]* -[xunit.*]* -[*.Tests]*"
    # exclude code marked by [ExcludeFromCodeCoverage] attribute
    $testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
    # exclude files by pattern (ex. auto-generated files)
    $testCoverageExcludeByFile = ""

    $buildConfiguration = "Release"
    $buildPlatform = "Any CPU"

    $packagesPath= "$solutionDirectory\packages"
    $NUnitExe = (Find-PackagePath $packagesPath "NUnit.ConsoleRunner") + "\tools\nunit3-console.exe"
    $xUnitExe = (Find-PackagePath $packagesPath "xUnit.Runner.Console") + "\Tools\xunit.console.exe"

    $openCoverExe = (Find-PackagePath $packagesPath "OpenCover") + "\Tools\OpenCover.Console.exe"

    $nugetExe = Get-NuGet $solutionDirectory
}

task default -depends Test

FormatTaskName "`r`n`r`n-------- Executing {0} Task --------"

task Init `
    -description "Initialises the build by removing previous artifacts and creating output directories" `
    -requiredVariables outputDirectory, temporaryOutputDirectory `
{
    Assert ("Debug", "Release" -contains $buildConfiguration) `
           "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

    Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
           "Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

    # Check that all tools are available
    Write-Host "Checking that all required tools are available"
 
    Assert (Test-Path $NUnitExe) "NUnit Console could not be found"
    Assert (Test-Path $xUnitExe) "xUnit Console could not be found"
    Assert (Test-Path $openCoverExe) "OpenCover Console could not be found"
    Assert (Test-Path $nugetExe) "NuGet Command Line could not be found"

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
 
task Compile `
    -depends Init `
    -description "Compile the code" `
    -requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{
    Write-Host "Building solution $solutionFile"

    # MSBuild is still the best tool for building .NET projects.
    # TODO: Consider case when MSBuild is not available on machine... Get it from NuGet repo???
    # msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"
    Exec { msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory" }
}

task TestNUnit `
    -depends Compile `
    -description "Run NUnit tests" `
    -precondition { return Test-Path $publishedNUnitTestsDirectory } `
    -requiredVariable publishedNUnitTestsDirectory, NUnitTestResultsDirectory `
{
    $testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
                                    -publishedTestsDirectory $publishedNUnitTestsDirectory `
                                    -testResultsDirectory $NUnitTestResultsDirectory `
                                    -testCoverageDirectory $testCoverageDirectory

    # TODO: Check what other options in NUnit test runner are available
    $targetArgs = "$testAssemblies --result=`"`"$NUnitTestResultsDirectory\NUnit.xml`"`""

    # Run OpenCover, which in turn will run NUnit
    Run-Tests -openCoverExe $openCoverExe `
              -targetExe $nunitExe `
              -targetArgs $targetArgs `
              -coveragePath $testCoveragereportPath `
              -filter $testCoverageFilter `
              -excludebyattribute:$testCoverageExcludeByAttribute `
              -excludebyfile:$testCoverageExcludeByFile

    if ($env:APPVEYOR -eq $true) {
        Upload-TestResults "https://ci.appveyor.com/api/testresults/nunit3/$($env:APPVEYOR_JOB_ID)" (Resolve-Path $NUnitTestResultsDirectory\NUnit.xml)
    }
}

task TestxUnit `
    -depends Compile `
    -description "Run xUnit tests" `
    -precondition { return Test-Path $publishedxUnitTestsDirectory } `
    -requiredVariable publishedxUnitTestsDirectory, xUnitTestResultsDirectory `
{
    $testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
                                    -publishedTestsDirectory $publishedxUnitTestsDirectory `
                                    -testResultsDirectory $xUnitTestResultsDirectory `
                                    -testCoverageDirectory $testCoverageDirectory

    # TODO: Check what other options in xUnit test runner are available
    $targetArgs = "$testAssemblies -xml `"`"$xUnitTestResultsDirectory\xUnit.xml`"`" -nologo -noshadow"

    # Run OpenCover, which in turn will run xUnit
    Run-Tests -openCoverExe $openCoverExe `
              -targetExe $xunitExe `
              -targetArgs $targetArgs `
              -coveragePath $testCoveragereportPath `
              -filter $testCoverageFilter `
              -excludebyattribute:$testCoverageExcludeByAttribute `
              -excludebyfile:$testCoverageExcludeByFile

    if ($env:APPVEYOR -eq $true) {
        Upload-TestResults "https://ci.appveyor.com/api/testresults/xunit/$($env:APPVEYOR_JOB_ID)" (Resolve-Path $xUnitTestResultsDirectory\xUnit.xml)
    }
}

task Test `
    -depends Compile, TestNUnit, TestxUnit `
    -description "Run unit tests" `
{
    Write-Host "Executed Test!"
}

task Package `
    -depends Compile, Test `
    -description "Prepare NuGet package" `
    -requiredVariables publishedLibrariesDirectory, packagesOutputDirectory `
{
    Write-Host "Looking for nuspec file at $solutionDirectory"

    $nuspecs = @(Get-ChildItem -Path $solutionDirectory -Filter "*.nuspec")

    if ($nuspecs.Length -gt 0)
    {
        if (!(Test-Path $packagesOutputDirectory))
        {
            New-Item $packagesOutputDirectory -ItemType Directory | Out-Null
        }

        foreach ($nuspec in $nuspecs)
        {
            Copy-Item $nuspec.FullName -Destination $publishedLibrariesDirectory

            Write-Host "Packaging using $($nuspec.Name)"

            $nuspecFile = $publishedLibrariesDirectory + "\" + $nuspec

            $nuspecContent = [xml](Get-Content -Path $nuspecFile -Encoding UTF8)
            $metadata = $nuspecContent.package.metadata

            $metadata.version = $metadata.version.Replace("{build}", $buildNumber)
            $metadata.releaseNotes = "Build Number: $buildNumber`r`nBranch Name: $branchName`r`nCommit Hash: $gitCommitHash"

            # Save the nuspec file
            $nuspecContent.Save((Get-Item $nuspecFile))

            # package as NuGet package
            Exec { &$nugetExe pack $nuspecFile -OutputDirectory $packagesOutputDirectory }
        }
    }
    else
    {
        Write-Host "No any nuspec file found."
    }
}

task Clean `
    -depends Compile, Test, Package `
    -description "Remove temporary files" `
    -requiredVariables packagesOutputDirectory `
{
    if (Test-Path $temporaryOutputDirectory)
    {
        Write-Host "Removing temporary output directory located at $temporaryOutputDirectory"

        Remove-Item $temporaryOutputDirectory -Force -Recurse
    }
}