using System.ComponentModel.DataAnnotations;

namespace MonitoringServiceAPI.Models
{
    public class CreateAPIDataSourceRequest
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        public bool IsEnabled { get; set; } = true;

        public bool IsRefreshing { get; set; } = true;

        [StringLength(500)]
        public string? TempFolderPath { get; set; }

        [StringLength(500)]
        public string? ApiEndpoint { get; set; }

        [StringLength(200)]
        public string? ApiKey { get; set; }

        public int PollingIntervalMinutes { get; set; } = 5;

        [StringLength(1000)]
        public string? AdditionalSettings { get; set; }
    }

    public class UpdateAPIDataSourceRequest
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        public bool IsEnabled { get; set; }

        public bool IsRefreshing { get; set; } = true;

        [StringLength(500)]
        public string? TempFolderPath { get; set; }

        [StringLength(500)]
        public string? ApiEndpoint { get; set; }

        [StringLength(200)]
        public string? ApiKey { get; set; }

        public int PollingIntervalMinutes { get; set; } = 5;

        [StringLength(1000)]
        public string? AdditionalSettings { get; set; }
    }
}
