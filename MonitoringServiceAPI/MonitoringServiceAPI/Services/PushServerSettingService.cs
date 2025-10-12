using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;
using System.ComponentModel.DataAnnotations;

namespace MonitoringServiceAPI.Services
{
    public interface IPushServerSettingService
    {
        Task<PushServerSetting?> GetSettingAsync();
        Task<bool> IsEnabledAsync();
        Task<PushServerSetting?> UpdateSettingAsync(bool isEnabled, string dataFolderPath, string? updatedBy = null);
        Task<PushServerSetting?> EnableServiceAsync(string? updatedBy = null);
        Task<PushServerSetting?> DisableServiceAsync(string? updatedBy = null);
    }

    public class PushServerSettingService : IPushServerSettingService
    {
        private readonly IRepository<PushServerSetting> _repository;
        private readonly ILogger<PushServerSettingService> _logger;
        private readonly IPathValidationService _pathValidationService;
        private readonly IScriptExecutionService _scriptExecutionService;

        public PushServerSettingService(
            [FromKeyedServices("file")] IRepository<PushServerSetting> repository,
            ILogger<PushServerSettingService> logger,
            IPathValidationService pathValidationService,
            IScriptExecutionService scriptExecutionService)
        {
            _repository = repository;
            _logger = logger;
            _pathValidationService = pathValidationService;
            _scriptExecutionService = scriptExecutionService;
        }

        public async Task<PushServerSetting?> GetSettingAsync()
        {
            try
            {
                var settings = await _repository.GetAllAsync();
                return settings.FirstOrDefault();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving PushServerSetting from database");
                return null;
            }
        }

        public async Task<bool> IsEnabledAsync()
        {
            var setting = await GetSettingAsync();
            return setting?.IsEnabled ?? false;
        }

        public async Task<PushServerSetting?> UpdateSettingAsync(bool isEnabled, string dataFolderPath, string? updatedBy = null)
        {
            try
            {
                var setting = await GetSettingAsync();

                if (setting == null)
                {
                    _logger.LogWarning("PushServerSetting not found in database");
                    return null;
                }

                // Validate folder path
                if (string.IsNullOrWhiteSpace(dataFolderPath))
                {
                    throw new ValidationException("Folder path is required");
                }

                _logger.LogInformation("Validating push server folder path: {FolderPath}", dataFolderPath);
                var validation = await _pathValidationService.ValidateFolderPathAsync(dataFolderPath);

                if (!validation.IsValid)
                {
                    throw new ValidationException($"Invalid folder path: {validation.ErrorMessage}");
                }

                // Execute permission script if needed (folder doesn't exist or not accessible)
                if (validation.RequiresPermissionFix)
                {
                    _logger.LogInformation("Executing permission fix script for push server folder: {FolderPath}", dataFolderPath);

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

                    _logger.LogInformation("Permission script completed successfully for push server folder");
                }
                else
                {
                    _logger.LogInformation("Push server folder permissions are already correct, skipping script execution");
                }

                // Update settings
                setting.IsEnabled = isEnabled;
                setting.DataFolderPath = _pathValidationService.NormalizePath(dataFolderPath);
                setting.UpdatedAt = DateTime.UtcNow;
                setting.UpdatedBy = updatedBy ?? "API";

                await _repository.UpdateAsync(setting);

                _logger.LogInformation("PushServerSetting updated: IsEnabled={IsEnabled}, DataFolderPath={DataFolderPath}, UpdatedBy={UpdatedBy}",
                    setting.IsEnabled, setting.DataFolderPath, setting.UpdatedBy);

                return setting;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating PushServerSetting");
                throw;
            }
        }

        public async Task<PushServerSetting?> EnableServiceAsync(string? updatedBy = null)
        {
            try
            {
                var setting = await GetSettingAsync();

                if (setting == null)
                {
                    _logger.LogWarning("PushServerSetting not found in database");
                    return null;
                }

                setting.IsEnabled = true;
                setting.UpdatedAt = DateTime.UtcNow;
                setting.UpdatedBy = updatedBy ?? "API";

                await _repository.UpdateAsync(setting);

                _logger.LogInformation("Push server enabled by {UpdatedBy}", setting.UpdatedBy);

                return setting;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error enabling push server");
                throw;
            }
        }

        public async Task<PushServerSetting?> DisableServiceAsync(string? updatedBy = null)
        {
            try
            {
                var setting = await GetSettingAsync();

                if (setting == null)
                {
                    _logger.LogWarning("PushServerSetting not found in database");
                    return null;
                }

                setting.IsEnabled = false;
                setting.UpdatedAt = DateTime.UtcNow;
                setting.UpdatedBy = updatedBy ?? "API";

                await _repository.UpdateAsync(setting);

                _logger.LogInformation("Push server disabled by {UpdatedBy}", setting.UpdatedBy);

                return setting;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error disabling push server");
                throw;
            }
        }
    }
}

