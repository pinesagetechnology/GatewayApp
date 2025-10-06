export interface FileDataSourceConfig {
    id: number;
    name: string;
    isEnabled: boolean;
    isRefreshing: boolean;
    folderPath: string | null;
    filePattern: string | null;
    createdAt: string;            // ISO datetime string
    lastProcessedAt: string | null;
}
