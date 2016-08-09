using System;
using NUnit.Framework;

namespace SharpBlueprint.Core.Tests
{
    [TestFixture]
    public class SimpleHttpClientTests
    {
        [Test]
        public void GetDotNetCountTest()
        {
            var client = new SimpleHttpClient();
            var result = client.GetDotNetCount();

            Console.WriteLine(result);

            Assert.IsTrue(!string.IsNullOrEmpty(result));
        }
    }
}
