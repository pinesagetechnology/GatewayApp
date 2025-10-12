using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Services;
using System.Text;

namespace MonitoringServiceAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class VivotekController : ControllerBase
    {
        private readonly ILogger<VivotekController> _logger;
        private readonly IVivotekService _dataStorageService;

        public VivotekController(ILogger<VivotekController> logger, IVivotekService dataStorageService)
        {
            _logger = logger;
            _dataStorageService = dataStorageService;
        }

        [HttpPost("push")]
        public async Task<IActionResult> Push()
        {
            try
            {
                // Check if the push server is enabled
                var isEnabled = await _dataStorageService.IsEnabledAsync();
                if (!isEnabled)
                {
                    _logger.LogWarning("Push request rejected - service is disabled");
                    return StatusCode(503, new { message = "Push server is currently disabled" });
                }

                using var reader = new StreamReader(Request.Body, Encoding.UTF8);
                var payload = await reader.ReadToEndAsync();

                await _dataStorageService.SaveRawDataAsync(payload);

                var timestamp = DateTime.Now.ToString("o"); // ISO 8601 format

                _logger.LogInformation("Push received at {Timestamp}", timestamp);

                return Ok("OK");
            }
            catch (InvalidOperationException ex) when (ex.Message.Contains("disabled"))
            {
                _logger.LogWarning(ex, "Push request rejected - service is disabled");
                return StatusCode(503, new { message = "Push server is currently disabled" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing push request");
                return Ok("OK");
            }
        }

        [HttpGet("health")]
        public IActionResult Health()
        {
            return Ok(new { status = "healthy", timestamp = DateTime.UtcNow });
        }
    }
}
