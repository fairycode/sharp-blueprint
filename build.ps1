<#
    Script performs the next steps:

    1. Ensures that NuGet executable is available in "tools" folder.
       If not available it's downloaded from "dist.nuget.org".

    2. Restores all packages defined in root "packages.config" and project-specific
       config files into top-level "packages" folder.

    3. [Init]. Initialises build by removing previous artifacts and creates
       temporary output directories (".\build\" and ".\build\temp\").

    4. [Compile]. Compiles all projects defined in SharpBlueprint.sln with msbuild tool.

    5. [TestNUnit]. Runs NUnit tests with OpenCover profiler (for .NET 3.5 projects).
        Test coverage statistics are gathered into OpenCover.xml file.
        NUnit test results are uploaded to AppVeyor (if AppVeyor build environment).

    6. [TestxUnit]. Runs xUnit tests with OpenCover profiler (for .NET 4.5+ projects).
        Test coverage statistics are gathered into OpenCover.xml file.
        xUnit test results are uploaded to AppVeyor (if AppVeyor build environment).

    Steps that are not implemented yet:
        - StyleCop
        - uploading test coverage results to Coveralls
        - packaging

    TBD...
#>

param (
    [Int32]$buildNumber=0,
    [String]$branchName="localBuild",
    [String]$gitCommitHash="unknownHash"
)

. build\helpers.ps1

# script "build.ps1" is located in solution's root folder
$solutionRoot = (Resolve-Path .)

# NuGet is the package manager for .NET platform
$nugetExe = Get-NuGet $solutionRoot

@(
    # packages used in build process and maintenance
    ".\packages.config",

    # project-specific packages
    # TODO: rewrite so config files are picked up automatically for projects defined in solution
    # TODO: add support for .NET Core projects
    ".\src\SharpBlueprint.Client\packages.config",
    ".\src\SharpBlueprint.Client_Net35\packages.config",

    ".\test\SharpBlueprint.Client.Tests\packages.config",
    ".\test\SharpBlueprint.Client.Tests_Net35\packages.config"

) | foreach {
    # packages are restored into single top-level "packages" folder
    if (Test-Path $_) {
        &$nugetExe restore (Resolve-Path $_) -PackagesDirectory "$solutionRoot\packages"
    }
}

# ensure that Psake is not in the current session for safe importing
remove-module [p]sake

#
# Psake is a build automation tool that simplifies our life with PowerShell (MS shell).
#
Import-Module ((Find-PackagePath ".\packages\" "psake") + "\tools\psake.psm1")

# TODO: consider to get hard-coded params like"Release", "Any CPU" etc. from build environment (ex. AppVeyor) 
Invoke-psake -buildFile .\build\default.ps1 `
             -taskList Clean `
             -properties @{
                 "buildConfiguration" = "Release"
                 "buildPlatform" = "Any CPU" } `
             -parameters @{
                 "solutionFile" = "..\SharpBlueprint.sln"
                 "buildNumber" = $buildNumber
                 "branchName" = $branchName
                 "gitCommitHash" = $gitCommitHash }

Write-Host "Build exit code:" $LastExitCode

# propagate the exit code so that builds actually fail when there is a problem
exit $LastExitCode