#tool nuget:?package=OpenCover&version=4.6.519
#tool nuget:?package=ReportGenerator&version=2.5.8

var target = Context.Argument("target", "Default");

var configuration =
    HasArgument("Configuration") ? Argument<string>("Configuration") :
    EnvironmentVariable("Configuration") != null ? EnvironmentVariable("Configuration") : "Release";

var buildSystem = Context.BuildSystem();

var isLocalBuild = buildSystem.IsLocalBuild;
var isRunningOnAppVeyor = buildSystem.AppVeyor.IsRunningOnAppVeyor;
var isRunningOnWindows = Context.IsRunningOnWindows();

var isPullRequest = buildSystem.AppVeyor.Environment.PullRequest.IsPullRequest;
var isBuildTagged = IsBuildTagged(buildSystem);

var buildNumber =
    HasArgument("BuildNumber") ? Argument<int>("BuildNumber") :
    isRunningOnAppVeyor ? AppVeyor.Environment.Build.Number :
    EnvironmentVariable("BuildNumber") != null ? int.Parse(EnvironmentVariable("BuildNumber")) : 0;

var artifactsDir = Directory("./artifacts");
var testResultsDir = Directory("./artifacts/test-results");
var nugetDir = System.IO.Path.Combine(artifactsDir, "nuget");

//
// Tasks
//

Task("Info")
    .Does(() =>
{
    Information("Target: {0}", target);
    Information("Configuration: {0}", configuration);
    Information("Build number: {0}", buildNumber);

    var projects = GetFiles("./src/**/*.csproj");

    foreach (var project in projects) {
        Information("{0} version: {1}", project.GetFilenameWithoutExtension(), GetVersion(project.FullPath));
    }
});

Task("Clean")
    .Does(() =>
{
    CleanDirectory(artifactsDir);
});

Task("Restore-Packages")
    .Does(() =>
{
    DotNetCoreRestore();
});

Task("Build")
    .IsDependentOn("Info")
    .IsDependentOn("Clean")
    .IsDependentOn("Restore-Packages")
    .Does(() =>
{
    var projects = GetFiles("./src/**/*.csproj");
    projects.Add(GetFiles("./test/**/*.csproj"));

    foreach (var project in projects)
    {
        DotNetCoreBuild(project.FullPath,
            new DotNetCoreBuildSettings
            {
                Configuration = configuration,
                ArgumentCustomization = args => args.Append("/p:DebugType=full /p:DebugSymbols=True")
            }
        );
    }
});

Task("Run-Unit-Tests")
    .IsDependentOn("Build")
    .Does(() =>
{
    var testProject = new FilePath("./test/SharpBlueprint.Client.Tests/SharpBlueprint.Client.Tests.csproj");
    var workingDirectory = MakeAbsolute(new DirectoryPath("./test/SharpBlueprint.Client.Tests")).FullPath;

    var testActions = new List<Action<ICakeContext>>();
    var dotnetCmd = isRunningOnWindows ? "dotnet.exe" : "dotnet";

    testActions.Add(tool => {
        using (var process = tool.StartAndReturnProcess(
            dotnetCmd,
            new ProcessSettings {
                Arguments = "xunit -f netcoreapp1.1 -nobuild -c " + configuration,
                WorkingDirectory = workingDirectory
            }
        ))
        {
            process.WaitForExit();
            if (process.GetExitCode() != 0)
                throw new Exception("Tests for netcoreapp1.1 have failed!");
        }
    });

    testActions.Add(tool => {
        using (var process = tool.StartAndReturnProcess(
            dotnetCmd,
            new ProcessSettings {
                Arguments = "xunit -f net452 -nobuild -noshadow -c " + configuration,
                WorkingDirectory = workingDirectory
            }
        ))
        {
            process.WaitForExit();
            if (process.GetExitCode() != 0)
                throw new Exception("Tests for net452 have failed!");
        }
    });

    EnsureDirectoryExists(testResultsDir);

    // OpenCover works only on Windows
    if (isRunningOnWindows)
    {
        var openCoverXml = MakeAbsolute(testResultsDir.Path.CombineWithFilePath("OpenCover").AppendExtension("xml"));;
        var coverageReportDir = System.IO.Path.Combine(testResultsDir, "report");

        var settings = new OpenCoverSettings
        {
            Register = "user",
            ReturnTargetCodeOffset = 0,
            WorkingDirectory = workingDirectory,
            ArgumentCustomization =
                args =>
                    args.Append(
                        "-skipautoprops -mergebyhash -mergeoutput -oldstyle -hideskipped:All")
        }
        .WithFilter("+[*]* -[xunit.*]* -[*.Tests]*")
        .ExcludeByAttribute("*.ExcludeFromCodeCoverage*")
        .ExcludeByFile("*/*Designer.cs;*/*.g.cs;*/*.g.i.cs");

        foreach (var testAction in testActions)
            OpenCover(testAction, openCoverXml, settings);

        // for non-local build coverage is uploaded to codecov.io so no need to generate the report
        if (FileExists(openCoverXml) && isLocalBuild)
        {
            ReportGenerator(openCoverXml, coverageReportDir,
                new ReportGeneratorSettings {
                    ArgumentCustomization = args => args.Append("-reporttypes:html")
                }
            );
        }
    }
    else
    {
        foreach (var testAction in testActions)
            testAction(Context);
    }
});

