using System;
using System.Text;
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

    public static BuildVersion Calculate(ICakeContext context, BuildParameters parameters)
    {
        if (context == null)
        {
            throw new ArgumentNullException("context");
        }

        string version = null;
        string semVersion = null;
        string milestone = null;

        if (parameters.IsRunningOnWindows && !parameters.SkipGitVersion)
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

        return new BuildVersion
        {
            Version = version,
            SemVersion = semVersion,
            DotNetAsterix = semVersion.Substring(version.Length).TrimStart('-'),
            Milestone = milestone
        };
    }

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