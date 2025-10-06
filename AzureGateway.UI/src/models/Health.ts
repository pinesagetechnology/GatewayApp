export interface DatabaseHealth {
    status: string;
    canConnect: boolean;
    provider: string;
}

export interface AzureStorageHealth {
    status: string;
    isConnected: boolean;
}

export interface FileMonitoringHealth {
    status: string;
    isRunning: boolean;
    startedAt: string; // ISO datetime string
    totalFilesProcessed: number;
}

export interface HealthStatus {
    status: string;
    timestamp: string; // ISO datetime string
    database: DatabaseHealth;
    azureStorage: AzureStorageHealth;
    fileMonitoring: FileMonitoringHealth;
    isHealthy: boolean;
    issues: string[];
    checkedAt: string; // ISO datetime string
}

export interface HealthStat {
    pendingUploads: number;
    processingUploads: number;
    completedUploads: number;
    failedUploads: number;
    totalUploads: number;
    historyRecords: number;
    configurationEntries: number;
    dataSources: number;
    enabledDataSources: number;
    uploadsLast24Hours: number;
    failuresLast24Hours: number;
    error: string | null;
    lastCalculated: string; // ISO datetime string
}
