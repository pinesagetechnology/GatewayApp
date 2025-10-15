using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Models;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class GpsServerSettingController : ControllerBase
    {
        private readonly IGpsServerSettingService _gpsServerSettingService;
        private readonly ILogger<GpsServerSettingController> _logger;

        public GpsServerSettingController(
            IGpsServerSettingService gpsServerSettingService,
            ILogger<GpsServerSettingController> logger)
        {
            _gpsServerSettingService = gpsServerSettingService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<GpsServerSetting>> GetSetting()
        {
            try
            {
                var setting = await _gpsServerSettingService.GetSettingAsync();
                
                if (setting == null)
                {
                    return NotFound(new { message = "GpsServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving GpsServerSetting");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }

        [HttpPut]
        public async Task<ActionResult<GpsServerSetting>> UpdateSetting([FromBody] UpdateGpsServerSettingRequest request)
        {
            try
            {
                var setting = await _gpsServerSettingService.UpdateSettingAsync(
                    request.IsEnabled,
                    request.DataFolderPath);

                if (setting == null)
                {
                    return NotFound(new { message = "GpsServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating GpsServerSetting");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }

        [HttpPatch("enable")]
        public async Task<ActionResult<GpsServerSetting>> EnableService()
        {
            try
            {
                var setting = await _gpsServerSettingService.EnableServiceAsync();

                if (setting == null)
                {
                    return NotFound(new { message = "GpsServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error enabling GPS server");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }

        [HttpPatch("disable")]
        public async Task<ActionResult<GpsServerSetting>> DisableService()
        {
            try
            {
                var setting = await _gpsServerSettingService.DisableServiceAsync();

                if (setting == null)
                {
                    return NotFound(new { message = "GpsServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error disabling GPS server");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }
    }

    public class UpdateGpsServerSettingRequest
    {
        public bool IsEnabled { get; set; }
        public string DataFolderPath { get; set; } = string.Empty;
    }
}

