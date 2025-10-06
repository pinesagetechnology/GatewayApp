namespace MonitoringServiceAPI.Models
{
    public class AzureStorageConfigRequest
    {
        public string ConnectionString { get; set; } = string.Empty;
        public string? DefaultContainer { get; set; }
        public int? MaxConcurrentUploads { get; set; }
    }

    public class AzureStorageInfo
    {
        public bool IsConnected { get; set; }
        public string? AccountName { get; set; }
        public List<string> Containers { get; set; } = new();
        public string? ErrorMessage { get; set; }
    }
}
