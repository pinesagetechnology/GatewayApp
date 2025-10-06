using FileMonitorWorkerService.Data.Repository;
using Microsoft.Extensions.DependencyInjection;
using MonitoringServiceAPI.Models;

namespace MonitoringServiceAPI.Services
{
    public interface IHeartbeatService
    {
        Task<FileMonitorServiceHeartBeat> GetFileMonitorHeartbeatAsync();
        Task<APIMonitorServiceHeartBeat> GetAPIMonitorHeartbeatAsync();
    }

    public class HeartbeatService: IHeartbeatService
    {
        private readonly IRepository<FileMonitorServiceHeartBeat> _fileHeartbeatRepository;
        private readonly IRepository<APIMonitorServiceHeartBeat> _apiHeartbeatRepository;

        public HeartbeatService(
            [FromKeyedServices("file")] IRepository<FileMonitorServiceHeartBeat> fileHeartbeatRepository,
            [FromKeyedServices("api")] IRepository<APIMonitorServiceHeartBeat> apiHeartbeatRepository
            )
        {
            _apiHeartbeatRepository = apiHeartbeatRepository;
            _fileHeartbeatRepository = fileHeartbeatRepository;
        }

        public async Task<APIMonitorServiceHeartBeat> GetAPIMonitorHeartbeatAsync()
        {
            var result = await _apiHeartbeatRepository.GetAllAsync();

            return result.FirstOrDefault() ?? new APIMonitorServiceHeartBeat { LastRun = null };
        }

        public async Task<FileMonitorServiceHeartBeat> GetFileMonitorHeartbeatAsync()
        {
            var result = await _fileHeartbeatRepository.GetAllAsync();

            return result.FirstOrDefault() ?? new FileMonitorServiceHeartBeat { LastRun = null };
        }
    }
}
