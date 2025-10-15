using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;
using System.ComponentModel.DataAnnotations;

namespace MonitoringServiceAPI.Services
{
    public interface IGpsServerSettingService
    {
        Task<GpsServerSetting?> GetSettingAsync();
        Task<bool> IsEnabledAsync();
        Task<GpsServerSetting?> UpdateSettingAsync(bool isEnabled, string dataFolderPath);
        Task<GpsServerSetting?> EnableServiceAsync();
        Task<GpsServerSetting?> DisableServiceAsync();
    }

    public class GpsServerSettingService : IGpsServerSettingService
    {
        private readonly IRepository<GpsServerSetting> _repository;
        private readonly ILogger<GpsServerSettingService> _logger;
        private readonly IPathValidationService _pathValidationService;
        private readonly IScriptExecutionService _scriptExecutionService;

        public GpsServerSettingService(
            [FromKeyedServices("file")] IRepository<GpsServerSetting> repository,
            ILogger<GpsServerSettingService> logger,
            IPathValidationService pathValidationService,
            IScriptExecutionService scriptExecutionService)
        {
            _repository = repository;
            _logger = logger;
            _pathValidationService = pathValidationService;
            _scriptExecutionService = scriptExecutionService;
        }

        public async Task<GpsServerSetting?> GetSettingAsync()
        {
            try
            {
                var settings = await _repository.GetAllAsync();
                return settings.FirstOrDefault();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving GpsServerSetting from database");
                return null;
            }
        }

        public async Task<bool> IsEnabledAsync()
        {
            var setting = await GetSettingAsync();
            return setting?.IsEnabled ?? false;
        }

        public async Task<GpsServerSetting?> UpdateSettingAsync(bool isEnabled, string dataFolderPath)
        {
            try
            {
                var setting = await GetSettingAsync();

                if (setting == null)
                {
                    _logger.LogWarning("GpsServerSetting not found in database");
                    return null;
                }

                // Validate folder path
                if (string.IsNullOrWhiteSpace(dataFolderPath))
                {
                    throw new ValidationException("Folder path is required");
                }

                _logger.LogInformation("Validating GPS server folder path: {FolderPath}", dataFolderPath);
                var validation = await _pathValidationService.ValidateFolderPathAsync(dataFolderPath);

                if (!validation.IsValid)
                {
                    throw new ValidationException($"Invalid folder path: {validation.ErrorMessage}");
                }

                // Execute permission script if needed (folder doesn't exist or not accessible)
                if (validation.RequiresPermissionFix)
                {
                    _logger.LogInformation("Executing permission fix script for GPS server folder: {FolderPath}", dataFolderPath);

                    var scriptResult = await _scriptExecutionService.ExecutePermissionScriptAsync(dataFolderPath);

                    if (!scriptResult.Success)
                    {
                        var errorDetails = $"Failed to setup folder permissions: {scriptResult.ErrorMessage}\n" +
                                         $"Exit Code: {scriptResult.ExitCode}\n" +
                                         $"Output: {scriptResult.Output}\n" +
                                         $"Error: {scriptResult.Error}";
                        
                        _logger.LogError("Permission script failed: {ErrorDetails}", errorDetails);
                        throw new InvalidOperationException(errorDetails);
                    }

                    _logger.LogInformation("Permission script completed successfully for GPS server folder");
                }
                else
                {
                    _logger.LogInformation("GPS server folder permissions are already correct, skipping script execution");
                }

                // Update settings
                setting.IsEnabled = isEnabled;
                setting.DataFolderPath = _pathValidationService.NormalizePath(dataFolderPath);

                await _repository.UpdateAsync(setting);

                _logger.LogInformation("GpsServerSetting updated: IsEnabled={IsEnabled}, DataFolderPath={DataFolderPath}",
                    setting.IsEnabled, setting.DataFolderPath);

                return setting;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating GpsServerSetting");
                throw;
            }
        }

        public async Task<GpsServerSetting?> EnableServiceAsync()
        {
            try
            {
                var setting = await GetSettingAsync();

                if (setting == null)
                {
                    _logger.LogWarning("GpsServerSetting not found in database");
                    return null;
                }

                setting.IsEnabled = true;

                await _repository.UpdateAsync(setting);

                _logger.LogInformation("GPS server enabled");

                return setting;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error enabling GPS server");
                throw;
            }
        }

        public async Task<GpsServerSetting?> DisableServiceAsync()
        {
            try
            {
                var setting = await GetSettingAsync();

                if (setting == null)
                {
                    _logger.LogWarning("GpsServerSetting not found in database");
                    return null;
                }

                setting.IsEnabled = false;

                await _repository.UpdateAsync(setting);

                _logger.LogInformation("GPS server disabled");

                return setting;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error disabling GPS server");
                throw;
            }
        }
    }
}