Task("Publish-Coverage")
    .IsDependentOn("Run-Unit-Tests")
    .WithCriteria(() => !isLocalBuild && !isPullRequest)
    .Does(() =>
{
    var openCoverXml = MakeAbsolute(testResultsDir.Path.CombineWithFilePath("OpenCover").AppendExtension("xml"));;
    if (!FileExists(openCoverXml))
        throw new Exception("Missing \"" + openCoverXml + "\" file");

    UploadCoverageReport(Context, openCoverXml.FullPath);
})
.OnError(exception =>
{
    Information("Error: " + exception.Message);
});

Task("Create-Packages")
    .IsDependentOn("Run-Unit-Tests")
    .Does(() =>
{
    var projects = GetFiles("./src/**/*.csproj");

    foreach (var project in projects)
    {
        DotNetCorePack(
            project.GetDirectory().FullPath,
            new DotNetCorePackSettings()
            {
                Configuration = configuration,
                OutputDirectory = nugetDir,
                ArgumentCustomization = args => args.Append("--include-symbols")
            });
    }
});

Task("Publish-MyGet")
    .IsDependentOn("Create-Packages")
    .WithCriteria(() => !isLocalBuild && !isPullRequest && !isBuildTagged)
    .Does(() =>
{
    var serverUrl = EnvironmentVariable("MYGET_SERVER_URL");
    if (string.IsNullOrEmpty(serverUrl))
        throw new InvalidOperationException("Could not resolve MyGet server URL");

    var apiKey = EnvironmentVariable("MYGET_API_KEY");
    if (string.IsNullOrEmpty(apiKey))
        throw new InvalidOperationException("Could not resolve MyGet API key");

    foreach (var package in GetFiles(nugetDir + "/*.nupkg"))
    {
        // symbols packages are pushed alongside regular ones so no need to push them explicitly
        if (package.FullPath.EndsWith("symbols.nupkg", StringComparison.OrdinalIgnoreCase))
            continue;

        NuGetPush(package.FullPath, new NuGetPushSettings {
            Source = serverUrl,
            ApiKey = apiKey
        });
    }
})
.OnError(exception =>
{
    Information("Error: " + exception.Message);
});

Task("Publish-NuGet")
    .IsDependentOn("Create-Packages")
    .WithCriteria(() => !isLocalBuild && !isPullRequest && isBuildTagged)
    .Does(() =>
{
    var serverUrl = EnvironmentVariable("NUGET_SERVER_URL");
    if (string.IsNullOrEmpty(serverUrl))
        throw new InvalidOperationException("Could not resolve NuGet server URL");

    var apiKey = EnvironmentVariable("NUGET_API_KEY");
    if (string.IsNullOrEmpty(apiKey))
        throw new InvalidOperationException("Could not resolve NuGet API key");

    foreach (var package in GetFiles(nugetDir + "/*.nupkg"))
    {
        // symbols packages are pushed alongside regular ones so no need to push them explicitly
        if (package.FullPath.EndsWith("symbols.nupkg", StringComparison.OrdinalIgnoreCase))
            continue;

        NuGetPush(package.FullPath, new NuGetPushSettings {
            Source = serverUrl,
            ApiKey = apiKey
        });
    }
})
.OnError(exception =>
{
    Information("Error: " + exception.Message);
});

