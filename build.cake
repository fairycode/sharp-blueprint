// load scripts to support build session
#load "./build/parameters.cs"

var parameters = BuildParameters.GetParameters(Context);
var publishingError = false;

Setup(context =>
{
    parameters.Initialize(context);

    Information("Building version {0} of SharpBlueprint.Client ({1}, {2}, IsTagged: {3})",
    parameters.Version.SemVersion,
    parameters.Configuration,
    parameters.Target,
    parameters.IsTagged);
});

Task("Clean")
    .Does(() =>
{
    CleanDirectories(parameters.Paths.Directories.ToClean);
});

Task("Patch-Project-Json")
    .IsDependentOn("Clean")
    .Does(() =>
{
    var projects = GetFiles("./src/**/project.json");
    foreach(var project in projects)
    {
        if(!parameters.Version.PatchProjectJson(project)) {
            Warning("No version specified in {0}.", project.FullPath);
        }
    }
});

Task("Restore-NuGet-Packages")
    .IsDependentOn("Clean")
    .Does(() =>
{
    DotNetCoreRestore("./", new DotNetCoreRestoreSettings
    {
        Verbose = false,
        Verbosity = DotNetCoreRestoreVerbosity.Warning,
        Sources = new [] {
            "https://api.nuget.org/v3/index.json"
        }
    });
});

Task("Build")
    .IsDependentOn("Patch-Project-Json")
    .IsDependentOn("Restore-NuGet-Packages")
    .Does(() =>
{
    var srcProjects = GetFiles("./src/**/*.xproj");
    foreach(var project in srcProjects)
    {
        Information(project.FullPath);
        DotNetCoreBuild(project.GetDirectory().FullPath, new DotNetCoreBuildSettings {
            VersionSuffix = parameters.Version.DotNetAsterix,
            Configuration = parameters.Configuration
        });
    }

    var testProjects = GetFiles("./test/**/*.xproj");
    foreach(var project in testProjects)
    {
        Information(project.FullPath);
        DotNetCoreBuild(project.GetDirectory().FullPath, new DotNetCoreBuildSettings {
            VersionSuffix = parameters.Version.DotNetAsterix,
            Configuration = parameters.Configuration
        });
    }
});

Task("Run-Unit-Tests")
    .IsDependentOn("Build")
    .Does(() =>
{
    var projects = GetFiles("./test/**/*.Tests.xproj");
    foreach(var project in projects)
    {
        if(IsRunningOnWindows())
        {
            var apiUrl = EnvironmentVariable("APPVEYOR_API_URL");
            try
            {
                if (!string.IsNullOrEmpty(apiUrl))
                {
                    // Disable XUnit AppVeyorReporter see https://github.com/cake-build/cake/issues/1200
                    System.Environment.SetEnvironmentVariable("APPVEYOR_API_URL", null);
                }

                Action<ICakeContext> testAction = tool => {
                    tool.DotNetCoreTest(project.GetDirectory().FullPath, new DotNetCoreTestSettings {
                        Configuration = parameters.Configuration,
                        NoBuild = true,
                        Verbose = false,
                        ArgumentCustomization = args =>
                            args.Append("-xml").Append(parameters.Paths.Directories.TestResults.CombineWithFilePath(project.GetFilenameWithoutExtension()).FullPath + ".xml")
                    });};

                if(!parameters.SkipOpenCover)
                {
                    OpenCover(testAction,
                        parameters.Paths.Files.TestCoverageOutputFilePath,
                        new OpenCoverSettings {
                            ReturnTargetCodeOffset = 0,
                            ArgumentCustomization = args => args.Append("-mergeoutput")
                        }
                        .WithFilter("+[*]* -[nunit.*]* -[xunit.*]* -[*.Tests]*")
                        .ExcludeByAttribute("*.ExcludeFromCodeCoverage*")
                        .ExcludeByFile("*/*Designer.cs;*/*.g.cs;*/*.g.i.cs"));
                }
                else
                {
                    testAction(Context);
                }
            }
            finally
            {
                if (!string.IsNullOrEmpty(apiUrl))
                {
                    System.Environment.SetEnvironmentVariable("APPVEYOR_API_URL", apiUrl);
                }
            }
        }
        else
        {
            var name = project.GetFilenameWithoutExtension();
            var dirPath = project.GetDirectory().FullPath;
            var config = parameters.Configuration;
            var xunit = GetFiles(dirPath + "/bin/" + config + "/net452/*/dotnet-test-xunit.exe").First().FullPath;
            var testfile = GetFiles(dirPath + "/bin/" + config + "/net452/*/" + name + ".dll").First().FullPath;

            using(var process = StartAndReturnProcess("mono", new ProcessSettings{ Arguments = xunit + " " + testfile }))
            {
                process.WaitForExit();
                if (process.GetExitCode() != 0)
                {
                    throw new Exception("Mono tests failed!");
                }
            }
        }
    }

    // Generate the HTML version of the Code Coverage report if the XML file exists
    if(FileExists(parameters.Paths.Files.TestCoverageOutputFilePath))
    {
        ReportGenerator(parameters.Paths.Files.TestCoverageOutputFilePath, parameters.Paths.Directories.TestResults);
    }
});

