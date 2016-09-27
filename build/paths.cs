using System;
using System.Collections.Generic;
using System.Linq;
using Cake.Core;
using Cake.Core.IO;
using Cake.Common;
using Cake.Common.IO;

public class BuildPaths
{
    public BuildFiles Files { get; private set; }
    public BuildDirectories Directories { get; private set; }

    public static BuildPaths GetPaths(
        ICakeContext context,
        string configuration,
        string semVersion)
    {
        if (context == null)
        {
            throw new ArgumentNullException("context");
        }
        if (string.IsNullOrEmpty(configuration))
        {
            throw new ArgumentNullException("configuration");
        }
        if (string.IsNullOrEmpty(semVersion))
        {
            throw new ArgumentNullException("semVersion");
        }

        var buildDir = context.Directory("./src/SharpBlueprint.Client/bin") + context.Directory(configuration);
        var artifactsDir = (DirectoryPath)(context.Directory("./artifacts") + context.Directory("v" + semVersion));
        var artifactsBinDir = artifactsDir.Combine("bin");

        var artifactsBinNet35 = artifactsBinDir.Combine("net35");
        var artifactsBinNet452 = artifactsBinDir.Combine("net452");
        var artifactsBinNetStandard16 = artifactsBinDir.Combine("netstandard1.6");

        var testResultsDir = artifactsDir.Combine("test-results");
        var nugetRoot = artifactsDir.Combine("nuget");
        var testingDir = context.Directory("./test/SharpBlueprint.Client.Tests/bin") + context.Directory(configuration);

        var clientFiles = new FilePath[] {
            context.File("SharpBlueprint.Client.dll"),
            context.File("SharpBlueprint.Client.pdb"),
            context.File("Newtonsoft.Json.dll")
        };

        var clientAssemblyPaths = clientFiles.Concat(new FilePath[] { "LICENSE" })
            .Select(file => buildDir.Path.CombineWithFilePath(file))
            .ToArray();

        var testingAssemblyPaths = new FilePath[] {
            testingDir + context.File("SharpBlueprint.Client.Tests.dll"),
            testingDir + context.File("SharpBlueprint.Client.Tests.pdb"),
            testingDir + context.File("SharpBlueprint.Client.Tests.dll.config")
        };

        var repoFilesPaths = new FilePath[] {
            "LICENSE",
            "README.md",
            "ReleaseNotes.md"
        };

        var artifactSourcePaths = clientAssemblyPaths.Concat(testingAssemblyPaths.Concat(repoFilesPaths)).ToArray();

        var testCoverageOutputFilePath = testResultsDir.CombineWithFilePath("OpenCover.xml");

        // Directories
        var buildDirectories = new BuildDirectories(
            artifactsDir,
            testResultsDir,
            nugetRoot,
            artifactsBinDir,
            artifactsBinNet35,
            artifactsBinNet452,
            artifactsBinNetStandard16);

        // Files
        var buildFiles = new BuildFiles(
            context,
            clientAssemblyPaths,
            testingAssemblyPaths,
            repoFilesPaths,
            artifactSourcePaths,
            testCoverageOutputFilePath);

        return new BuildPaths
        {
            Files = buildFiles,
            Directories = buildDirectories
        };
    }
}

public class BuildFiles
{
    public ICollection<FilePath> ClientAssemblyPaths { get; private set; }
    public ICollection<FilePath> TestingAssemblyPaths { get; private set; }
    public ICollection<FilePath> RepoFilesPaths { get; private set; }
    public ICollection<FilePath> ArtifactsSourcePaths { get; private set; }
    public FilePath TestCoverageOutputFilePath { get; private set; }

    public BuildFiles(
        ICakeContext context,
        FilePath[] clientAssemblyPaths,
        FilePath[] testingAssemblyPaths,
        FilePath[] repoFilesPaths,
        FilePath[] artifactsSourcePaths,
        FilePath testCoverageOutputFilePath)
    {
        ClientAssemblyPaths = Filter(context, clientAssemblyPaths);
        TestingAssemblyPaths = Filter(context, testingAssemblyPaths);
        RepoFilesPaths = Filter(context, repoFilesPaths);
        ArtifactsSourcePaths = Filter(context, artifactsSourcePaths);
        TestCoverageOutputFilePath = testCoverageOutputFilePath;
    }

    private static FilePath[] Filter(ICakeContext context, FilePath[] files)
    {
        // filter out pdb files when building on OS that is not Windows (since they don't exist there)
        if (!context.IsRunningOnWindows())
        {
            return files.Where(f => !f.FullPath.EndsWith("pdb", StringComparison.OrdinalIgnoreCase)).ToArray();
        }
        return files;
    }
}

public class BuildDirectories
{
    public DirectoryPath Artifacts { get; private set; }
    public DirectoryPath TestResults { get; private set; }
    public DirectoryPath NugetRoot { get; private set; }
    public DirectoryPath ArtifactsBin { get; private set; }
    public DirectoryPath ArtifactsBinNet35 { get; private set; }
    public DirectoryPath ArtifactsBinNet452 { get; private set; }
    public DirectoryPath ArtifactsBinNetStandard16 { get; private set; }
    public ICollection<DirectoryPath> ToClean { get; private set; }

    public BuildDirectories(
        DirectoryPath artifactsDir,
        DirectoryPath testResultsDir,
        DirectoryPath nugetRoot,
        DirectoryPath artifactsBinDir,
        DirectoryPath artifactsBinNet35,
        DirectoryPath artifactsBinNet452,
        DirectoryPath artifactsBinNetStandard16)
    {
        Artifacts = artifactsDir;
        TestResults = testResultsDir;
        NugetRoot = nugetRoot;
        ArtifactsBin = artifactsBinDir;
        ArtifactsBinNet35 = artifactsBinNet35;
        ArtifactsBinNet452 = artifactsBinNet452;
        ArtifactsBinNetStandard16 = artifactsBinNetStandard16;
        ToClean = new[] {
            Artifacts,
            TestResults,
            NugetRoot,
            ArtifactsBin,
            ArtifactsBinNet35,
            ArtifactsBinNet452,
            ArtifactsBinNetStandard16
        };
    }
}