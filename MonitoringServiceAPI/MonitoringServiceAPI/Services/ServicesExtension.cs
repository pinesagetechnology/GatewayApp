using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;

namespace MonitoringServiceAPI.Services
{
    public static class ServicesExtension
    {
        public static IServiceCollection RegisterBusinessServices(this IServiceCollection services)
        {
            // Register business services
            services.AddTransient<IUploadQueueService, UploadQueueService>();
            services.AddTransient<IConfigurationService, ConfigurationService>();
            services.AddTransient<IAzureStorageService, AzureStorageService>();
            services.AddTransient<IDataSourceService, DataSourceService>();
            services.AddTransient<IHeartbeatService, HeartbeatService>();
            
            // Register infrastructure services
            services.AddTransient<IScriptExecutionService, ScriptExecutionService>();
            services.AddTransient<IPathValidationService, PathValidationService>();
            
            // API-specific configuration service to update API Monitoring config table
            services.AddTransient<IApiConfigurationService, ApiConfigurationService>();
            services.AddTransient<IAPIDataSourceService, APIDataSourceService>();

            // Push server services
            services.AddTransient<IPushServerSettingService, PushServerSettingService>();
            services.AddTransient<IVivotekService, VivotekService>();

            return services;
        }
    }
}
