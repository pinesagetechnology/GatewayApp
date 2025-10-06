export interface ApiError {
    message: string;
    details: string;
    status?: number;
    data?: any;
}
