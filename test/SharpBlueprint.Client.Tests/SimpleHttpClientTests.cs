using System;
using Xunit;

namespace SharpBlueprint.Client.Tests
{
    public class SimpleHttpClientTests
    {
#if NET35
        [Fact]
        public void GetDotNetCountTest()
        {
            var client = new SimpleHttpClient();
            var result = client.GetDotNetCount();

            Console.WriteLine(result);

            Assert.True(!string.IsNullOrEmpty(result));
        }
#endif
        [Fact]
        public void GetDotNetCountAsyncTest()
        {
            var client = new SimpleHttpClient();
            var resultTask = client.GetDotNetCountAsync();

            var result = resultTask.Result;

            Console.WriteLine(result);

            Assert.True(!string.IsNullOrEmpty(result));
        }
    }
}