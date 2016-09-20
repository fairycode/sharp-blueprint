public class BuildPackages
{
    public ICollection<BuildPackage> Nuget { get; private set; }

    public static BuildPackages GetPackages(
        DirectoryPath nugetRooPath,
        string semVersion,
        string[] packageIds)
    {
        var toNugetPackage = BuildPackage(nugetRooPath, semVersion);
        var nugetPackages = packageIds.Select(toNugetPackage).ToArray();

        return new BuildPackages
        {
            Nuget = nugetPackages
        };
    }

    private static Func<string, BuildPackage> BuildPackage(
        DirectoryPath nugetRooPath,
        string semVersion)
    {
        return package => new BuildPackage(
            package,
            string.Concat("./nuspec/", package, ".nuspec"),
            nugetRooPath.CombineWithFilePath(string.Concat(package, ".", semVersion, ".nupkg")));
    }
}

public class BuildPackage
{
    public string Id { get; private set; }
    public FilePath NuspecPath { get; private set; }
    public FilePath PackagePath { get; private set; }

    public BuildPackage(
        string id,
        FilePath nuspecPath,
        FilePath packagePath)
    {
        Id = id;
        NuspecPath = nuspecPath;
        PackagePath = packagePath;
    }
}