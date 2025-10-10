namespace APIMonitorWorkerService.Models
{
    public class ApiPollerSettings
    {
        public Dictionary<string, string>? Headers { get; set; }
        public string? AuthenticationType { get; set; }  // "Basic", "Digest", "Bearer"
        public string? Username { get; set; }
        public string? Password { get; set; }
        public string? AuthenticationValue { get; set; }  // For Bearer tokens
        public int? RetryCount { get; set; }
        public int? RetryDelayMs { get; set; }
        public bool ParseJsonArray { get; set; } = true;
        public string? ItemIdField { get; set; }
        public string? TimestampField { get; set; }
        public string? DataField { get; set; }
    }
}
