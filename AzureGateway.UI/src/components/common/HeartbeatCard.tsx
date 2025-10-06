import React from 'react';
import { Card, Space, Typography, Tag } from 'antd';
import { HeartOutlined, ClockCircleOutlined } from '@ant-design/icons';
import { Heartbeat } from '../../models/Heartbeat';
import { formatDateTime } from '../../services/apiService';

const { Text } = Typography;

interface HeartbeatCardProps {
    title: string;
    heartbeat: Heartbeat | null;
    loading?: boolean;
}

const HeartbeatCard: React.FC<HeartbeatCardProps> = ({ 
    title, 
    heartbeat, 
    loading = false 
}) => {
    const getHeartbeatStatus = (lastRun: string | null): { status: string; color: string; icon: React.ReactNode } => {
        if (!lastRun) {
            return {
                status: 'No Data',
                color: '#d9d9d9',
                icon: <ClockCircleOutlined />
            };
        }

        const now = new Date();
        const lastRunDate = new Date(lastRun);
        const timeDiff = now.getTime() - lastRunDate.getTime();
        const minutesDiff = Math.floor(timeDiff / (1000 * 60));

        if (minutesDiff <= 5) {
            return {
                status: 'Active',
                color: '#52c41a',
                icon: <HeartOutlined />
            };
        } else if (minutesDiff <= 15) {
            return {
                status: 'Warning',
                color: '#faad14',
                icon: <ClockCircleOutlined />
            };
        } else {
            return {
                status: 'Stale',
                color: '#ff4d4f',
                icon: <ClockCircleOutlined />
            };
        }
    };

    const heartbeatStatus = getHeartbeatStatus(heartbeat?.lastRun || null);

    return (
        <Card 
            title={title} 
            size="small"
            loading={loading}
            style={{ height: '100%' }}
        >
            <Space direction="vertical" size="small" style={{ width: '100%' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Text strong>Status:</Text>
                    <Tag 
                        color={heartbeatStatus.color}
                        icon={heartbeatStatus.icon}
                    >
                        {heartbeatStatus.status}
                    </Tag>
                </div>

                {heartbeat?.lastRun && (
                    <>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                            <Text type="secondary">Last Run:</Text>
                            <Text>{formatDateTime(heartbeat.lastRun)}</Text>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                            <Text type="secondary">ID:</Text>
                            <Text code>{heartbeat.id}</Text>
                        </div>
                    </>
                )}

                {!heartbeat?.lastRun && !loading && (
                    <Text type="secondary" style={{ textAlign: 'center', display: 'block' }}>
                        No heartbeat data available
                    </Text>
                )}
            </Space>
        </Card>
    );
};

export default HeartbeatCard;
