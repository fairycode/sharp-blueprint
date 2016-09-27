<#
.SYNOPSIS
This is custom Powershell script to bootstrap a Cake build.
.DESCRIPTION
This Powershell script will download .NET Core SDK if missing, restore packages
for build tools (including Cake) and execute Cake build script.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER ScriptArgs
Remaining arguments are added here.
.LINK
http://cakebuild.net
#>

[CmdletBinding()]
Param(
    [string]$target = "Default",

    [ValidateSet("Release", "Debug")]
    [string]$configuration = "Release",

    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$verbosity = "Verbose",

    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$scriptArgs
)

$solutionRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

###########################################################################
# Prepare .NET Core SDK
###########################################################################

$dotnetVersion = "1.0.0-preview2-003121"
$dotnetInstallerUri = "https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0-preview2/scripts/obtain/dotnet-install.ps1"

$dotnetPath = Join-Path $solutionRoot ".dotnet"
$dotnetExe = Join-Path $dotnetPath "dotnet.exe"
$dotnetVersionFound = $null

if (Get-Command $dotnetExe -ErrorAction SilentlyContinue)
{
    $dotnetVersionFound = & $dotnetExe --version

    Write-Host "Found .NET Core SDK version $dotnetVersionFound"
}

if (
    # .NET Core SDK is not present
    ($dotnetVersionFound -eq $null) -or `
    # .NET Core SDK presents but is not of the version we want to go with
    (($dotnetVersion -ne $null) -and ($dotnetVersion -ne $dotnetVersionFound)))
{
    Write-Host "Installing .NET Core SDK version $dotnetVersion..."

    if (Test-Path $dotnetPath)
    {
        Remove-Item $dotnetPath -Force -Recurse
    }

    if (!(Test-Path $dotnetPath)) {
        New-Item $dotnetPath -ItemType Directory | Out-Null
    }

    (New-Object System.Net.WebClient).DownloadFile($dotnetInstallerUri, "$dotnetPath\dotnet-install.ps1") | Out-Null
    & $dotnetPath\dotnet-install.ps1 -Version $dotnetVersion -InstallDir $dotnetPath -NoPath | Out-Null

    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    $env:DOTNET_CLI_TELEMETRY_OPTOUT=1
}

# ensure that local version of .NET Core SDK (from .dotnet folder) is in use
if (Get-Command $dotnetExe -ErrorAction Stop)
{
    $dotnetCommandSource = (Get-Command dotnet –ErrorAction SilentlyContinue).Source

    if ($dotnetExe -ne $dotnetCommandSource)
    {
        $env:PATH = "$dotnetPath;$env:PATH"
    }
}

###########################################################################
# Prepare Cake and build tools
###########################################################################

$buildPath = Join-Path $solutionRoot "build"
$toolsPath = Join-Path $solutionRoot "tools"

$toolsProjectJson = Join-Path $toolsPath "project.json"
$toolsProjectJsonSource = Join-Path $buildPath "project_build_tools.json"

$cakeFeed = "https://api.nuget.org/v3/index.json"

# make sure tools folder exists
if (!(Test-Path $toolsPath))
{
    Write-Verbose -Message "Creating tools directory..."
    New-Item -Path $toolsPath -Type directory | Out-Null
}

# project.json defines packages used in build process
Write-Verbose -Message "Copying project.json from $toolsProjectJsonSource"
Copy-Item $toolsProjectJsonSource $toolsProjectJson –ErrorAction Stop

Write-Host "Preparing Cake and build tools..."
Invoke-Expression "&dotnet restore `"$toolsPath`" --packages `"$toolsPath`" -f `"$cakeFeed`"" | Out-Null;
if ($LastExitCode -ne 0)
{
    throw "Error occured while preparing Cake."
}

$cakeExe = (Get-ChildItem (Join-Path $toolsPath "Cake.CoreCLR/*/Cake.dll") –ErrorAction Stop).FullName |
            Sort-Object $_ |
            Select-Object -Last 1

###########################################################################
# Run build script
###########################################################################

$arguments = @{
    target=$target;
    configuration=$configuration;
    verbosity=$verbosity;
}.GetEnumerator() | %{"--{0}=`"{1}`"" -f $_.key, $_.value };

# Start Cake
Invoke-Expression "&dotnet `"$cakeExe`" `"build.cake`" $arguments $scriptArgs";
exit $LastExitCode