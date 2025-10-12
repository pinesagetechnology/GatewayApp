using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Models;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PushServerSettingController : ControllerBase
    {
        private readonly IPushServerSettingService _pushServerSettingService;
        private readonly ILogger<PushServerSettingController> _logger;

        public PushServerSettingController(
            IPushServerSettingService pushServerSettingService,
            ILogger<PushServerSettingController> logger)
        {
            _pushServerSettingService = pushServerSettingService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<ActionResult<PushServerSetting>> GetSetting()
        {
            try
            {
                var setting = await _pushServerSettingService.GetSettingAsync();
                
                if (setting == null)
                {
                    return NotFound(new { message = "PushServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving PushServerSetting");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }

        [HttpPut]
        public async Task<ActionResult<PushServerSetting>> UpdateSetting([FromBody] UpdatePushServerSettingRequest request)
        {
            try
            {
                var setting = await _pushServerSettingService.UpdateSettingAsync(
                    request.IsEnabled,
                    request.DataFolderPath,
                    request.UpdatedBy);

                if (setting == null)
                {
                    return NotFound(new { message = "PushServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating PushServerSetting");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }

        [HttpPatch("enable")]
        public async Task<ActionResult<PushServerSetting>> EnableService([FromBody] EnableServiceRequest? request)
        {
            try
            {
                var setting = await _pushServerSettingService.EnableServiceAsync(request?.UpdatedBy);

                if (setting == null)
                {
                    return NotFound(new { message = "PushServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error enabling push server");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }

        [HttpPatch("disable")]
        public async Task<ActionResult<PushServerSetting>> DisableService([FromBody] DisableServiceRequest? request)
        {
            try
            {
                var setting = await _pushServerSettingService.DisableServiceAsync(request?.UpdatedBy);

                if (setting == null)
                {
                    return NotFound(new { message = "PushServerSetting not found" });
                }

                return Ok(setting);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error disabling push server");
                return StatusCode(500, new { message = "Internal server error" });
            }
        }
    }

    public class UpdatePushServerSettingRequest
    {
        public bool IsEnabled { get; set; }
        public string DataFolderPath { get; set; } = string.Empty;
        public string? UpdatedBy { get; set; }
    }

    public class EnableServiceRequest
    {
        public string? UpdatedBy { get; set; }
    }

    public class DisableServiceRequest
    {
        public string? UpdatedBy { get; set; }
    }
}

