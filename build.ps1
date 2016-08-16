. build\helpers.ps1

# script "build.ps1" should be in solution root folder
$solutionRoot = (Resolve-Path .)

# init NuGet exe
$nugetExe = Get-Nuget $solutionRoot

@(
    # packages used mainly in build process
    ".\packages.config",

    # project-specific packages
    # TODO: rewrite so config files are picked up automatically for projects defined in solution
    ".\test\SharpBlueprint.Core.Tests\packages.SharpBlueprint.Core.Tests.config",
    ".\test\SharpBlueprint.Core.Tests\packages.SharpBlueprint.Core.Net35.Tests.config"

) | foreach {
    # packages are restored into single "packages" folder in solution's root
    &$nugetExe restore (Resolve-Path $_) -PackagesDirectory "$solutionRoot\packages"
}

#
# ensure that psake is not in context for safe importing
remove-module [p]sake

#
# TODO: ...
#
Import-Module ((Find-PackagePath ".\packages\" "psake") + "\tools\psake.psm1")

# TODO: consider to get hard-coded params like"Release", "Any CPU" etc. from environment (ex. AppVeyor) 
Invoke-psake -buildFile .\build\default.ps1 `
             -taskList Test `
             -properties @{
                 "buildConfiguration" = "Release"
                 "buildPlatform" = "Any CPU"} `
             -parameters @{
                 "solutionFile" = "..\SharpBlueprint.sln"}

Write-Host "Build exit code:" $LastExitCode

# Propagating the exit code so that builds actually fail when there is a problem
exit $LastExitCode
#>