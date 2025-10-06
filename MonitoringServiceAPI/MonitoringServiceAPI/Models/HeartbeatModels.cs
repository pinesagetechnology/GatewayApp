using System.ComponentModel.DataAnnotations;

namespace MonitoringServiceAPI.Models
{
    public class FileMonitorServiceHeartBeat
    {
        [Key]
        public int Id { get; set; }

        public DateTime? LastRun { get; set; }
    }

    public class APIMonitorServiceHeartBeat
    {
        [Key]
        public int Id { get; set; }

        public DateTime? LastRun { get; set; }
    }
}
