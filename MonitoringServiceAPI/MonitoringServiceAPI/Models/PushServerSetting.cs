using System.ComponentModel.DataAnnotations;

namespace MonitoringServiceAPI.Models
{
    public class PushServerSetting
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public bool IsEnabled { get; set; } = false;

        [Required]
        [StringLength(500)]
        public string DataFolderPath { get; set; } = string.Empty;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        [StringLength(100)]
        public string? UpdatedBy { get; set; }
    }
}