//
// Targets
//

Task("Default")
    .IsDependentOn("Create-Packages")
    .IsDependentOn("Publish-Coverage")
    .IsDependentOn("Publish-MyGet")
    .IsDependentOn("Publish-NuGet");

//
// Run build
//

RunTarget(target);


// **********************************************
// ***               Utilities                ***
// **********************************************

/// <summary>
/// Checks if build is tagged.
/// </summary>
private static bool IsBuildTagged(BuildSystem buildSystem)
{
    return buildSystem.AppVeyor.Environment.Repository.Tag.IsTag
           && !string.IsNullOrWhiteSpace(buildSystem.AppVeyor.Environment.Repository.Tag.Name);
}

/// <summary>
/// Gets version from "Version" node of csproj file.
/// </summary>
private static string GetVersion(string csproj)
{
    using (var reader = System.Xml.XmlReader.Create(csproj))
    {
        reader.MoveToContent();
        while (reader.Read())
            if (reader.NodeType == System.Xml.XmlNodeType.Element &&
                reader.LocalName.Equals("Version", StringComparison.OrdinalIgnoreCase))
                return reader.ReadElementContentAsString();
    }
    return null;
}

/// <summary>
/// Uploads coverage report (OpenCover.xml) to codecov.io.
/// </summary>
public static void UploadCoverageReport(ICakeContext context, string openCoverXml)
{
    const string url = "https://codecov.io/upload/v2";

    // query parameters: https://github.com/codecov/codecov-bash/blob/master/codecov#L1202
    var queryBuilder = new System.Text.StringBuilder(url);
    queryBuilder.Append("?package=bash-tbd&service=appveyor");
    queryBuilder.Append("&branch=").Append(context.EnvironmentVariable("APPVEYOR_REPO_BRANCH"));
    queryBuilder.Append("&commit=").Append(context.EnvironmentVariable("APPVEYOR_REPO_COMMIT"));
    queryBuilder.Append("&build=").Append(context.EnvironmentVariable("APPVEYOR_JOB_ID"));
    queryBuilder.Append("&pr=").Append(context.EnvironmentVariable("APPVEYOR_PULL_REQUEST_NUMBER"));
    queryBuilder.Append("&job=").Append(context.EnvironmentVariable("APPVEYOR_ACCOUNT_NAME"));
    queryBuilder.Append("%2F").Append(context.EnvironmentVariable("APPVEYOR_PROJECT_SLUG"));
    queryBuilder.Append("%2F").Append(context.EnvironmentVariable("APPVEYOR_BUILD_VERSION"));
    queryBuilder.Append("&token=").Append(context.EnvironmentVariable("CODECOV_TOKEN"));

    var request = (System.Net.HttpWebRequest) System.Net.WebRequest.Create(queryBuilder.ToString());
    request.Accept = "text/plain";
    request.Method = "POST";

    using (var requestStream = request.GetRequestStream())
    using (var openCoverXmlStream = new System.IO.FileStream(openCoverXml, System.IO.FileMode.Open, System.IO.FileAccess.Read))
    {
        var buffer = new byte[1024];
        int readBytes;
        while ((readBytes = openCoverXmlStream.Read(buffer, 0, buffer.Length)) > 0)
            requestStream.Write(buffer, 0, readBytes);
    }

    using (var response = (System.Net.HttpWebResponse) request.GetResponse())
    {
        if (response.StatusCode == System.Net.HttpStatusCode.OK)
        {
            using (var responseStream = response.GetResponseStream())
            {
                if (responseStream != null)
                {
                    using (var responseStreamReader = new System.IO.StreamReader(responseStream))
                        context.Information(responseStreamReader.ReadToEnd());
                }
            }
        }
        else
        {
            context.Information("Status code: " + response.StatusCode);
        }
    }
}
