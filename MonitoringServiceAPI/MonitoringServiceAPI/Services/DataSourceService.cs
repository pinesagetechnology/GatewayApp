using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;
using System.ComponentModel.DataAnnotations;

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
        private readonly IPathValidationService _pathValidationService;
        private readonly IScriptExecutionService _scriptExecutionService;

        public DataSourceService(
            [FromKeyedServices("file")] IRepository<FileDataSourceConfig> repository, 
            ILogger<DataSourceService> logger,
            IPathValidationService pathValidationService,
            IScriptExecutionService scriptExecutionService)
        {
            _repository = repository;
            _logger = logger;
            _pathValidationService = pathValidationService;
            _scriptExecutionService = scriptExecutionService;
        }

        public async Task<FileDataSourceConfig> CreateAsync(CreateDataSourceRequest request)
        {
            _logger.LogInformation("Creating new File DataSource: {Name}", request.Name);

            // Step 1: Validate folder path
            if (string.IsNullOrWhiteSpace(request.FolderPath))
            {
                throw new ValidationException("Folder path is required");
            }

            _logger.LogInformation("Validating folder path: {FolderPath}", request.FolderPath);
            var validation = await _pathValidationService.ValidateFolderPathAsync(request.FolderPath);

            if (!validation.IsValid)
            {
                throw new ValidationException($"Invalid folder path: {validation.ErrorMessage}");
            }

            // Step 2: Check for duplicate names
            var existing = await GetDataSourcesByNameAsync(request.Name);
            if (existing != null)
            {
                throw new ValidationException($"Data source with name '{request.Name}' already exists");
            }

            // Step 3: Execute permission script if needed
            if (validation.RequiresPermissionFix)
            {
                _logger.LogInformation("Executing permission fix script for: {FolderPath}", request.FolderPath);

                var scriptResult = await _scriptExecutionService.ExecutePermissionScriptAsync(request.FolderPath);

                if (!scriptResult.Success)
                {
                    var errorDetails = $"Failed to setup folder permissions: {scriptResult.ErrorMessage}\n" +
                                     $"Exit Code: {scriptResult.ExitCode}\n" +
                                     $"Output: {scriptResult.Output}\n" +
                                     $"Error: {scriptResult.Error}";
                    
                    _logger.LogError("Permission script failed: {ErrorDetails}", errorDetails);
                    throw new InvalidOperationException(errorDetails);
                }

                _logger.LogInformation("Permission script completed successfully");
            }
            else
            {
                _logger.LogInformation("Folder permissions are already correct, skipping script execution");
            }

            // Step 4: Create data source configuration
            var dataSourceConfig = new FileDataSourceConfig
            {
                Name = request.Name,
                IsEnabled = request.IsEnabled,
                IsRefreshing = request.IsRefreshing,
                FolderPath = _pathValidationService.NormalizePath(request.FolderPath),
                FilePattern = request.FilePattern ?? "*.*",
                CreatedAt = DateTime.UtcNow
            };

            _logger.LogInformation("Creating File DataSource in database: {Name} -> {FolderPath}", 
                dataSourceConfig.Name, dataSourceConfig.FolderPath);

            return await _repository.AddAsync(dataSourceConfig);
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
