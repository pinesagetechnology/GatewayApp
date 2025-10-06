namespace MonitoringServiceAPI.Models
{
    public class CreateDataSourceRequest
    {
        public string Name { get; set; } = string.Empty;
        public bool IsEnabled { get; set; } = true;
        public bool IsRefreshing { get; set; } = true;
        public string? FolderPath { get; set; }
        public string? FilePattern { get; set; }
    }

    public class UpdateDataSourceRequest
    {
        public string Name { get; set; } = string.Empty;
        public bool IsEnabled { get; set; }
        public bool IsRefreshing { get; set; } = true;
        public string? FolderPath { get; set; }
        public string? FilePattern { get; set; }
    }
}
