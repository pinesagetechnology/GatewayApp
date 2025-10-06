export interface AzureStorageInfo {
    isConnected: boolean;
    accountName: string;
    containers: string[];
    errorMessage: string | null;
}

export interface ContainerList {
    containers: string[];
}

export interface BlobInfoResponse {
    container: string;
    prefix: string | null;
    blobs: string[];
}

export interface BlobItem {
    name: string;
    size?: number;
    lastModified?: string;
    url?: string;
}