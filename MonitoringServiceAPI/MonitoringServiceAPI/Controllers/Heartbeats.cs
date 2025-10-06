using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class Heartbeats : ControllerBase
    {
        private readonly IHeartbeatService _heartbeatService;
        public Heartbeats(IHeartbeatService heartbeatService)
        {
            _heartbeatService = heartbeatService;
        }

        [HttpGet("apiservice")]
        public async Task<IActionResult> GetAPIServiceHeartbeat()
        {
            return Ok(await _heartbeatService.GetAPIMonitorHeartbeatAsync());
        }

        [HttpGet("fileservice")]
        public async Task<IActionResult> GetFIleServiceHeartbeat()
        {
            return Ok(await _heartbeatService.GetFileMonitorHeartbeatAsync());
        }
    }
}
