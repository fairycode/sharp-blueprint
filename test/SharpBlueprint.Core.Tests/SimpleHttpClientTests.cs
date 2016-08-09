using System;
using Xunit;

namespace SharpBlueprint.Core.Tests
{
    public class SimpleHttpClientTests
    {
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
