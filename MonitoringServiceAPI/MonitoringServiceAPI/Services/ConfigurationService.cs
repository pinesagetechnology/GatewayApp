using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using MonitoringServiceAPI.Models;
using System.Text.Json;

namespace MonitoringServiceAPI.Services
{
    public interface IConfigurationService
    {
        Task<IEnumerable<Configuration>> GetAllAsync();
        Task<string?> GetValueAsync(string key);
        Task<T?> GetValueAsync<T>(string key);
        Task SetValueAsync(string key, string value, string? description = null, string? category = null);
    }

    public class ConfigurationService : IConfigurationService
    {
        private readonly IRepository<Configuration> _repository;
        private readonly ILogger<ConfigurationService> _logger;

        public ConfigurationService([FromKeyedServices("file")] IRepository<Configuration> repository, ILogger<ConfigurationService> logger)
        {
            _logger = logger;
            _repository = repository;
        }

        public async Task<IEnumerable<Configuration>> GetAllAsync()
        {
            _logger.LogDebug("Getting all configuration values");

            var configs = await _repository.GetAllAsync();

            _logger.LogDebug($"Retrieved {configs.Count()} configuration values");

            return configs
                .OrderBy(c => c.Category)
                .ThenBy(c => c.Key)
                .ToList();
        }

        public async Task<string?> GetValueAsync(string key)
        {
            _logger.LogDebug("Getting configuration value for key: {Key}", key);
            var config = await _repository.GetByKeyAsync<string>(key);

            if (config != null)
            {
                _logger.LogDebug("Found configuration value for key {Key}: {Value}", key, config.Value);
                return config.Value;
            }
            else
            {
                _logger.LogDebug("Configuration key {Key} not found", key);
                return null;
            }
        }

        public async Task<T?> GetValueAsync<T>(string key)
        {
            _logger.LogDebug("Getting typed configuration value for key: {Key}, type: {Type}", key, typeof(T));

            var config = await _repository.GetByKeyAsync<string>(key);

            if (config == null || string.IsNullOrEmpty(config.Value))
            {
                _logger.LogDebug("Configuration value for key {Key} is null or empty, returning default", key);
                return default(T);
            }

            try
            {
                T result = (T)Convert.ChangeType(config.Value, typeof(T));

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error converting configuration value for key {Key} to type {Type}", key, typeof(T));
                return default(T);
            }
        }

        public async Task SetValueAsync(string key, string value, string? description = null, string? category = null)
        {
            var existing = await _repository.GetByKeyAsync(key);

            if (existing != null)
            {
                existing.Value = value;
                existing.UpdatedAt = DateTime.UtcNow;
                if (!string.IsNullOrEmpty(description))
                    existing.Description = description;
                if (!string.IsNullOrEmpty(category))
                    existing.Category = category;

                await _repository.UpdateAsync(existing);
            }
            else
            {
                var config = new Models.Configuration
                {
                    Key = key,
                    Value = value,
                    Description = description,
                    Category = category,
                    UpdatedAt = DateTime.UtcNow
                };
                await _repository.AddAsync(config);
            }
        }

    }
}
