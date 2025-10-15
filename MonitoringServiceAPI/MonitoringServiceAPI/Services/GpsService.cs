using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Services
{
    public interface IGpsService
    {
        Task SaveRawDataAsync(string data);
        Task<bool> IsEnabledAsync();
    }

    public class GpsService : IGpsService
    {
        private readonly IRepository<GpsServerSetting> _repository;
        private readonly ILogger<GpsService> _logger;

        public GpsService(
            [FromKeyedServices("file")] IRepository<GpsServerSetting> repository,
            ILogger<GpsService> logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public async Task<bool> IsEnabledAsync()
        {
            var settings = await _repository.GetAllAsync();
            var setting = settings.FirstOrDefault();
            return setting?.IsEnabled ?? false;
        }

        public async Task SaveRawDataAsync(string data)
        {
            try
            {
                var settings = await _repository.GetAllAsync();
                var setting = settings.FirstOrDefault();

                if (setting == null)
                {
                    throw new InvalidOperationException("GpsServerSetting not found in database");
                }

                if (!setting.IsEnabled)
                {
                    _logger.LogWarning("GPS server is disabled. Data not saved.");
                    throw new InvalidOperationException("GPS server is currently disabled");
                }

                var dataFolderPath = setting.DataFolderPath;
                if (string.IsNullOrEmpty(dataFolderPath))
                {
                    throw new InvalidOperationException("DataFolderPath is not configured in GpsServerSetting");
                }

                // Ensure directory exists
                Directory.CreateDirectory(dataFolderPath);

                // Create filename with timestamp
                var fileName = $"gps_data_{DateTimeOffset.UtcNow:yyyyMMdd_HHmmss}_{Guid.NewGuid():N}.json";
                var filePath = Path.Combine(dataFolderPath, fileName);

                // Write to file
                await File.WriteAllTextAsync(filePath, data);

                _logger.LogInformation("GPS data saved successfully to: {FilePath}", filePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving GPS data to file");
                throw;
            }
        }
    }
}

