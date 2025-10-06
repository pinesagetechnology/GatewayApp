export interface Heartbeat {
    id: number;
    lastRun: string; // ISO datetime string
}

export interface HeartbeatStatus {
    apiservice: Heartbeat | null;
    fileservice: Heartbeat | null;
    lastChecked: string; // ISO datetime string
}
