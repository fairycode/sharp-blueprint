#if NET35
using System;
using System.Net;
#else
using System.Net.Http;
using System.Threading.Tasks;
#endif
using System.Text.RegularExpressions;

namespace SharpBlueprint.Client
{
    /// <summary>
    /// 
    /// </summary>
    public class SimpleHttpClient
    {
#if NET35
        private readonly WebClient client = new WebClient();
        private readonly object locker = new object();
#else
        private readonly HttpClient client = new HttpClient();
#endif

#if NET35
        // .NET Framework 4.0 does not have async/await
        public string GetDotNetCount()
        {
            var url = "http://www.dotnetfoundation.org/";
            var uri = new Uri(url);
            var result = "";

            // Lock here to provide thread-safety.
            lock(locker)
            {
                result = client.DownloadString(uri);
            }

            var dotNetCount = Regex.Matches(result, ".NET").Count;

            return string.Format("Dotnet Foundation mentions .NET {0} times!", dotNetCount);
        }
#else
        // .NET 4.5+ can use async/await!
        public async Task<string> GetDotNetCountAsync()
        {
            var url = "http://www.dotnetfoundation.org/";

            // HttpClient is thread-safe, so no need to explicitly lock here
            var result = await client.GetStringAsync(url);

            var dotNetCount = Regex.Matches(result, ".NET").Count;

            return string.Format("dotnetfoundation.orgmentions .NET {0} times in its HTML!", dotNetCount);
        }
#endif
    }
}
