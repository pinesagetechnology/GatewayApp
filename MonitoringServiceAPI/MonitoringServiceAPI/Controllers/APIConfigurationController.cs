using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Models;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class APIConfigurationController : ControllerBase
    {
        private readonly IApiConfigurationService _configService;
        private readonly ILogger<APIConfigurationController> _logger;

        public APIConfigurationController(ILogger<APIConfigurationController> logger,
            IApiConfigurationService configService)
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
                _logger.LogError(ex, "Failed to retrieve API configurations");
                return StatusCode(500, new { Error = "Failed to retrieve API configurations", Details = ex.Message });
            }
        }

        [HttpPost("config")]
        public async Task<IActionResult> SetConfig([FromBody] SetConfigRequest request)
        {
            try
            {
                await _configService.SetValueAsync(request.Key, request.Value, request.Description, request.Category);
                return Ok(new { Message = "API configuration updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to update API configuration");
                return BadRequest(new { Error = "Failed to update API configuration", Details = ex.Message });
            }
        }
    }
}


