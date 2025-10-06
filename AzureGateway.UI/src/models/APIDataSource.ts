export interface APIDataSourceConfig {
    id: number;
    name: string;
    isEnabled: boolean;
    isRefreshing: boolean;
    tempFolderPath: string;
    apiEndpoint: string;
    apiKey: string;
    pollingIntervalMinutes: number;
    createdAt: string;            // ISO datetime string
    lastProcessedAt: string | null;
    additionalSettings: string;
}
