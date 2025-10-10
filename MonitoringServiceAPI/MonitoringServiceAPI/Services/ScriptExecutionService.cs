using System.Diagnostics;
using System.Text;

namespace MonitoringServiceAPI.Services
{
    public class ScriptExecutionResult
    {
        public bool Success { get; set; }
        public int ExitCode { get; set; }
        public string Output { get; set; } = string.Empty;
        public string Error { get; set; } = string.Empty;
        public string? ErrorMessage { get; set; }
    }

    public interface IScriptExecutionService
    {
        Task<ScriptExecutionResult> ExecutePermissionScriptAsync(string folderPath, string? ownerUser = null);
        Task<bool> ValidateScriptExistsAsync();
        string GetScriptPath();
    }

    public class ScriptExecutionService : IScriptExecutionService
    {
        private readonly ILogger<ScriptExecutionService> _logger;
        private readonly IConfiguration _configuration;
        private readonly string _scriptPath;

        public ScriptExecutionService(
            ILogger<ScriptExecutionService> logger,
            IConfiguration configuration)
        {
            _logger = logger;
            _configuration = configuration;

            // Get script path from configuration or use default
            _scriptPath = configuration["ScriptPaths:PermissionScript"]
                ?? Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "scripts", "fix-monitored-folder-permissions.sh");

            _logger.LogInformation("Script path configured: {ScriptPath}", _scriptPath);
        }

        public string GetScriptPath() => _scriptPath;

        public async Task<bool> ValidateScriptExistsAsync()
        {
            var exists = File.Exists(_scriptPath);
            
            if (!exists)
            {
                _logger.LogWarning("Permission script not found at: {ScriptPath}", _scriptPath);
            }
            else
            {
                _logger.LogInformation("Permission script found at: {ScriptPath}", _scriptPath);
            }
            
            return await Task.FromResult(exists);
        }

        public async Task<ScriptExecutionResult> ExecutePermissionScriptAsync(
            string folderPath,
            string? ownerUser = null)
        {
            var result = new ScriptExecutionResult();

            try
            {
                // Validate script exists
                if (!await ValidateScriptExistsAsync())
                {
                    result.ErrorMessage = $"Permission script not found at: {_scriptPath}";
                    _logger.LogError(result.ErrorMessage);
                    return result;
                }

                // Validate folder path
                if (string.IsNullOrWhiteSpace(folderPath))
                {
                    result.ErrorMessage = "Folder path cannot be empty";
                    _logger.LogError(result.ErrorMessage);
                    return result;
                }

                // Build command arguments
                var arguments = new StringBuilder();
                arguments.Append($"--folder \"{folderPath}\"");

                if (!string.IsNullOrWhiteSpace(ownerUser))
                {
                    arguments.Append($" --owner \"{ownerUser}\"");
                }

                // Use absolute path to bash (required for sudo)
                var bashPath = "/bin/bash";
                if (!File.Exists(bashPath))
                {
                    bashPath = "/usr/bin/bash";
                }

                _logger.LogInformation("Executing permission script: {BashPath} {ScriptPath} {Arguments}", 
                    bashPath, _scriptPath, arguments.ToString());

                // Configure process - run with sudo for permission operations
                var processStartInfo = new ProcessStartInfo
                {
                    FileName = "sudo",
                    Arguments = $"{bashPath} {_scriptPath} {arguments}",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = new Process { StartInfo = processStartInfo };
                
                var outputBuilder = new StringBuilder();
                var errorBuilder = new StringBuilder();

                // Capture output
                process.OutputDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        outputBuilder.AppendLine(e.Data);
                        _logger.LogDebug("Script output: {Output}", e.Data);
                    }
                };

                process.ErrorDataReceived += (sender, e) =>
                {
                    if (!string.IsNullOrEmpty(e.Data))
                    {
                        errorBuilder.AppendLine(e.Data);
                        _logger.LogWarning("Script error: {Error}", e.Data);
                    }
                };

                // Start process
                process.Start();
                process.BeginOutputReadLine();
                process.BeginErrorReadLine();

                // Wait for completion with timeout (5 minutes)
                var completed = await Task.Run(() => process.WaitForExit(300000)); // 5 minutes timeout

                if (!completed)
                {
                    process.Kill();
                    result.ErrorMessage = "Script execution timed out after 5 minutes";
                    _logger.LogError(result.ErrorMessage);
                    return result;
                }

                result.ExitCode = process.ExitCode;
                result.Output = outputBuilder.ToString();
                result.Error = errorBuilder.ToString();
                result.Success = process.ExitCode == 0;

                if (result.Success)
                {
                    _logger.LogInformation("Permission script executed successfully for folder: {FolderPath}", folderPath);
                }
                else
                {
                    result.ErrorMessage = $"Script exited with code {result.ExitCode}";
                    _logger.LogError("Permission script failed with exit code {ExitCode} for folder: {FolderPath}", 
                        result.ExitCode, folderPath);
                }
            }
            catch (Exception ex)
            {
                result.ErrorMessage = $"Exception during script execution: {ex.Message}";
                _logger.LogError(ex, "Failed to execute permission script for folder: {FolderPath}", folderPath);
            }

            return result;
        }
    }
}
