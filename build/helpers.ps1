#
# TODO:
#
function Get-Nuget {
    [CmdletBinding()]
    param (
        [Parameter(Position=0,Mandatory=1)][string]$rootDirectory
    )

    $nugetExe = "$rootDirectory\tools\nuget.exe"
    $nugetDistUrl = "https://dist.nuget.org/win-x86-commandline/v3.4.4/NuGet.exe"

    if (!(Test-Path $nugetExe)) {
        $toolsDirectory = split-path -parent $nugetExe

        if (!(Test-Path $toolsDirectory)) {
            New-Item $toolsDirectory -ItemType Directory | Out-Null
        }

        Write-Host "Downloading NuGet.exe (into $nugetExe)"

        Invoke-WebRequest $nugetDistUrl -OutFile $nugetExe
    }

    return $nugetExe
}

#
# TODO:
#
function Find-PackagePath
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$packagesPath,
        [Parameter(Position=1,Mandatory=1)]$packageName
    )

    return (Get-ChildItem ($packagesPath + "\" + $packageName + "*")).FullName | Sort-Object $_ | Select-Object -Last 1
}

#
# TODO:
#
function Prepare-Tests
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$testRunnerName,
        [Parameter(Position=1,Mandatory=1)]$publishedTestsDirectory,
        [Parameter(Position=2,Mandatory=1)]$testResultsDirectory
    )

    $projects = Get-ChildItem $publishedTestsDirectory

    if ($projects.Count -eq 1) 
    {
        Write-Host "1 $testRunnerName project has been found:"
    }
    else 
    {
        Write-Host $projects.Count " $testRunnerName projects have been found:"
    }
    
    Write-Host ($projects | Select $_.Name )

    # Create the test results directory if needed
    if (!(Test-Path $testResultsDirectory))
    {
        Write-Host "Creating test results directory located at $testResultsDirectory"
        mkdir $testResultsDirectory | Out-Null
    }

    # Get the list of test DLLs
    $testAssembliesPaths = $projects | ForEach-Object { $_.FullName + "\" + $_.Name + ".dll" }

    $testAssemblies = [string]::Join(" ", $testAssembliesPaths)

    return $testAssemblies
}

#
# TODO:
#
function Upload-TestResults
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$destinationUrl,
        [Parameter(Position=1,Mandatory=1)]$testResulsFile
    )

    Write-Host "Upload test results to AppVeyor"
    $client = New-Object 'System.Net.WebClient'
    $client.UploadFile($destinationUrl, $testResulsFile)
}