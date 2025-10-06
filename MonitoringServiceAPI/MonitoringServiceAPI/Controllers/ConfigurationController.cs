using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Models;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ConfigurationController : ControllerBase
    {
        private readonly IConfigurationService _configService;
        private readonly ILogger<ConfigurationController> _logger;

        public ConfigurationController( ILogger<ConfigurationController> logger, 
            IConfigurationService configService)
        {
            _configService = configService;
            _logger = logger;
        }

        [HttpGet("config")]
        public async Task<IActionResult> GetAllConfig()
        {
            try
            {
                var configs = await _configService.GetAllAsync();
                return Ok(configs.Select(c => new
                {
                    c.Key,
                    c.Value,
                    c.Description,
                    c.Category,
                    c.UpdatedAt
                }));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to retrieve configurations");
                return StatusCode(500, new { Error = "Failed to retrieve configurations", Details = ex.Message });
            }
        }

        [HttpPost("config")]
        public async Task<IActionResult> SetConfig([FromBody] SetConfigRequest request)
        {
            try
            {
                await _configService.SetValueAsync(request.Key, request.Value, request.Description, request.Category);
                return Ok(new { Message = "Configuration updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to update configuration");
                return BadRequest(new { Error = "Failed to update configuration", Details = ex.Message });
            }
        }
    }
}
