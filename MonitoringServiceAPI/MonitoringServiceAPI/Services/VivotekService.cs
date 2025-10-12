using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Services
{
    public interface IVivotekService
    {
        Task SaveRawDataAsync(string data);
        Task<bool> IsEnabledAsync();
    }

    public class VivotekService : IVivotekService
    {
        private readonly IRepository<PushServerSetting> _repository;
        private readonly ILogger<VivotekService> _logger;

        public VivotekService(
            [FromKeyedServices("file")] IRepository<PushServerSetting> repository,
            ILogger<VivotekService> logger)
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
                    throw new InvalidOperationException("PushServerSetting not found in database");
                }

                if (!setting.IsEnabled)
                {
                    _logger.LogWarning("Push server is disabled. Data not saved.");
                    throw new InvalidOperationException("Push server is currently disabled");
                }

                var dataFolderPath = setting.DataFolderPath;
                if (string.IsNullOrEmpty(dataFolderPath))
                {
                    throw new InvalidOperationException("DataFolderPath is not configured in PushServerSetting");
                }

                // Ensure directory exists
                Directory.CreateDirectory(dataFolderPath);

                // Create filename with timestamp
                var fileName = $"data_{DateTimeOffset.UtcNow:yyyyMMdd_HHmmss}_{Guid.NewGuid():N}.json";
                var filePath = Path.Combine(dataFolderPath, fileName);

                // Write to file
                await File.WriteAllTextAsync(filePath, data);

                _logger.LogInformation("Data saved successfully to: {FilePath}", filePath);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error saving data to file");
                throw;
            }
        }
    }
}
