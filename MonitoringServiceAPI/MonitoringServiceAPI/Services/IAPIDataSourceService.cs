using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Services
{
    public interface IAPIDataSourceService
    {
        Task<IEnumerable<APIDataSourceConfig>> GetAllAPIDataSourcesAsync();
        Task<APIDataSourceConfig?> GetAPIDataSourceByNameAsync(string name);
        Task<APIDataSourceConfig?> GetAPIDataSourceByIdAsync(int id);
        Task<APIDataSourceConfig> CreateAsync(CreateAPIDataSourceRequest request);
        Task<APIDataSourceConfig?> UpdateAsync(int id, UpdateAPIDataSourceRequest apiDataSourceConfig);
        Task<bool> DeleteAsync(int id);
        Task UpdateAPIDataSourceIsRefreshingFlagAsync(APIDataSourceConfig apiDataSourceConfig);
    }
}
