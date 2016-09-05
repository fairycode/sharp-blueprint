﻿using System;
#if NET35
using NUnit.Framework;
#else
using Xunit;
#endif

namespace SharpBlueprint.Client.Tests
{
#if NET35
    [TestFixture]
#endif
    public class SimpleHttpClientTests
    {
#if NET35
        [Test]
        public void GetDotNetCountTest()
        {
            var client = new SimpleHttpClient();
            var result = client.GetDotNetCount();

            Console.WriteLine(result);

            Assert.IsTrue(!string.IsNullOrEmpty(result));
        }
#else
        [Fact]
        public void GetDotNetCountAsyncTest()
        {
            var client = new SimpleHttpClient();
            var resultTask = client.GetDotNetCountAsync();

            var result = resultTask.Result;

            Console.WriteLine(result);

            Assert.True(!string.IsNullOrEmpty(result));
        }
#endif
    }
}
