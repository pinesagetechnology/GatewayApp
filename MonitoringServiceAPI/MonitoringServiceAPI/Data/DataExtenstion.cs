using FileMonitorWorkerService.Data.Repository;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace MonitoringServiceAPI.Data
{
    public static class DataExtenstion
    {
        public static IServiceCollection RegisterDataServices(this IServiceCollection services, IConfiguration configuration)
        {
            var fileConn = configuration.GetConnectionString("FileMonitorConnection")
                ?? throw new InvalidOperationException("FileMonitorConnection not found");

            var apiConn = configuration.GetConnectionString("ApiMonitorConnection")
                ?? fileConn; // fallback to file conn if not provided

            services.AddDbContext<AppDbContext>(options =>
            {
                options.UseSqlite(fileConn);
                options.EnableSensitiveDataLogging(false);
                options.EnableDetailedErrors(true);
            });

            services.AddDbContext<ApiDbContext>(options =>
            {
                options.UseSqlite(apiConn);
                options.EnableSensitiveDataLogging(false);
                options.EnableDetailedErrors(true);
            });

            // Register repositories as keyed services so we can choose DbContext per usage
            services.AddKeyedTransient(typeof(IRepository<>), "file", typeof(Repository<>));
            services.AddKeyedTransient(typeof(IRepository<>), "api", typeof(ApiRepository<>));

            return services;
        }

    }
}