Task("Create-NuGet-Packages")
    .IsDependentOn("Run-Unit-Tests")
    .Does(() =>
{
    // Build libraries
    var projects = GetFiles("./src/**/*.xproj");
    foreach(var project in projects)
    {
        DotNetCorePack(project.GetDirectory().FullPath, new DotNetCorePackSettings {
            VersionSuffix = parameters.Version.DotNetAsterix,
            Configuration = parameters.Configuration,
            OutputDirectory = parameters.Paths.Directories.NugetRoot,
            NoBuild = true,
            Verbose = false
        });
    }
});

Task("Upload-AppVeyor-Artifacts")
    .IsDependentOn("Create-NuGet-Packages")
    .WithCriteria(() => parameters.IsRunningOnAppVeyor)
    .Does(() =>
{
    foreach(var package in GetFiles(parameters.Paths.Directories.NugetRoot + "/*"))
    {
        AppVeyor.UploadArtifact(package);
    }
});
/*
Task("Upload-Coverage-Report")
    .WithCriteria(() => FileExists(parameters.Paths.Files.TestCoverageOutputFilePath))
    .WithCriteria(() => !parameters.IsLocalBuild)
    .WithCriteria(() => !parameters.IsPullRequest)
    .IsDependentOn("Run-Unit-Tests")
    .Does(() =>
{
    CoverallsIo(parameters.Paths.Files.TestCoverageOutputFilePath, new CoverallsIoSettings()
    {
        RepoToken = parameters.Coveralls.RepoToken
    });
});
*/
Task("Publish-MyGet")
    .IsDependentOn("Package")
    .WithCriteria(() => parameters.ShouldPublishToMyGet)
    .Does(() =>
{
    // resolve MyGet API key
    var apiKey = EnvironmentVariable("MYGET_API_KEY");
    if(string.IsNullOrEmpty(apiKey)) {
        throw new InvalidOperationException("Could not resolve MyGet API key.");
    }

    // resolve MyGet API url
    var apiUrl = EnvironmentVariable("MYGET_API_URL");
    if(string.IsNullOrEmpty(apiUrl)) {
        throw new InvalidOperationException("Could not resolve MyGet API url.");
    }

    foreach(var package in parameters.Packages.Nuget)
    {
        // Push the package.
        NuGetPush(package.PackagePath, new NuGetPushSettings {
            Source = apiUrl,
            ApiKey = apiKey
        });
    }
})
.OnError(exception =>
{
    Information("Error: " + exception.Message);
    Information("Publish-MyGet Task failed, but continuing with next Task...");
    publishingError = true;
});

Task("Publish-NuGet")
    .IsDependentOn("Create-NuGet-Packages")
    .WithCriteria(() => parameters.ShouldPublish)
    .Does(() =>
{
    // resolve NuGet API key
    var apiKey = EnvironmentVariable("NUGET_API_KEY");
    if(string.IsNullOrEmpty(apiKey)) {
        throw new InvalidOperationException("Could not resolve NuGet API key.");
    }

    // resolve NuGet API url
    var apiUrl = EnvironmentVariable("NUGET_API_URL");
    if(string.IsNullOrEmpty(apiUrl)) {
        throw new InvalidOperationException("Could not resolve NuGet API url.");
    }

    foreach(var package in parameters.Packages.Nuget)
    {
        // push the package
        NuGetPush(package.PackagePath, new NuGetPushSettings {
          ApiKey = apiKey,
          Source = apiUrl
        });
    }
})
.OnError(exception =>
{
    Information("Error: " + exception.Message);
    Information("Publish-NuGet Task failed, but continuing with next Task...");
    publishingError = true;
});

Task("Publish-GitHub-Release")
    .WithCriteria(() => parameters.ShouldPublish)
    .Does(() =>
{
    GitReleaseManagerClose(parameters.GitHub.UserName, parameters.GitHub.Password, "fairycode", "sharp-blueprint", parameters.Version.Milestone);
})
.OnError(exception =>
{
    Information("Error: " + exception.Message);
    Information("Publish-GitHub-Release Task failed, but continuing with next Task...");
    publishingError = true;
});

Task("Create-Release-Notes")
    .Does(() =>
{
    GitReleaseManagerCreate(parameters.GitHub.UserName, parameters.GitHub.Password, "fairycode", "sharp-blueprint", new GitReleaseManagerCreateSettings {
        Milestone         = parameters.Version.Milestone,
        Name              = parameters.Version.Milestone,
        Prerelease        = true,
        TargetCommitish   = "main"
    });
});

//
// Task Targets
//

Task("Package")
    .IsDependentOn("Create-NuGet-Packages");

Task("Default")
    .IsDependentOn("Package");

Task("AppVeyor")
    .IsDependentOn("Upload-AppVeyor-Artifacts")
    /*.IsDependentOn("Upload-Coverage-Report")*/
    .IsDependentOn("Publish-MyGet")
    .IsDependentOn("Publish-NuGet")
    .IsDependentOn("Publish-GitHub-Release")
    .Finally(() =>
{
    if(publishingError)
    {
        throw new Exception("An error occurred during the publishing of Cake. All publishing tasks have been attempted.");
    }
});

Task("ReleaseNotes")
    .IsDependentOn("Create-Release-Notes");

//
// Run build tasks
//
RunTarget(parameters.Target);