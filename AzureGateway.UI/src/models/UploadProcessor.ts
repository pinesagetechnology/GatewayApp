export interface QueueItem {
    id: number;
    filePath: string;
    fileName: string;
    fileType: number;
    status: number;
    fileSizeBytes: number;
    createdAt: string;
    lastAttemptAt: string | null;
    attemptCount: number;
    maxRetries: number;
    errorMessage: string | null;
    azureBlobUrl: string | null;
    azureContainer: string | null;
    azureBlobName: string | null;
    completedAt: string | null;
    uploadDurationMs: number | null;
    hash: string;
}

export interface StatusBreakdown {
    status: number;
    count: number;
}

export interface QueueSummary {
    totalFiles: number;
    statusBreakdown: StatusBreakdown[];
    lastUpdated: string;
}

export enum QueueItemStatus {
    Pending = 0,
    Processing = 1,
    Uploading = 2,
    Completed = 3,
    Failed = 4,
    Archived = 5
}

export enum FileType {
    Json = 0,
    Image = 1,
    Other = 2
}
