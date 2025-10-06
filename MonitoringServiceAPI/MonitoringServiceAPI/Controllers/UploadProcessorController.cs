using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Models;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UploadProcessorController : ControllerBase
    {
        private readonly ILogger<UploadProcessorController> _logger;
        private readonly IUploadQueueService _uploadQueueService;


        public UploadProcessorController(ILogger<UploadProcessorController> logger,
            IUploadQueueService uploadQueueService)
        {
            _logger = logger;
            _uploadQueueService = uploadQueueService;
        }

        [HttpGet("all")]
        public async Task<IActionResult> GetAllUploads()
        {
            try
            {
                var allUploads = await _uploadQueueService.GetAllUploadsAsync();
                return Ok(allUploads);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving all uploads");
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpGet("pending")]
        public async Task<IActionResult> GetPendingUploads()
        {
            try
            {
                var pendingUploads = await _uploadQueueService.GetPendingUploadsAsync();
                return Ok(pendingUploads);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving pending uploads");
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpGet("failed")]
        public async Task<IActionResult> GetFailedUploads()
        {
            try
            {
                var failedUploads = await _uploadQueueService.GetFailedUploadsAsync();
                return Ok(failedUploads);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving failed uploads");
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpGet("summary")]
        public async Task<IActionResult> GetQueueSummary()
        {
            try
            {
                var summary = await _uploadQueueService.GetQueueSummaryAsync();
                return Ok(summary);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving queue summary");
                return StatusCode(500, "Internal server error");
            }
        }

        [HttpPut("reprocess/{id}")]
        public async Task<IActionResult> ReprocessUpload(int id)
        {
            try
            {
                await _uploadQueueService.ReprocessItem(id);
                return NoContent();
            }
            catch (KeyNotFoundException)
            {
                return NotFound($"Upload item with ID {id} not found.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error reprocessing upload item with ID {id}");
                return StatusCode(500, "Internal server error");
            }
        }
    }
}
