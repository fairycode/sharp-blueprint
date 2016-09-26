<#
.SYNOPSIS
This is custom Powershell script to bootstrap a Cake build.
.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake)
and execute your Cake build script with the parameters you provide.
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

$toolPath = Join-Path $solutionRoot "tools"
if (!(Test-Path $toolPath)) {
    Write-Verbose "Creating tools directory..."
    New-Item -Path $ToolPath -Type directory | Out-Null
}

###########################################################################
# Install .NET Core SDK
###########################################################################

$dotnetVersionUri = "https://dotnetcli.blob.core.windows.net/dotnet/Sdk/rel-1.0.0/latest.version"
$dotnetInstallerUri = "https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0/scripts/obtain/dotnet-install.ps1"

$dotnetPath = Join-Path $solutionRoot ".dotnet"
$dotnetExe = Join-Path $dotnetPath "dotnet"
$dotnetVersionFound = $null
$dotnetVersionLatest = $null

if (Get-Command $dotnetExe -ErrorAction SilentlyContinue)
{
    $dotnetVersionFound = & $dotnetExe --version

    # check what is the latest version of .NET Core SDK
    try
    {
        $response = (New-Object System.Net.WebClient).DownloadString($dotnetVersionUri);
        if ($response -ne "")
        {
            $dotnetVersionLatest = (-split $response) | select -last 1
        }
    }
    catch [Exception]
    {
        Write-Host "Can't check the version of the latest .NET Core SDK: $_"
    }

    $msgFoundVersion = "Found .NET Core SDK version $dotnetVersionFound"

    if ($dotnetVersionFound -eq $dotnetVersionLatest)
    {
        $msgFoundVersion += " (latest)"
    }

    Write-Host $msgFoundVersion
}

if (
    # .NET Core SDK is not present
    ($dotnetVersionFound -eq $null) -or `
    # .NET Core SDK presents but is not of the latest version
    (($dotnetVersionLatest -ne $null) -and ($dotnetVersionFound -ne $dotnetVersionLatest)))
{
    Write-Host "Installing the latest .NET Core SDK..."

    if (Test-Path $dotnetPath)
    {
        Remove-Item $dotnetPath -Force -Recurse
    }

    if (!(Test-Path $dotnetPath)) {
        New-Item $dotnetPath -ItemType Directory | Out-Null
    }

    (New-Object System.Net.WebClient).DownloadFile($dotnetInstallerUri, "$dotnetPath\dotnet-install.ps1") | Out-Null
    & $dotnetPath\dotnet-install.ps1 -Version latest -InstallDir $dotnetPath -NoPath | Out-Null

    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    $env:DOTNET_CLI_TELEMETRY_OPTOUT=1
}

if (Get-Command $dotnetExe -ErrorAction SilentlyContinue)
{
    $env:PATH = "$dotnetPath;$env:PATH"
}

###########################################################################
# Install Cake
###########################################################################

$cakeVersion = "0.16.1"
$cakeExe = Join-Path $toolPath "cake.coreclr/$cakeVersion/Cake.dll"
$cakeFeed = "https://api.nuget.org/v3/index.json"

if (!(Test-Path $cakeExe)) {
    Write-Host "Installing Cake..."
    Invoke-Expression "&`"$dotnetExe`" restore `"$toolPath`" --packages `"$toolPath`" -f `"$cakeFeed`"" | Out-Null;    
    if ($LastExitCode -ne 0) {
        Throw "An error occured while installing Cake."
    }
}

###########################################################################
# Run build script
###########################################################################

$arguments = @{
    target=$target;
    configuration=$configuration;
    verbosity=$verbosity;
}.GetEnumerator() | %{"--{0}=`"{1}`"" -f $_.key, $_.value };

# Start Cake
Invoke-Expression "&`"$dotnetExe`" `"$cakeExe`" `"build.cake`" $arguments $scriptArgs";
exit $LastExitCode