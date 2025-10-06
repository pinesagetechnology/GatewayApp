export interface ActiveUploadInfo {
    id: number;
    fileName: string;
    fileSize: number;
    uploadedBytes: number;
    status: "Pending" | "Processing" | "Completed" | "Failed";
    startedAt: string;            // ISO datetime string
    lastUpdatedAt: string;        // ISO datetime string
    error: string | null;
}

export interface UploadProcessStatus {
    isRunning: boolean;
    isPaused: boolean;
    startedAt: string;            // ISO datetime string
    activeUploads: number;
    pendingCount: number;
    failedCount: number;
    completedCount: number;
    totalBytesUploaded: number;
    averageUploadSpeedMbps: number;
    lastUploadCompleted: string | null;
    activeUploadInfo: ActiveUploadInfo[];
    recentErrors: string[];
}
