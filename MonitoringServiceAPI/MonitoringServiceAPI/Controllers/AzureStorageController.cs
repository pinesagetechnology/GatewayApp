using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AzureStorageController : ControllerBase
    {
        private readonly IAzureStorageService _azureService;
        private readonly IConfigurationService _configService;
        private readonly ILogger<AzureStorageController> _logger;

        public AzureStorageController(
            IAzureStorageService azureService,
            IConfigurationService configService,
            ILogger<AzureStorageController> logger)
        {
            _azureService = azureService;
            _configService = configService;
            _logger = logger;
        }

        [HttpGet("info")]
        public async Task<IActionResult> GetStorageInfo()
        {
            try
            {
                var info = await _azureService.GetStorageInfoAsync();
                return Ok(info);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get Azure Storage info");
                return StatusCode(500, new { Error = "Failed to get storage info", Details = ex.Message });
            }
        }

        [HttpGet("test-connection")]
        public async Task<IActionResult> TestConnection()
        {
            try
            {
                var isConnected = await _azureService.IsConnectedAsync();
                var result = new
                {
                    IsConnected = isConnected,
                    Status = isConnected ? "Connected" : "Not Connected",
                    TestedAt = DateTime.UtcNow
                };

                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to test Azure connection");
                return StatusCode(500, new { Error = "Connection test failed", Details = ex.Message });
            }
        }

        [HttpGet("containers")]
        public async Task<IActionResult> ListContainers()
        {
            try
            {
                var info = await _azureService.GetStorageInfoAsync();
                if (!info.IsConnected)
                {
                    return BadRequest(new { Error = "Not connected to Azure Storage", Details = info.ErrorMessage });
                }

                return Ok(new { Containers = info.Containers });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to list containers");
                return StatusCode(500, new { Error = "Failed to list containers", Details = ex.Message });
            }
        }

        [HttpGet("containers/{containerName}/blobs")]
        public async Task<IActionResult> ListBlobs(string containerName, [FromQuery] string? prefix = null)
        {
            try
            {
                var blobs = await _azureService.ListBlobsAsync(containerName, prefix);
                return Ok(new { Container = containerName, Prefix = prefix, Blobs = blobs });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to list blobs in container {ContainerName}", containerName);
                return StatusCode(500, new { Error = "Failed to list blobs", Details = ex.Message });
            }
        }

        [HttpPost("containers/{containerName}")]
        public async Task<IActionResult> CreateContainer(string containerName)
        {
            try
            {
                var success = await _azureService.CreateContainerIfNotExistsAsync(containerName);
                if (success)
                {
                    return Ok(new { Message = $"Container '{containerName}' created or already exists" });
                }
                else
                {
                    return StatusCode(500, new { Error = "Failed to create container" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create container {ContainerName}", containerName);
                return StatusCode(500, new { Error = "Failed to create container", Details = ex.Message });
            }
        }
    }
}
