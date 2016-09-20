// load scripts to support build session
#load "./build/parameters.cake"

var parameters = BuildParameters.GetParameters(Context);

Setup(context =>
{
    parameters.Initialize(context);

    Information("Building version {0} of SharpBlueprint.Client ({1}, {2}) using version {3} of Cake. (IsTagged: {4})",
    parameters.Version.SemVersion,
    parameters.Configuration,
    parameters.Target,
    parameters.Version.CakeVersion,
    parameters.IsTagged);
});

Task("Clean")
    .Does(() =>
{
    CleanDirectories(parameters.Paths.Directories.ToClean);
});

Task("Restore")
    .Does(() =>
{
    Information("Task Restore");
});

Task("Version")
    .Does(() =>
{
    Information("Task Version");
});

Task("Build")
    .IsDependentOn("Clean")
    .IsDependentOn("Restore")
    .IsDependentOn("Version")
    .Does(() =>
{
    Information("Task Build");
});

Task("Default")
    .IsDependentOn("Build");

RunTarget(parameters.Target);