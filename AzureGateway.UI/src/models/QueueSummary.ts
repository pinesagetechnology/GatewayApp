export enum FileStatus {
  Pending = 0,
  Processing = 1,
  Uploading = 2,      // Add this
  Completed = 3,      // Change from 2 to 3
  Failed = 4,         // Change from 3 to 4
  Archived = 5        // Add this (or map Canceled to Archived)
}

export interface RecentUpload {
  id: number;
  fileName: string;
  status: FileStatus;
  createdAt: string;             // ISO datetime string
  completedAt: string | null;    // ISO datetime string
  fileSizeBytes: number;
  attemptCount: number;
  errorMessage: string | null;
  progressPercent: number;
}

export interface UploadQueueSummary {
  pendingCount: number;
  failedCount: number;
  recentUploads: RecentUpload[];
  totalSizeBytes: number;
  oldestPending: string | null;  // ISO datetime string
  newestPending: string | null;  // ISO datetime string
}
