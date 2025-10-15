export interface GpsServerSetting {
    id: number;
    isEnabled: boolean;
    dataFolderPath: string;
    updatedAt?: string;
    updatedBy?: string | null;
}

export interface UpdateGpsServerSettingRequest {
    isEnabled: boolean;
    dataFolderPath: string;
}

