using System;
using System.Text;
using System.Reflection;
using Cake.Core;
using Cake.Core.IO;
using Cake.Common;
using Cake.Common.Diagnostics;
using Cake.Common.Tools.GitVersion;

public class BuildVersion
{
    public string Version { get; private set; }
    public string SemVersion { get; private set; }
    public string DotNetAsterix { get; private set; }
    public string Milestone { get; private set; }
    public string CakeVersion { get; private set; }

    public static BuildVersion Calculate(ICakeContext context, BuildParameters parameters)
    {
        if (context == null)
        {
            throw new ArgumentNullException("context");
        }

        string version = null;
        string semVersion = null;
        string milestone = null;

        // TODO: use parameters.IsRunningOnWindows???
        if (context.IsRunningOnWindows() && !parameters.SkipGitVersion)
        {
            context.Information("Calculating Semantic Version");
            if (!parameters.IsLocalBuild || parameters.IsPublishBuild || parameters.IsReleaseBuild)
            {
                context.GitVersion(new GitVersionSettings
                {
                    UpdateAssemblyInfoFilePath = "./src/SharpBlueprint.Client/Properties/AssemblyInfo.cs",
                    UpdateAssemblyInfo = true,
                    OutputType = GitVersionOutput.BuildServer
                });

                version = context.EnvironmentVariable("GitVersion_MajorMinorPatch");
                semVersion = context.EnvironmentVariable("GitVersion_LegacySemVerPadded");
                milestone = string.Concat("v", version);
            }

            var assertedVersions = context.GitVersion(new GitVersionSettings
            {
                OutputType = GitVersionOutput.Json,
            });

            version = assertedVersions.MajorMinorPatch;
            semVersion = assertedVersions.LegacySemVerPadded;
            milestone = string.Concat("v", version);

            context.Information("Calculated Semantic Version: {0}", semVersion);
        }

        if (string.IsNullOrEmpty(version) || string.IsNullOrEmpty(semVersion))
        {
            context.Information("Fetching version from first project.json...");
            //version = ReadProjectJsonVersion(context);
            semVersion = version;
            milestone = string.Concat("v", version);
        }

        var cakeVersion = typeof(ICakeContext).GetTypeInfo().Assembly.GetName().Version.ToString();

        return new BuildVersion
        {
            Version = version,
            SemVersion = semVersion,
            DotNetAsterix = semVersion.Substring(version.Length).TrimStart('-'),
            Milestone = milestone,
            CakeVersion = cakeVersion
        };
    }

/*
    public static string ReadProjectJsonVersion(ICakeContext context)
    {
        var projects = context.GetFiles("./*#1#project.json");
        foreach (var project in projects)
        {
            var content = System.IO.File.ReadAllText(project.FullPath, Encoding.UTF8);

            var node = Newtonsoft.Json.Linq.JObject.Parse(content);
            if (node["version"] != null)
            {
                var version = node["version"].ToString();
                return version.Replace("-*", "");
            }
        }
        throw new CakeException("Could not parse version.");
    }
*/

    public bool PatchProjectJson(FilePath project)
    {
        var content = System.IO.File.ReadAllText(project.FullPath, Encoding.UTF8);

        var versionStartPos = content.IndexOf("\"version\"", StringComparison.OrdinalIgnoreCase);
        var versionEndPos = content.IndexOf(",", versionStartPos, StringComparison.OrdinalIgnoreCase);

        if (versionStartPos == -1 || versionEndPos <= versionStartPos) return false;

        var newContent =
            new StringBuilder(content)
                .Remove(versionStartPos, versionEndPos - versionStartPos)
                .Insert(versionStartPos, string.Format(System.Globalization.CultureInfo.InvariantCulture, "\"version\": \"{0}\"", Version))
                .ToString();

        System.IO.File.WriteAllText(project.FullPath, newContent, Encoding.UTF8);

        return true;
    }
}