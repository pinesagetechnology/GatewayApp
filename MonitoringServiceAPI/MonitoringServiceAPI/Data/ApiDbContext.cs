using Microsoft.EntityFrameworkCore;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Data
{
    public class ApiDbContext : DbContext
    {
        public ApiDbContext(DbContextOptions<ApiDbContext> options) : base(options)
        {
        }

        public DbSet<APIDataSourceConfig> APIDataSourceConfigs { get; set; }

        public DbSet<APIMonitorServiceHeartBeat> APIMonitorServiceHeartBeats { get; set; }

        public DbSet<Configuration> Configurations { get; set; }
    }
}


