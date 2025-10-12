export interface PushServerSetting {
    id: number;
    isEnabled: boolean;
    dataFolderPath: string;
    updatedAt: string;
    updatedBy: string | null;
}

export interface UpdatePushServerSettingRequest {
    isEnabled: boolean;
    dataFolderPath: string;
    updatedBy?: string;
}

export interface EnableServiceRequest {
    updatedBy?: string;
}

export interface DisableServiceRequest {
    updatedBy?: string;
}

