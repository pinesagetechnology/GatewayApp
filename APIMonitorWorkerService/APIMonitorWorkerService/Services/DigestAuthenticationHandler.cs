using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace APIMonitorWorkerService.Services
{
    public class DigestAuthenticationHandler : DelegatingHandler
    {
        private readonly string _username;
        private readonly string _password;
        private readonly ILogger<DigestAuthenticationHandler> _logger;
        private int _nonceCount = 0;
        private string? _cnonce;

        public DigestAuthenticationHandler(string username, string password, ILogger<DigestAuthenticationHandler> logger)
        {
            _username = username;
            _password = password;
            _logger = logger;
            InnerHandler = new HttpClientHandler();
        }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            // First attempt without authentication
            var response = await base.SendAsync(request, cancellationToken);

            // If 401, handle Digest authentication
            if (response.StatusCode == HttpStatusCode.Unauthorized)
            {
                var authHeader = response.Headers.WwwAuthenticate.FirstOrDefault();
                
                if (authHeader != null && authHeader.Scheme.Equals("Digest", StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogDebug("Received Digest authentication challenge");
                    
                    // Parse the challenge
                    var challenge = authHeader.Parameter;
                    if (challenge != null)
                    {
                        // Create new request with Digest auth header
                        var authenticatedRequest = await CloneRequestAsync(request);
                        var digestHeader = CreateDigestHeader(request.Method.Method, request.RequestUri!, challenge);
                        
                        if (digestHeader != null)
                        {
                            authenticatedRequest.Headers.Authorization = 
                                new System.Net.Http.Headers.AuthenticationHeaderValue("Digest", digestHeader);
                            
                            _logger.LogDebug("Sending request with Digest authentication");
                            response = await base.SendAsync(authenticatedRequest, cancellationToken);
                        }
                    }
                }
            }

            return response;
        }

        private async Task<HttpRequestMessage> CloneRequestAsync(HttpRequestMessage request)
        {
            var clone = new HttpRequestMessage(request.Method, request.RequestUri);

            // Copy headers
            foreach (var header in request.Headers)
            {
                clone.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }

            // Copy content if present
            if (request.Content != null)
            {
                var content = await request.Content.ReadAsByteArrayAsync();
                clone.Content = new ByteArrayContent(content);

                // Copy content headers
                foreach (var header in request.Content.Headers)
                {
                    clone.Content.Headers.TryAddWithoutValidation(header.Key, header.Value);
                }
            }

            return clone;
        }

        private string? CreateDigestHeader(string method, Uri uri, string challenge)
        {
            try
            {
                // Parse challenge parameters
                var realm = ExtractValue(challenge, "realm");
                var nonce = ExtractValue(challenge, "nonce");
                var qop = ExtractValue(challenge, "qop");
                var opaque = ExtractValue(challenge, "opaque");
                var algorithm = ExtractValue(challenge, "algorithm") ?? "MD5";

                if (string.IsNullOrEmpty(realm) || string.IsNullOrEmpty(nonce))
                {
                    _logger.LogWarning("Invalid Digest challenge - missing realm or nonce");
                    return null;
                }

                // Generate cnonce (client nonce)
                if (_cnonce == null)
                {
                    _cnonce = Guid.NewGuid().ToString("N").Substring(0, 16);
                }

                // Increment nonce count
                _nonceCount++;
                var nc = _nonceCount.ToString("x8");

                // Calculate HA1 = MD5(username:realm:password)
                var ha1 = CalculateMD5Hash($"{_username}:{realm}:{_password}");

                // Calculate HA2 = MD5(method:uri)
                var ha2 = CalculateMD5Hash($"{method}:{uri.PathAndQuery}");

                // Calculate response
                string response;
                if (!string.IsNullOrEmpty(qop))
                {
                    // With qop (quality of protection)
                    response = CalculateMD5Hash($"{ha1}:{nonce}:{nc}:{_cnonce}:{qop}:{ha2}");
                }
                else
                {
                    // Without qop (legacy)
                    response = CalculateMD5Hash($"{ha1}:{nonce}:{ha2}");
                }

                // Build Digest header
                var headerBuilder = new StringBuilder();
                headerBuilder.Append($"username=\"{_username}\"");
                headerBuilder.Append($", realm=\"{realm}\"");
                headerBuilder.Append($", nonce=\"{nonce}\"");
                headerBuilder.Append($", uri=\"{uri.PathAndQuery}\"");
                headerBuilder.Append($", algorithm={algorithm}");
                headerBuilder.Append($", response=\"{response}\"");

                if (!string.IsNullOrEmpty(qop))
                {
                    headerBuilder.Append($", qop={qop}");
                    headerBuilder.Append($", nc={nc}");
                    headerBuilder.Append($", cnonce=\"{_cnonce}\"");
                }

                if (!string.IsNullOrEmpty(opaque))
                {
                    headerBuilder.Append($", opaque=\"{opaque}\"");
                }

                return headerBuilder.ToString();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create Digest authentication header");
                return null;
            }
        }

        private string ExtractValue(string challenge, string key)
        {
            var pattern = $@"{key}=""?([^"",]+)""?";
            var match = Regex.Match(challenge, pattern, RegexOptions.IgnoreCase);
            return match.Success ? match.Groups[1].Value : string.Empty;
        }

        private string CalculateMD5Hash(string input)
        {
            using var md5 = MD5.Create();
            var inputBytes = Encoding.UTF8.GetBytes(input);
            var hashBytes = md5.ComputeHash(inputBytes);
            return BitConverter.ToString(hashBytes).Replace("-", "").ToLower();
        }
    }
}
