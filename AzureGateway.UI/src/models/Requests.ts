
export interface AzureStorageConfigRequest {
    connectionString?: string | null;
    defaultContainer?: string | null;
    maxConcurrentUploads?: number | null; // int32
}

// Matches: AzureTestUploadRequest
export interface AzureTestUploadRequest {
    fileName?: string | null;
    containerName?: string | null;
    content?: string | null; // e.g., base64 or plain text per your API
}

// Matches: CreateDataSourceRequest
export interface CreateDataSourceRequest {
    name?: string | null;
    isEnabled?: boolean;
    isRefreshing?: boolean;
    folderPath?: string | null;
    filePattern?: string | null;
}

// Matches: UpdateDataSourceRequest
export interface UpdateDataSourceRequest {
    name?: string | null;
    isEnabled?: boolean;
    isRefreshing?: boolean;
    folderPath?: string | null;
    filePattern?: string | null;
}

// Matches: SetConfigRequest
export interface SetConfigRequest {
    key?: string | null;
    value?: string | null;
    description?: string | null;
    category?: string | null;
}