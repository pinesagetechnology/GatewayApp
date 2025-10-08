using System.Text.Json;

namespace MonitoringServiceAPI.Services
{
    public interface IVivotekService
    {
        Task SaveRawDataAsync(string data);
    }

    public class VivotekService : IVivotekService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<VivotekService> _logger;
        public VivotekService(IConfiguration configuration, ILogger<VivotekService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public async Task SaveRawDataAsync(string data)
        {
            try
            {
                var dataFolderPath = _configuration["VivotechStorage:DataFolderPath"];
                if (string.IsNullOrEmpty(dataFolderPath))
                {
                    throw new InvalidOperationException("DataStorage:DataFolderPath is not configured in appsettings.json");
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
