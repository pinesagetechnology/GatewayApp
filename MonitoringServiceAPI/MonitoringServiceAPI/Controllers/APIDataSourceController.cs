using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Models;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class APIDataSourceController : ControllerBase
    {
        private readonly IAPIDataSourceService _apiDataSourceService;
        private readonly ILogger<APIDataSourceController> _logger;

        public APIDataSourceController(
            IAPIDataSourceService apiDataSourceService,
            ILogger<APIDataSourceController> logger)
        {
            _apiDataSourceService = apiDataSourceService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> GetAPIDataSources()
        {
            try
            {
                var apiDataSources = await _apiDataSourceService.GetAllAPIDataSourcesAsync();
                return Ok(apiDataSources);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to retrieve API data sources");
                return StatusCode(500, new { Error = "Failed to retrieve API data sources", Details = ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetAPIDataSource(int id)
        {
            try
            {
                var apiDataSource = await _apiDataSourceService.GetAPIDataSourceByIdAsync(id);
                if (apiDataSource == null)
                {
                    return NotFound(new { Error = "API data source not found" });
                }
                return Ok(apiDataSource);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to retrieve API data source {Id}", id);
                return StatusCode(500, new { Error = "Failed to retrieve API data source", Details = ex.Message });
            }
        }

        [HttpGet("byname/{name}")]
        public async Task<IActionResult> GetAPIDataSourceByName(string name)
        {
            try
            {
                var apiDataSource = await _apiDataSourceService.GetAPIDataSourceByNameAsync(name);
                if (apiDataSource == null)
                {
                    return NotFound(new { Error = "API data source not found" });
                }
                return Ok(apiDataSource);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to retrieve API data source by name {Name}", name);
                return StatusCode(500, new { Error = "Failed to retrieve API data source", Details = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> CreateAPIDataSource([FromBody] CreateAPIDataSourceRequest request)
        {
            try
            {
                var apiDataSource = await _apiDataSourceService.CreateAsync(request);
                return CreatedAtAction(nameof(GetAPIDataSource), new { id = apiDataSource.Id }, apiDataSource);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create API data source");
                return BadRequest(new { Error = "Failed to create API data source", Details = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateAPIDataSource(int id, [FromBody] UpdateAPIDataSourceRequest request)
        {
            try
            {
                var apiDataSource = await _apiDataSourceService.UpdateAsync(id, request);
                if (apiDataSource == null)
                {
                    return NotFound(new { Error = "API data source not found" });
                }
                return Ok(apiDataSource);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to update API data source {Id}", id);
                return BadRequest(new { Error = "Failed to update API data source", Details = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteAPIDataSource(int id)
        {
            try
            {
                var success = await _apiDataSourceService.DeleteAsync(id);
                if (!success)
                {
                    return NotFound(new { Error = "API data source not found" });
                }
                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to delete API data source {Id}", id);
                return StatusCode(500, new { Error = "Failed to delete API data source", Details = ex.Message });
            }
        }

        [HttpPatch("{id}/refreshing")]
        public async Task<IActionResult> UpdateRefreshingFlag(int id, [FromBody] bool isRefreshing)
        {
            try
            {
                var apiDataSource = await _apiDataSourceService.GetAPIDataSourceByIdAsync(id);
                if (apiDataSource == null)
                {
                    return NotFound(new { Error = "API data source not found" });
                }

                apiDataSource.IsRefreshing = isRefreshing;
                await _apiDataSourceService.UpdateAPIDataSourceIsRefreshingFlagAsync(apiDataSource);
                
                return Ok(new { Message = "Refreshing flag updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to update refreshing flag for API data source {Id}", id);
                return StatusCode(500, new { Error = "Failed to update refreshing flag", Details = ex.Message });
            }
        }
    }
}
