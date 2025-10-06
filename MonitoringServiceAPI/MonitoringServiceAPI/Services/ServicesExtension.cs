using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;

namespace MonitoringServiceAPI.Services
{
    public static class ServicesExtension
    {
        public static IServiceCollection RegisterBusinessServices(this IServiceCollection services)
        {
            // Register services
            services.AddTransient<IUploadQueueService, UploadQueueService>();
            services.AddTransient<IConfigurationService, ConfigurationService>();
            services.AddTransient<IAzureStorageService, AzureStorageService>();
            services.AddTransient<IDataSourceService, DataSourceService>();
            services.AddTransient<IHeartbeatService, HeartbeatService>();

            // API-specific configuration service to update API Monitoring config table
            services.AddTransient<IApiConfigurationService, ApiConfigurationService>();

            services.AddTransient<IAPIDataSourceService, APIDataSourceService>();

            return services;

        }
    }
}
