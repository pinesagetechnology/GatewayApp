import { FileDataSourceConfig } from '@/models/FileDataSource';
import { APIDataSourceConfig } from '@/models/APIDataSource';
import { AzureStorageInfo } from '@/models/AzureStorageInfo';
import { QueueItem, QueueSummary } from '@/models/UploadProcessor';
import { Heartbeat } from '@/models/Heartbeat';
import { PushServerSetting, UpdatePushServerSettingRequest, EnableServiceRequest, DisableServiceRequest } from '@/models/PushServerSetting';
import axios, { AxiosResponse } from 'axios';
import { CreateDataSourceRequest, UpdateDataSourceRequest, SetConfigRequest } from '@/models/Requests';
import { ApiError } from '@/models/ApiError';

// Use relative base URL so the browser calls the same host serving the UI (Nginx),
// and let Nginx proxy /api and /hubs to the backend (e.g., localhost:5000) on the device.
// In development, use relative URLs to go through webpack dev server proxy
const API_BASE_URL = '';

const apiClient = axios.create({
    baseURL: API_BASE_URL,
    timeout: 30000,
    headers: {
        'Content-Type': 'application/json',
    },
});

// Request interceptor
apiClient.interceptors.request.use(
    (config) => {
        // Add auth token if available
        const token = localStorage.getItem('authToken');
        if (token && config.headers) {
            config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
    },
    (error) => {
        return Promise.reject(error);
    }
);

// Response interceptor
apiClient.interceptors.response.use(
    (response: AxiosResponse) => response,
    (error) => {
        if (error.response?.status === 401) {
            // Handle unauthorized access
            localStorage.removeItem('authToken');
            window.location.href = '/login';
        }
        return Promise.reject(error);
    }
);

// API service methods - Updated for simplified API
export const apiService = {
    // Health check (basic endpoint)
    getHealth: (): Promise<AxiosResponse<any>> =>
        apiClient.get('/health'),

    // File Data sources
    getDataSources: (): Promise<AxiosResponse<FileDataSourceConfig[]>> =>
        apiClient.get('/api/DataSource'),
    getDataSource: (id: string | number): Promise<AxiosResponse<FileDataSourceConfig>> =>
        apiClient.get(`/api/DataSource/${id}`),
    createDataSource: (data: Partial<CreateDataSourceRequest>): Promise<AxiosResponse<CreateDataSourceRequest>> =>
        apiClient.post('/api/DataSource', data),
    updateDataSource: (id: string | number, data: Partial<UpdateDataSourceRequest>): Promise<AxiosResponse<UpdateDataSourceRequest>> =>
        apiClient.put(`/api/DataSource/${id}`, data),
    deleteDataSource: (id: string | number): Promise<AxiosResponse<void>> =>
        apiClient.delete(`/api/DataSource/${id}`),

    // API Data sources
    getAPIDataSources: (): Promise<AxiosResponse<APIDataSourceConfig[]>> =>
        apiClient.get('/api/APIDataSource'),
    getAPIDataSource: (id: string | number): Promise<AxiosResponse<APIDataSourceConfig>> =>
        apiClient.get(`/api/APIDataSource/${id}`),
    getAPIDataSourceByName: (name: string): Promise<AxiosResponse<APIDataSourceConfig>> =>
        apiClient.get(`/api/APIDataSource/byname/${name}`),
    createAPIDataSource: (data: Partial<APIDataSourceConfig>): Promise<AxiosResponse<APIDataSourceConfig>> =>
        apiClient.post('/api/APIDataSource', data),
    updateAPIDataSource: (id: string | number, data: Partial<APIDataSourceConfig>): Promise<AxiosResponse<APIDataSourceConfig>> =>
        apiClient.put(`/api/APIDataSource/${id}`, data),
    deleteAPIDataSource: (id: string | number): Promise<AxiosResponse<void>> =>
        apiClient.delete(`/api/APIDataSource/${id}`),

    // Azure Storage (working endpoints)
    getAzureStorageInfo: (): Promise<AxiosResponse<AzureStorageInfo>> =>
        apiClient.get('/api/AzureStorage/info'),
    testAzureConnection: (): Promise<AxiosResponse<any>> =>
        apiClient.get('/api/AzureStorage/test-connection'),
    listContainers: (): Promise<AxiosResponse<any>> =>
        apiClient.get('/api/AzureStorage/containers'),
    listBlobs: (containerName: string, prefix?: string): Promise<AxiosResponse<any>> =>
        apiClient.get(`/api/AzureStorage/containers/${containerName}/blobs`, {
            params: { prefix }
        }),
    createContainer: (containerName: string): Promise<AxiosResponse<void>> =>
        apiClient.post(`/api/AzureStorage/containers/${containerName}`),
    deleteBlob: (containerName: string, blobName: string): Promise<AxiosResponse<void>> =>
        apiClient.delete(`/api/AzureStorage/containers/${containerName}/blobs/${blobName}`),
    configureAzureStorage: (config: any): Promise<AxiosResponse<void>> =>
        apiClient.post('/api/azurestorage/configure', config),

    // File Monitor Configuration
    getConfiguration: (): Promise<AxiosResponse<any>> =>
        apiClient.get('/api/Configuration/config'),
    getConfigurations: (): Promise<AxiosResponse<any>> =>
        apiClient.get('/api/Configuration/config'),
    setConfigRequest: (config: SetConfigRequest): Promise<AxiosResponse<void>> =>
        apiClient.post('/api/Configuration/config', config),

    // API Service Configuration
    getApiConfiguration: (): Promise<AxiosResponse<any>> =>
        apiClient.get('/api/APIConfiguration/config'),
    setApiConfigRequest: (config: SetConfigRequest): Promise<AxiosResponse<void>> =>
        apiClient.post('/api/APIConfiguration/config', config),

    // Upload Processor endpoints
    getQueueItems: (): Promise<AxiosResponse<QueueItem[]>> =>
        apiClient.get('/api/UploadProcessor/all'),
    getPendingQueueItems: (): Promise<AxiosResponse<QueueItem[]>> =>
        apiClient.get('/api/UploadProcessor/pending'),
    getFailedQueueItems: (): Promise<AxiosResponse<QueueItem[]>> =>
        apiClient.get('/api/UploadProcessor/failed'),
    getQueueSummary: (): Promise<AxiosResponse<QueueSummary>> =>
        apiClient.get('/api/UploadProcessor/summary'),
    reprocessQueueItem: (id: number): Promise<AxiosResponse<void>> =>
        apiClient.put(`/api/UploadProcessor/reprocess/${id}`),

    // Heartbeat endpoints
    getApiServiceHeartbeat: (): Promise<AxiosResponse<Heartbeat>> =>
        apiClient.get('/api/Heartbeats/apiservice'),
    getFileServiceHeartbeat: (): Promise<AxiosResponse<Heartbeat>> =>
        apiClient.get('/api/Heartbeats/fileservice'),

    // Push Server Settings endpoints
    getPushServerSetting: (): Promise<AxiosResponse<PushServerSetting>> =>
        apiClient.get('/api/PushServerSetting'),
    updatePushServerSetting: (data: UpdatePushServerSettingRequest): Promise<AxiosResponse<PushServerSetting>> =>
        apiClient.put('/api/PushServerSetting', data),
    enablePushServer: (data?: EnableServiceRequest): Promise<AxiosResponse<PushServerSetting>> =>
        apiClient.patch('/api/PushServerSetting/enable', data || {}),
    disablePushServer: (data?: DisableServiceRequest): Promise<AxiosResponse<PushServerSetting>> =>
        apiClient.patch('/api/PushServerSetting/disable', data || {}),
};

// Utility functions for API responses
export const handleApiError = (error: any, defaultMessage: string = 'An error occurred'): ApiError => {
    const message = error.response?.data?.message ||
        error.response?.data?.Error ||
        error.message ||
        defaultMessage;

    const details = error.response?.data?.Details ||
        error.response?.data?.details ||
        '';

    return {
        message,
        details,
        status: error.response?.status,
        data: error.response?.data,
    };
};

export const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

export const formatDuration = (milliseconds: number): string => {
    const seconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);

    if (hours > 0) {
        return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
    } else if (minutes > 0) {
        return `${minutes}m ${seconds % 60}s`;
    } else {
        return `${seconds}s`;
    }
};

export const getStatusColor = (status?: string | any): string => {
    const statusStr = typeof status === 'string' ? status : String(status || '');
    switch (statusStr.toLowerCase()) {
        case 'completed':
        case 'success':
        case 'active':
        case 'connected':
            return '#52c41a';
        case 'failed':
        case 'error':
        case 'disconnected':
            return '#ff4d4f';
        case 'pending':
        case 'processing':
        case 'uploading':
        case 'warning':
            return '#faad14';
        case 'paused':
        case 'inactive':
        case 'disabled':
            return '#d9d9d9';
        default:
            return '#1890ff';
    }
};

export const formatDateTime = (dateTime: string | Date | null): string => {
    if (!dateTime) return 'N/A';
    try {
        const date = new Date(dateTime);
        if (isNaN(date.getTime())) return 'Invalid Date';
        return date.toLocaleString();
    } catch (error) {
        return 'Invalid Date';
    }
};

export default apiService;
