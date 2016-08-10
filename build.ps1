. (".\build\restore_packages.ps1")

(Restore-Packages "SharpBlueprint.sln" "packages.config")
(Restore-Packages "SharpBlueprint.sln" "test\SharpBlueprint.Core.Tests\packages.SharpBlueprint.Core.Tests.config")
(Restore-Packages "SharpBlueprint.sln" "test\SharpBlueprint.Core.Tests\packages.SharpBlueprint.Core.Net35.Tests.config")

if ($lastExitCode -ne 0) { exit $lastExitCode }

if ($env:APPVEYOR -eq "True")
{
    Write-Host "This is AppVeyor environment"
}

# '[p]sake' is the same as 'psake' but $Error is not polluted
remove-module [p]sake

# find psake's path
$psakeModule = (Get-ChildItem (".\packages\psake*\tools\psake.psm1")).FullName | Sort-Object $_ | Select -Last 1
 
#if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode) }

Import-Module $psakeModule

# you can put arguments to task in multiple lines using `
Invoke-psake -buildFile .\build\default.ps1 `
             -taskList Test `
             -properties @{ 
                 "buildConfiguration" = "Debug"
                 "buildPlatform" = "Any CPU"} `
             -parameters @{ 
                 "solutionFile" = "..\SharpBlueprint.sln"}

Write-Host "Build exit code:" $LastExitCode

# Propagating the exit code so that builds actually fail when there is a problem
exit $LastExitCode