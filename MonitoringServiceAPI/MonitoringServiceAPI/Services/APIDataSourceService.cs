using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Services
{
    public class APIDataSourceService : IAPIDataSourceService
    {
        private readonly IRepository<APIDataSourceConfig> _repository;
        private readonly ILogger<APIDataSourceService> _logger;

        public APIDataSourceService([FromKeyedServices("api")] IRepository<APIDataSourceConfig> repository, 
            ILogger<APIDataSourceService> logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public Task<APIDataSourceConfig> CreateAsync(CreateAPIDataSourceRequest request)
        {
            var apiDataSourceConfig = new APIDataSourceConfig
            {
                Name = request.Name,
                IsEnabled = request.IsEnabled,
                IsRefreshing = request.IsRefreshing,
                TempFolderPath = request.TempFolderPath,
                ApiEndpoint = request.ApiEndpoint,
                ApiKey = request.ApiKey,
                PollingIntervalMinutes = request.PollingIntervalMinutes,
                AdditionalSettings = request.AdditionalSettings,
                CreatedAt = DateTime.UtcNow
            };

            return _repository.AddAsync(apiDataSourceConfig);
        }

        public async Task<bool> DeleteAsync(int id)
        {
            var existing = await _repository.GetByIdAsync(id);

            if (existing == null)
            {
                return false;
            }
            await _repository.DeleteAsync(existing);

            return true;
        }

        public async Task<IEnumerable<APIDataSourceConfig>> GetAllAPIDataSourcesAsync()
        {
            try
            {
                return await _repository.GetAllAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error occurred while fetching API data sources {ex.Message}");
                return Enumerable.Empty<APIDataSourceConfig>();
            }
        }

        public Task<APIDataSourceConfig?> GetAPIDataSourceByIdAsync(int id)
        {
            return _repository.GetByIdAsync(id);
        }

        public async Task<APIDataSourceConfig?> GetAPIDataSourceByNameAsync(string name)
        {
            var result = await _repository.FindAsync(x => x.Name == name);
            return result.FirstOrDefault(); 
        }

        public async Task<APIDataSourceConfig?> UpdateAsync(int id, UpdateAPIDataSourceRequest apiDataSourceConfig)
        {
            var existing = await _repository.GetByIdAsync(id);
            if (existing == null)
            {
                return await Task.FromResult<APIDataSourceConfig?>(null);
            }

            existing.Name = apiDataSourceConfig.Name;
            existing.IsEnabled = apiDataSourceConfig.IsEnabled;
            existing.IsRefreshing = apiDataSourceConfig.IsRefreshing;
            existing.TempFolderPath = apiDataSourceConfig.TempFolderPath;
            existing.ApiEndpoint = apiDataSourceConfig.ApiEndpoint;
            existing.ApiKey = apiDataSourceConfig.ApiKey;
            existing.PollingIntervalMinutes = apiDataSourceConfig.PollingIntervalMinutes;
            existing.AdditionalSettings = apiDataSourceConfig.AdditionalSettings;
            
            return await _repository.UpdateAsync(existing).ContinueWith(t => existing);
        }

        public async Task UpdateAPIDataSourceIsRefreshingFlagAsync(APIDataSourceConfig apiDataSourceConfig)
        {
            await _repository.UpdateAsync(apiDataSourceConfig);
        }
    }
}
