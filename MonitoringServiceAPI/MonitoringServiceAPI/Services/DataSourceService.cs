using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Services
{
    public interface IDataSourceService
    {
        Task<IEnumerable<FileDataSourceConfig>> GetAllDataSourcesAsync();
        Task<FileDataSourceConfig?> GetDataSourcesByNameAsync(string name);
        Task<FileDataSourceConfig?> GetDataSourcesByIdAsync(int id);
        Task<FileDataSourceConfig> CreateAsync(CreateDataSourceRequest request);
        Task<FileDataSourceConfig?> UpdateAsync(int id, UpdateDataSourceRequest dataSourceConfig);
        Task<bool> DeleteAsync(int id);

        Task UpdateDataSourcesIsrefreshingFlagAsync(FileDataSourceConfig fileDataSourceConfig);
    }

    public class DataSourceService : IDataSourceService
    {
        private readonly IRepository<FileDataSourceConfig> _repository;
        private readonly ILogger<DataSourceService> _logger;

        public DataSourceService([FromKeyedServices("file")] IRepository<FileDataSourceConfig> repository, 
            ILogger<DataSourceService> logger)
        {
            _repository = repository;
            _logger = logger;
        }

        public Task<FileDataSourceConfig> CreateAsync(CreateDataSourceRequest request)
        {
            var dataSourceConfig = new FileDataSourceConfig
            {
                Name = request.Name,
                IsEnabled = request.IsEnabled,
                IsRefreshing = request.IsRefreshing,
                FolderPath = request.FolderPath,
                FilePattern = request.FilePattern
            };

            return _repository.AddAsync(dataSourceConfig);
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

        public async Task<IEnumerable<FileDataSourceConfig>> GetAllDataSourcesAsync()
        {
            try
            {
                return await _repository.GetAllAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error occurred while fetching data sources {ex.Message}");

                return Enumerable.Empty<FileDataSourceConfig>();
            }
        }

        public Task<FileDataSourceConfig?> GetDataSourcesByIdAsync(int id)
        {
            return _repository.GetByIdAsync(id);
        }

        public async Task<FileDataSourceConfig?> GetDataSourcesByNameAsync(string name)
        {
            var result = await _repository.FindAsync(x => x.Name == name);
            return result.FirstOrDefault(); 
        }

        public async Task<FileDataSourceConfig?> UpdateAsync(int id, UpdateDataSourceRequest dataSourceConfig)
        {
            var existing = await _repository.GetByIdAsync(id);
            if (existing == null)
            {
                return await Task.FromResult<FileDataSourceConfig?>(null);
            }

            existing.Name = dataSourceConfig.Name;
            existing.IsEnabled = dataSourceConfig.IsEnabled;
            existing.IsRefreshing = dataSourceConfig.IsRefreshing;
            existing.FolderPath = dataSourceConfig.FolderPath;
            existing.FilePattern = dataSourceConfig.FilePattern;
            
            return await _repository.UpdateAsync(existing).ContinueWith(t => existing);
        }

        public async Task UpdateDataSourcesIsrefreshingFlagAsync(FileDataSourceConfig fileDataSourceConfig)
        {
            await _repository.UpdateAsync(fileDataSourceConfig);
        }
    }
}
