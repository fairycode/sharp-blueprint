#
# Downloads NuGet executable into "tools" folder if needed.
# Returns path to executable.
#
function Get-NuGet {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,Mandatory=1)][string]$rootDirectory
    )

    $nugetExe = "$rootDirectory\tools\nuget.exe"
    # TODO: pass url via parameter
    $nugetDistUrl = "https://dist.nuget.org/win-x86-commandline/v3.4.4/NuGet.exe"

    if (!(Test-Path $nugetExe)) {
        $toolsDirectory = split-path -parent $nugetExe

        if (!(Test-Path $toolsDirectory)) {
            New-Item $toolsDirectory -ItemType Directory | Out-Null
        }

        Write-Host "Downloading NuGet.exe (into $nugetExe)"

        $client = New-Object 'System.Net.WebClient'
        $client.DownloadFile($nugetDistUrl, $nugetExe)
    }

    return $nugetExe
}

#
# Gets the most recent version of package from "packages" folder.
#
function Find-PackagePath
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$packagesPath,
        [Parameter(Position=1,Mandatory=1)]$packageName
    )

    return (Get-ChildItem ($packagesPath + "\" + $packageName + "*")).FullName | Sort-Object $_ | Select-Object -Last 1
}

#
# Gets the list of test DLLs.
#
function Prepare-Tests
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$testRunnerName,
        [Parameter(Position=1,Mandatory=1)]$publishedTestsDirectory,
        [Parameter(Position=2,Mandatory=1)]$testResultsDirectory,
        [Parameter(Position=3,Mandatory=1)]$testCoverageDirectory
    )

    $projects = Get-ChildItem $publishedTestsDirectory

    if ($projects.Count -eq 1) 
    {
        Write-Host "1 $testRunnerName project has been found:"
    }
    else 
    {
        Write-Host $projects.Count " $testRunnerName projects have been found:"
    }
    
    Write-Host ($projects | Select $_.Name )

    # Create the test results directory if needed
    if (!(Test-Path $testResultsDirectory))
    {
        Write-Host "Creating test results directory located at $testResultsDirectory"
        mkdir $testResultsDirectory | Out-Null
    }

    # Create the test coverage directory if needed
    if (!(Test-Path $testCoverageDirectory))
    {
        Write-Host "Creating test coverage directory located at $testCoverageDirectory"
        mkdir $testCoverageDirectory | Out-Null
    }

    # Get the list of test DLLs
    $testAssembliesPaths = $projects | ForEach-Object { "`"`"" + $_.FullName + "\" + $_.Name + ".dll`"`"" }

    $testAssemblies = [string]::Join(" ", $testAssembliesPaths)

    return $testAssemblies
}

#
# Wraps call to test runner with OpenCover profiler to gather coverage statistics.
#
function Run-Tests
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$openCoverExe,
        [Parameter(Position=1,Mandatory=1)]$targetExe,
        [Parameter(Position=2,Mandatory=1)]$targetArgs,
        [Parameter(Position=3,Mandatory=1)]$coveragePath,
        [Parameter(Position=4,Mandatory=1)]$filter,
        [Parameter(Position=5,Mandatory=1)]$excludeByAttribute,
        [Parameter(Position=6,Mandatory=1)]$excludeByFile
    )

    Write-Host "Running tests"

    <#
        # per-user registration allows using profiler without account
        # with administrative permissions
        -register:user

        # include or exclude assemblies and classes from coverage results
        -filter:$filter
        -excludebyattribute:$excludeByAttribute
        -excludebyfile:$excludeByFile

        # code for auto-implemented properties (getters and setters) is not 
        # useful in test coverage statistics
        -skipautoprops

        # need to merge the coverage results for an assembly as we are using
        # multiple test runners (NUnit and xUnit)
        -mergebyhash
        -mergeoutput

        # keep report clean
        -hideskipped:All

        # propagate return code from test runner
        -returntargetcode
    #>

    Exec { &$openCoverExe -target:$targetExe `
                          -targetargs:$targetArgs `
                          -output:$coveragePath `
                          -register:user `
                          -filter:$filter `
                          -excludebyattribute:$excludeByAttribute `
                          -excludebyfile:$excludeByFile `
                          -skipautoprops `
                          -mergebyhash `
                          -mergeoutput `
                          -hideskipped:All `
                          -returntargetcode }
}

#
# Uploads test results to AppVeyor.
#
function Upload-TestResults
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$destinationUrl,
        [Parameter(Position=1,Mandatory=1)]$testResulsFile
    )

    Write-Host "Uploading test results to AppVeyor"
    $client = New-Object 'System.Net.WebClient'
    $client.UploadFile($destinationUrl, $testResulsFile)
}