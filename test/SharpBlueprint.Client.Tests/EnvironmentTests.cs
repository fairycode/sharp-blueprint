using Xunit;

namespace SharpBlueprint.Client.Tests
{
    public class EnvironmentTests
    {
        [Fact]
        public void GetFrameworkVersionTest()
        {
            var environment = new Environment();
            var version = environment.GetFrameworkVersion();
#if NETCOREAPP1_1
            Assert.True(".NET Standard 1.4".Equals(version));
#elif NET452
            Assert.True(".NET Framework 4.5.2".Equals(version));
#endif
        }
    }
}
