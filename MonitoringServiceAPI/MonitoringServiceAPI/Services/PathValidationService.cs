namespace MonitoringServiceAPI.Services
{
    public class PathValidationResult
    {
        public bool IsValid { get; set; }
        public bool Exists { get; set; }
        public bool IsAccessible { get; set; }
        public bool RequiresPermissionFix { get; set; }
        public string? ErrorMessage { get; set; }
        public List<string> Warnings { get; set; } = new();
    }

    public interface IPathValidationService
    {
        Task<PathValidationResult> ValidateFolderPathAsync(string path);
        bool IsAbsolutePath(string path);
        string NormalizePath(string path);
    }

    public class PathValidationService : IPathValidationService
    {
        private readonly ILogger<PathValidationService> _logger;

        public PathValidationService(ILogger<PathValidationService> logger)
        {
            _logger = logger;
        }

        public async Task<PathValidationResult> ValidateFolderPathAsync(string path)
        {
            var result = new PathValidationResult();

            _logger.LogInformation("Validating folder path: {Path}", path);

            // Check if path is null or empty
            if (string.IsNullOrWhiteSpace(path))
            {
                result.ErrorMessage = "Path cannot be empty";
                _logger.LogWarning("Path validation failed: empty path");
                return result;
            }

            // Check if absolute path
            if (!IsAbsolutePath(path))
            {
                result.ErrorMessage = "Path must be absolute (start with /)";
                _logger.LogWarning("Path validation failed: {Path} is not absolute", path);
                return result;
            }

            // Check for dangerous patterns
            if (path.Contains("..") || path.Contains("//"))
            {
                result.ErrorMessage = "Path contains invalid patterns (./ or //)";
                _logger.LogWarning("Path validation failed: {Path} contains dangerous patterns", path);
                return result;
            }

            // Normalize path
            var normalizedPath = NormalizePath(path);
            _logger.LogDebug("Normalized path: {NormalizedPath}", normalizedPath);

            // Check if path exists
            result.Exists = Directory.Exists(normalizedPath);
            
            if (!result.Exists)
            {
                result.RequiresPermissionFix = true;
                result.Warnings.Add("Folder does not exist and will be created");
                _logger.LogInformation("Folder does not exist: {Path}", normalizedPath);
            }
            else
            {
                // Check if accessible (will fail if no permissions)
                result.IsAccessible = await CheckAccessibilityAsync(normalizedPath);
                
                if (!result.IsAccessible)
                {
                    result.RequiresPermissionFix = true;
                    result.Warnings.Add("Folder exists but requires permission fix");
                    _logger.LogWarning("Folder exists but is not accessible: {Path}", normalizedPath);
                }
                else
                {
                    _logger.LogInformation("Folder is accessible: {Path}", normalizedPath);
                }
            }

            result.IsValid = true;
            _logger.LogInformation("Path validation completed: Valid={IsValid}, Exists={Exists}, Accessible={IsAccessible}, RequiresFix={RequiresFix}", 
                result.IsValid, result.Exists, result.IsAccessible, result.RequiresPermissionFix);

            return result;
        }

        public bool IsAbsolutePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return false;

            // On Linux/Unix, absolute paths start with /
            return path.StartsWith("/");
        }

        public string NormalizePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
                return path;

            try
            {
                // Remove trailing slashes
                path = path.TrimEnd('/');
                
                // Get full path (this also resolves . and .. if present)
                return Path.GetFullPath(path);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to normalize path: {Path}", path);
                return path;
            }
        }

        private async Task<bool> CheckAccessibilityAsync(string path)
        {
            try
            {
                // Try to list directory contents
                await Task.Run(() =>
                {
                    var files = Directory.GetFiles(path).Take(1).ToList();
                    var dirs = Directory.GetDirectories(path).Take(1).ToList();
                });
                
                return true;
            }
            catch (UnauthorizedAccessException)
            {
                _logger.LogWarning("Access denied to path: {Path}", path);
                return false;
            }
            catch (DirectoryNotFoundException)
            {
                _logger.LogWarning("Directory not found: {Path}", path);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking accessibility of path: {Path}", path);
                return false;
            }
        }
    }
}

