using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Services;
using System.Text;

namespace MonitoringServiceAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class GpsController : ControllerBase
    {
        private readonly ILogger<GpsController> _logger;
        private readonly IGpsService _gpsService;

        public GpsController(ILogger<GpsController> logger, IGpsService gpsService)
        {
            _logger = logger;
            _gpsService = gpsService;
        }

        [HttpPost("push")]
        public async Task<IActionResult> Push()
        {
            try
            {
                // Check if the GPS server is enabled
                var isEnabled = await _gpsService.IsEnabledAsync();
                if (!isEnabled)
                {
                    _logger.LogWarning("GPS push request rejected - service is disabled");
                    return StatusCode(503, new { message = "GPS server is currently disabled" });
                }

                using var reader = new StreamReader(Request.Body, Encoding.UTF8);
                var payload = await reader.ReadToEndAsync();

                await _gpsService.SaveRawDataAsync(payload);

                var timestamp = DateTime.Now.ToString("o"); // ISO 8601 format

                _logger.LogInformation("GPS push received at {Timestamp}", timestamp);

                return Ok("OK");
            }
            catch (InvalidOperationException ex) when (ex.Message.Contains("disabled"))
            {
                _logger.LogWarning(ex, "GPS push request rejected - service is disabled");
                return StatusCode(503, new { message = "GPS server is currently disabled" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing GPS push request");
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

