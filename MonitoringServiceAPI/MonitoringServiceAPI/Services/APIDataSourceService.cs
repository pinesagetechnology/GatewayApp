using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;
using System.ComponentModel.DataAnnotations;

namespace MonitoringServiceAPI.Services
{
    public class APIDataSourceService : IAPIDataSourceService
    {
        private readonly IRepository<APIDataSourceConfig> _repository;
        private readonly ILogger<APIDataSourceService> _logger;
        private readonly IPathValidationService _pathValidationService;
        private readonly IScriptExecutionService _scriptExecutionService;

        public APIDataSourceService(
            [FromKeyedServices("api")] IRepository<APIDataSourceConfig> repository, 
            ILogger<APIDataSourceService> logger,
            IPathValidationService pathValidationService,
            IScriptExecutionService scriptExecutionService)
        {
            _repository = repository;
            _logger = logger;
            _pathValidationService = pathValidationService;
            _scriptExecutionService = scriptExecutionService;
        }

        public async Task<APIDataSourceConfig> CreateAsync(CreateAPIDataSourceRequest request)
        {
            _logger.LogInformation("Creating new API DataSource: {Name}", request.Name);

            // Step 1: Validate API endpoint
            if (!string.IsNullOrEmpty(request.ApiEndpoint))
            {
                if (!Uri.TryCreate(request.ApiEndpoint, UriKind.Absolute, out var uri))
                {
                    throw new ValidationException($"Invalid API endpoint URL: {request.ApiEndpoint}");
                }
                _logger.LogInformation("API endpoint validated: {ApiEndpoint}", request.ApiEndpoint);
            }

            // Step 2: Validate temp folder path (if provided)
            if (!string.IsNullOrEmpty(request.TempFolderPath))
            {
                _logger.LogInformation("Validating temp folder path: {TempFolderPath}", request.TempFolderPath);
                var validation = await _pathValidationService.ValidateFolderPathAsync(request.TempFolderPath);

                if (!validation.IsValid)
                {
                    throw new ValidationException($"Invalid temp folder path: {validation.ErrorMessage}");
                }

                // Execute permission script if needed
                if (validation.RequiresPermissionFix)
                {
                    _logger.LogInformation("Executing permission fix script for temp folder: {TempFolderPath}", request.TempFolderPath);

                    var scriptResult = await _scriptExecutionService.ExecutePermissionScriptAsync(request.TempFolderPath);

                    if (!scriptResult.Success)
                    {
                        var errorDetails = $"Failed to setup temp folder permissions: {scriptResult.ErrorMessage}\n" +
                                         $"Exit Code: {scriptResult.ExitCode}\n" +
                                         $"Output: {scriptResult.Output}\n" +
                                         $"Error: {scriptResult.Error}";
                        
                        _logger.LogError("Permission script failed: {ErrorDetails}", errorDetails);
                        throw new InvalidOperationException(errorDetails);
                    }

                    _logger.LogInformation("Permission script completed successfully for temp folder");
                }
                else
                {
                    _logger.LogInformation("Temp folder permissions are already correct, skipping script execution");
                }
            }

            // Step 3: Check for duplicate names
            var existing = await GetAPIDataSourceByNameAsync(request.Name);
            if (existing != null)
            {
                throw new ValidationException($"API data source with name '{request.Name}' already exists");
            }

            // Step 4: Create configuration
            var apiDataSourceConfig = new APIDataSourceConfig
            {
                Name = request.Name,
                IsEnabled = request.IsEnabled,
                IsRefreshing = request.IsRefreshing,
                TempFolderPath = !string.IsNullOrEmpty(request.TempFolderPath) ? 
                    _pathValidationService.NormalizePath(request.TempFolderPath) : null,
                ApiEndpoint = request.ApiEndpoint,
                ApiKey = request.ApiKey,
                PollingIntervalMinutes = request.PollingIntervalMinutes,
                AdditionalSettings = request.AdditionalSettings,
                CreatedAt = DateTime.UtcNow
            };

            _logger.LogInformation("Creating API DataSource in database: {Name} -> {ApiEndpoint}", 
                apiDataSourceConfig.Name, apiDataSourceConfig.ApiEndpoint);

            return await _repository.AddAsync(apiDataSourceConfig);
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
