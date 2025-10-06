using Azure.Storage.Blobs.Models;
using Azure.Storage.Blobs;
using Azure.Storage;
using Azure;
using MonitoringServiceAPI.Models;
using System.Diagnostics;

namespace MonitoringServiceAPI.Services
{
    public interface IAzureStorageService
    {
        Task<bool> IsConnectedAsync();
        Task<bool> BlobExistsAsync(string containerName, string blobName);
        Task<IEnumerable<string>> ListBlobsAsync(string containerName, string? prefix = null);
        Task<bool> CreateContainerIfNotExistsAsync(string containerName);
        Task<AzureStorageInfo> GetStorageInfoAsync();
    }

    public class AzureStorageService : IAzureStorageService
    {
        private BlobServiceClient? _blobServiceClient;
        private readonly IConfigurationService _configService;
        private readonly ILogger<AzureStorageService> _logger;
        private readonly SemaphoreSlim _connectionSemaphore = new(1, 1);

        public AzureStorageService(IConfigurationService configService, ILogger<AzureStorageService> logger)
        {
            _configService = configService;
            _logger = logger;
            _logger.LogDebug("AzureStorageService initialized");
        }

        private async Task<BlobServiceClient?> GetBlobServiceClientAsync()
        {
            if (_blobServiceClient != null)
            {
                _logger.LogDebug("Using existing BlobServiceClient instance");
                return _blobServiceClient;
            }

            _logger.LogDebug("Initializing new BlobServiceClient...");
            try
            {
                var connectionString = await _configService.GetValueAsync("Azure.StorageConnectionString");
                if (!string.IsNullOrEmpty(connectionString))
                {
                    _logger.LogDebug("Azure Storage connection string found, creating BlobServiceClient");
                    _blobServiceClient = new BlobServiceClient(connectionString);
                    _logger.LogInformation("BlobServiceClient initialized successfully");
                    return _blobServiceClient;
                }
                else
                {
                    _logger.LogWarning("Azure Storage connection string is not configured");
                    return null;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize Azure Storage client");
                return null;
            }
        }

        public async Task<bool> IsConnectedAsync()
        {
            _logger.LogDebug("Testing Azure Storage connection...");
            var blobServiceClient = await GetBlobServiceClientAsync();
            if (blobServiceClient == null)
            {
                _logger.LogWarning("Cannot test connection - BlobServiceClient is null");
                return false;
            }

            await _connectionSemaphore.WaitAsync();
            try
            {
                _logger.LogDebug("Attempting to get Azure Storage account properties...");
                var properties = await blobServiceClient.GetPropertiesAsync();
                _logger.LogInformation("Azure Storage connection test successful - Account: {AccountName}",
                    blobServiceClient.AccountName);
                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Azure Storage connection test failed");
                return false;
            }
            finally
            {
                _connectionSemaphore.Release();
            }
        }

        public async Task<bool> BlobExistsAsync(string containerName, string blobName)
        {
            _logger.LogDebug("Checking if blob exists: {Container}/{BlobName}", containerName, blobName);
            try
            {
                var blobServiceClient = await GetBlobServiceClientAsync();
                if (blobServiceClient == null)
                {
                    _logger.LogWarning("Cannot check blob existence - BlobServiceClient is null");
                    return false;
                }

                var containerClient = blobServiceClient.GetBlobContainerClient(containerName);
                var blobClient = containerClient.GetBlobClient(blobName);
                var response = await blobClient.ExistsAsync();

                _logger.LogDebug("Blob {Container}/{BlobName} exists: {Exists}", containerName, blobName, response.Value);
                return response.Value;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking if blob exists: {ContainerName}/{BlobName}", containerName, blobName);
                return false;
            }
        }

        public async Task<IEnumerable<string>> ListBlobsAsync(string containerName, string? prefix = null)
        {
            _logger.LogDebug("Listing blobs in container: {Container} (prefix: {Prefix})", containerName, prefix ?? "None");
            try
            {
                var blobServiceClient = await GetBlobServiceClientAsync();
                if (blobServiceClient == null)
                {
                    _logger.LogWarning("Cannot list blobs - BlobServiceClient is null");
                    return Enumerable.Empty<string>();
                }

                var containerClient = blobServiceClient.GetBlobContainerClient(containerName);
                var blobs = new List<string>();

                await foreach (var blobItem in containerClient.GetBlobsAsync(prefix: prefix))
                {
                    blobs.Add(blobItem.Name);
                }

                _logger.LogDebug("Found {Count} blobs in container {Container}", blobs.Count, containerName);
                return blobs;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error listing blobs in container: {ContainerName}", containerName);
                return Enumerable.Empty<string>();
            }
        }

        public async Task<bool> CreateContainerIfNotExistsAsync(string containerName)
        {
            _logger.LogDebug("Creating container if not exists: {ContainerName}", containerName);
            try
            {
                var blobServiceClient = await GetBlobServiceClientAsync();
                if (blobServiceClient == null)
                {
                    _logger.LogWarning("Cannot create container - BlobServiceClient is null");
                    return false;
                }

                var containerClient = blobServiceClient.GetBlobContainerClient(containerName);
                var response = await containerClient.CreateIfNotExistsAsync(PublicAccessType.None);

                if (response != null)
                {
                    _logger.LogInformation("Created new container: {ContainerName}", containerName);
                }
                else
                {
                    _logger.LogDebug("Container already exists: {ContainerName}", containerName);
                }

                return true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error creating container: {ContainerName}", containerName);
                return false;
            }
        }

        public async Task<AzureStorageInfo> GetStorageInfoAsync()
        {
            _logger.LogDebug("Getting Azure Storage information...");
            var info = new AzureStorageInfo();

            try
            {
                var blobServiceClient = await GetBlobServiceClientAsync();
                if (blobServiceClient == null)
                {
                    info.ErrorMessage = "Azure Storage client is not initialized";
                    _logger.LogWarning("Cannot get storage info - BlobServiceClient is null");
                    return info;
                }

                // Test connection
                _logger.LogDebug("Testing connection by getting account properties...");
                var properties = await blobServiceClient.GetPropertiesAsync();
                info.IsConnected = true;
                info.AccountName = blobServiceClient.AccountName;
                _logger.LogInformation("Azure Storage account connected: {AccountName}", info.AccountName);

                // List containers
                _logger.LogDebug("Listing containers...");
                var containers = new List<string>();
                await foreach (var container in blobServiceClient.GetBlobContainersAsync())
                {
                    containers.Add(container.Name);
                }
                info.Containers = containers;

                _logger.LogInformation("Found {Count} containers in Azure Storage account", containers.Count);

                return info;
            }
            catch (Exception ex)
            {
                info.ErrorMessage = ex.Message;
                _logger.LogError(ex, "Error getting Azure Storage info");
                return info;
            }
        }
    }
}