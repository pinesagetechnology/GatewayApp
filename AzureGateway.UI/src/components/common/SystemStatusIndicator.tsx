import React, { useState, useEffect } from 'react';
import { Space, Badge, Tooltip, Typography } from 'antd';
import { apiService } from '../../services/apiService';

const { Text } = Typography;

interface SystemStatus {
    azure: {
        isConnected: boolean;
    };
    api: {
        isHealthy: boolean;
    };
}

interface OverallStatus {
    status: 'success' | 'error' | 'warning' | 'processing' | 'default';
    text: string;
}

const SystemStatusIndicator: React.FC = () => {
    const [systemStatus, setSystemStatus] = useState<SystemStatus>({
        azure: { isConnected: false },
        api: { isHealthy: true },
    });

    const loadSystemStatus = async (): Promise<void> => {
        try {
            const [azureRes, healthRes] = await Promise.allSettled([
                apiService.getAzureStorageInfo(),
                apiService.getHealth(),
            ]);

            // Determine if health is healthy based on successful response
            const isHealthy = healthRes.status === 'fulfilled' && healthRes.value.status === 200;

            setSystemStatus({
                azure: {
                    isConnected: azureRes.status === 'fulfilled' ? azureRes.value.data.isConnected : false,
                },
                api: {
                    isHealthy: isHealthy,
                },
            });
        } catch (error) {
            console.error('Error loading system status:', error);
        }
    };

    useEffect(() => {
        loadSystemStatus();
    }, []);

    const getOverallStatus = (): OverallStatus => {
        const { azure, api } = systemStatus;

        if (!api.isHealthy) return { status: 'error', text: 'System Error' };
        if (!azure.isConnected) return { status: 'warning', text: 'Azure Disconnected' };
        return { status: 'success', text: 'System Running' };
    };

    const { status, text } = getOverallStatus();

    const tooltipContent = (
        <div>
            <div><strong>System Status</strong></div>
            <div>Azure: {systemStatus.azure.isConnected ? 'Connected' : 'Disconnected'}</div>
            <div>API: {systemStatus.api.isHealthy ? 'Healthy' : 'Error'}</div>
        </div>
    );

    return (
        <Tooltip title={tooltipContent}>
            <Space>
                <Badge status={status} />
                <Text style={{ fontSize: '14px' }}>{text}</Text>
            </Space>
        </Tooltip>
    );
};

export default SystemStatusIndicator;
