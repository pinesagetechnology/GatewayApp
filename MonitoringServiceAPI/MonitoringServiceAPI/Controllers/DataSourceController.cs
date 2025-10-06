using Microsoft.AspNetCore.Mvc;
using MonitoringServiceAPI.Models;
using MonitoringServiceAPI.Services;

namespace MonitoringServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class DataSourceController : ControllerBase
    {
        private readonly IDataSourceService _dataSourceService;
        private readonly ILogger<DataSourceController> _logger;

        public DataSourceController(
            IDataSourceService dataSourceService,
            ILogger<DataSourceController> logger)
        {
            _dataSourceService = dataSourceService;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> GetDataSources()
        {
            try
            {
                var dataSources = await _dataSourceService.GetAllDataSourcesAsync();
                return Ok(dataSources);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to retrieve data sources");
                return StatusCode(500, new { Error = "Failed to retrieve data sources", Details = ex.Message });
            }
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDataSource(int id)
        {
            try
            {
                var dataSource = await _dataSourceService.GetDataSourcesByIdAsync(id);
                if (dataSource == null)
                {
                    return NotFound(new { Error = "Data source not found" });
                }
                return Ok(dataSource);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to retrieve data source {Id}", id);
                return StatusCode(500, new { Error = "Failed to retrieve data source", Details = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> CreateDataSource([FromBody] CreateDataSourceRequest request)
        {
            try
            {
                var dataSource = await _dataSourceService.CreateAsync(request);
                return CreatedAtAction(nameof(GetDataSource), new { id = dataSource.Id }, dataSource);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create data source");
                return BadRequest(new { Error = "Failed to create data source", Details = ex.Message });
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateDataSource(int id, [FromBody] UpdateDataSourceRequest request)
        {
            try
            {
                var dataSource = await _dataSourceService.UpdateAsync(id, request);
                if (dataSource == null)
                {
                    return NotFound(new { Error = "Data source not found" });
                }
                return Ok(dataSource);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to update data source {Id}", id);
                return BadRequest(new { Error = "Failed to update data source", Details = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteDataSource(int id)
        {
            try
            {
                var success = await _dataSourceService.DeleteAsync(id);
                if (!success)
                {
                    return NotFound(new { Error = "Data source not found" });
                }
                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to delete data source {Id}", id);
                return StatusCode(500, new { Error = "Failed to delete data source", Details = ex.Message });
            }
        }
    }
}
