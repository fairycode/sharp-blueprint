function Restore-Packages
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)]$solutionFile,
        [Parameter(Position=1,Mandatory=1)]$packageConfigFile
    )

    $solutionDirectory = (Get-Item $solutionFile).DirectoryName

    Write-Host $solutionDirectory

    #$nugetExe = $executionContext.SessionState.Path. `
    #    GetUnresolvedProviderPathFromPSPath($solutionDirectory) + "\tools\nuget.exe"

    $nugetExe = "$solutionDirectory\tools\nuget.exe"

    $packagesPath = "$solutionDirectory\packages"

    if(!(Test-Path $nugetExe))
    {
        $toolsDirectory = Split-Path $nugetExe -Parent

        If(!(Test-Path $toolsDirectory))
        {
            New-Item $toolsDirectory -ItemType Directory | Out-Null
        }

        Write-Host "Downloading NuGet.exe (into $nugetExe)"

        Invoke-WebRequest "https://dist.nuget.org/win-x86-commandline/v3.4.4/NuGet.exe" -OutFile $nugetExe
    }

    &$nugetExe restore "$solutionDirectory\$packageConfigFile" -PackagesDirectory $packagesPath

    #if($LastExitCode -ne 0)
    #{
    #    throw ("Exec: " + ($msgs.error_bad_command -f $cmd))
    #}
}