using System.ComponentModel.DataAnnotations;

namespace MonitoringServiceAPI.Models
{
    public class GpsServerSetting
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public bool IsEnabled { get; set; } = false;

        [Required]
        [StringLength(500)]
        public string DataFolderPath { get; set; } = string.Empty;
    }
}

