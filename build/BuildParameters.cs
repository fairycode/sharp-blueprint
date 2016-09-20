using System;
using System.Collections.Generic;
using System.Linq;
using Cake.Core;
using Cake.Core.IO;
using Cake.Common;
using Cake.Common.IO;
using Cake.Common.Build;

namespace build
{
    public class BuildParameters
    {
        public string Target { get; private set; }
        public string Configuration { get; private set; }

        public bool IsLocalBuild { get; private set; }
        public bool IsRunningOnUnix { get; private set; }
        public bool IsRunningOnWindows { get; private set; }
        public bool IsRunningOnAppVeyor { get; private set; }

        public bool IsPullRequest { get; private set; }
        public bool IsMainClientBranch { get; private set; }
        public bool IsTagged { get; private set; }
        public bool IsPublishBuild { get; private set; }
        public bool IsReleaseBuild { get; private set; }

        public bool SkipGitVersion { get; private set; }
        public bool SkipOpenCover { get; private set; }

        public ReleaseNotes ReleaseNotes { get; private set; }
        public BuildVersion Version { get; private set; }
        public BuildPaths Paths { get; private set; }
        public BuildPackages Packages { get; private set; }


        public bool ShouldPublish
        {
            get
            {
                return !IsLocalBuild && !IsPullRequest && IsMainClientBranch && IsTagged;
            }
        }

        public bool ShouldPublishToMyGet
        {
            get
            {
                return !IsLocalBuild && !IsPullRequest && IsMainClientBranch && !IsTagged;
            }
        }

        public void Initialize(ICakeContext context)
        {
            Version = BuildVersion.Calculate(context, this);

            Paths = BuildPaths.GetPaths(context, Configuration, Version.SemVersion);

            Packages = BuildPackages.GetPackages(
                Paths.Directories.NugetRoot,
                Version.SemVersion,
                new[] { "SharpBlueprint.Client" });
        }

        public static BuildParameters GetParameters(ICakeContext context)
        {
            if (context == null)
            {
                throw new ArgumentNullException("context");
            }

            var target = context.Argument("target", "Default");
            var buildSystem = context.BuildSystem();

            return new BuildParameters
            {
                Target = target,
                Configuration = context.Argument("configuration", "Release"),

                IsLocalBuild = buildSystem.IsLocalBuild,
                IsRunningOnUnix = context.IsRunningOnUnix(),
                IsRunningOnWindows = context.IsRunningOnWindows(),
                IsRunningOnAppVeyor = buildSystem.AppVeyor.IsRunningOnAppVeyor,

                IsPullRequest = buildSystem.AppVeyor.Environment.PullRequest.IsPullRequest,
                //IsMainClientRepo = StringComparer.OrdinalIgnoreCase.Equals("fairycode/sharp-blueprint", buildSystem.AppVeyor.Environment.Repository.Name),
                IsMainClientBranch = StringComparer.OrdinalIgnoreCase.Equals("master", buildSystem.AppVeyor.Environment.Repository.Branch),
                IsTagged = IsBuildTagged(buildSystem),

                ReleaseNotes = context.ParseReleaseNotes("./ReleaseNotes.md"),
                IsPublishBuild = IsPublishing(target),
                IsReleaseBuild = IsReleasing(target),
                SkipGitVersion = StringComparer.OrdinalIgnoreCase.Equals("True", context.EnvironmentVariable("CLIENT_SKIP_GITVERSION")),
                SkipOpenCover = StringComparer.OrdinalIgnoreCase.Equals("True", context.EnvironmentVariable("CLIENT_SKIP_OPENCOVER"))
            };
        }

        private static bool IsBuildTagged(BuildSystem buildSystem)
        {
            return buildSystem.AppVeyor.Environment.Repository.Tag.IsTag
                && !string.IsNullOrWhiteSpace(buildSystem.AppVeyor.Environment.Repository.Tag.Name);
        }

        private static bool IsReleasing(string target)
        {
            var targets = new[] { "Publish", "Publish-NuGet", "Publish-GitHub-Release" };
            return targets.Any(t => StringComparer.OrdinalIgnoreCase.Equals(t, target));
        }

        private static bool IsPublishing(string target)
        {
            var targets = new[] { "ReleaseNotes", "Create-Release-Notes" };
            return targets.Any(t => StringComparer.OrdinalIgnoreCase.Equals(t, target));
        }
    }
}
