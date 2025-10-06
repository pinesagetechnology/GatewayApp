// src/contexts/SignalRContext.tsx - SignalR connection context
import React, { createContext, useContext, useEffect, useState, useCallback, ReactNode } from 'react';
import * as signalR from '@microsoft/signalr';
import { useNotification } from './NotificationContext';

interface UploadUpdate {
    uploadId: string;
    fileName: string;
    percentComplete: number;
    bytesUploaded: number;
    totalBytes: number;
    timestamp: Date;
}

interface UploadProgressData {
    UploadId: string;
    FileName: string;
    PercentComplete: number;
    BytesUploaded: number;
    TotalBytes: number;
}

interface UploadCompletedData {
    UploadId: string;
    FileName: string;
    Duration: number;
}

interface UploadFailedData {
    UploadId: string;
    FileName: string;
    Error: string;
}

interface ProcessorStatusData {
    IsRunning: boolean;
}

interface SignalRContextType {
    connection: signalR.HubConnection | null;
    connectionStatus: string;
    uploadUpdates: UploadUpdate[];
    sendMessage: (methodName: string, ...args: any[]) => Promise<void>;
    reconnect: () => Promise<void>;
}

const SignalRContext = createContext<SignalRContextType | undefined>(undefined);

export const useSignalR = (): SignalRContextType => {
    const context = useContext(SignalRContext);
    if (!context) {
        throw new Error('useSignalR must be used within a SignalRProvider');
    }
    return context;
};

interface SignalRProviderProps {
    children: ReactNode;
}

export const SignalRProvider: React.FC<SignalRProviderProps> = ({ children }) => {
    const [connection, setConnection] = useState<signalR.HubConnection | null>(null);
    const [connectionStatus, setConnectionStatus] = useState<string>('Disconnected');
    const [uploadUpdates, setUploadUpdates] = useState<UploadUpdate[]>([]);
    const { showNotification } = useNotification();

    const connectToHub = useCallback(async (): Promise<void> => {
        try {
            const newConnection = new signalR.HubConnectionBuilder()
                // Use relative URL; backend maps hub at /uploadStatusHub
                .withUrl('/uploadStatusHub')
                .withAutomaticReconnect()
                .build();

            // Set up event handlers
            newConnection.on('UploadProgressUpdated', (data: UploadProgressData) => {
                setUploadUpdates(prev => {
                    const updated = prev.filter(item => item.uploadId !== data.UploadId);
                    return [...updated, {
                        uploadId: data.UploadId,
                        fileName: data.FileName,
                        percentComplete: data.PercentComplete,
                        bytesUploaded: data.BytesUploaded,
                        totalBytes: data.TotalBytes,
                        timestamp: new Date()
                    }];
                });
            });

            newConnection.on('UploadCompleted', (data: UploadCompletedData) => {
                showNotification('success', 'Upload Completed',
                    `${data.FileName} uploaded successfully in ${data.Duration.toFixed(1)}s`);

                // Remove from active uploads
                setUploadUpdates(prev => prev.filter(item => item.uploadId !== data.UploadId));
            });

            newConnection.on('UploadFailed', (data: UploadFailedData) => {
                showNotification('error', 'Upload Failed',
                    `${data.FileName} failed: ${data.Error}`);

                // Remove from active uploads
                setUploadUpdates(prev => prev.filter(item => item.uploadId !== data.UploadId));
            });

            newConnection.on('UploadProcessorStatusChanged', (data: ProcessorStatusData) => {
                const status = data.IsRunning ? 'Running' : 'Stopped';
                showNotification('info', 'Processor Status Changed', `Upload processor is now ${status}`);
            });

            // Connection state handlers
            newConnection.onclose(() => {
                setConnectionStatus('Disconnected');
                setConnection(null);
            });

            newConnection.onreconnecting(() => {
                setConnectionStatus('Reconnecting');
            });

            newConnection.onreconnected(() => {
                setConnectionStatus('Connected');
            });

            // Start connection
            await newConnection.start();
            setConnection(newConnection);
            setConnectionStatus('Connected');

            // Join groups for receiving updates
            await newConnection.invoke('JoinUploadGroup');
            await newConnection.invoke('JoinProcessorGroup');

        } catch (error) {
            console.error('SignalR connection error:', error);
            setConnectionStatus('Error');
            showNotification('error', 'Connection Error', 'Failed to connect to real-time updates');
        }
    }, [showNotification]);

    useEffect(() => {
        connectToHub();

        return () => {
            if (connection) {
                connection.stop();
            }
        };
    }, [connectToHub]);

    const sendMessage = useCallback(async (methodName: string, ...args: any[]): Promise<void> => {
        if (connection && connectionStatus === 'Connected') {
            try {
                await connection.invoke(methodName, ...args);
            } catch (error) {
                console.error('SignalR send error:', error);
            }
        }
    }, [connection, connectionStatus]);

    const value: SignalRContextType = {
        connection,
        connectionStatus,
        uploadUpdates,
        sendMessage,
        reconnect: connectToHub,
    };

    return (
        <SignalRContext.Provider value={value}>
            {children}
        </SignalRContext.Provider>
    );
};
