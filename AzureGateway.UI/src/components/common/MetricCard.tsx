import React from 'react';
import { Card, Statistic } from 'antd';

interface MetricCardProps {
    title: string;
    value: string | number;
    suffix?: string;
    prefix?: React.ReactNode;
    loading?: boolean;
    color?: string;
    trend?: React.ReactNode;
    size?: 'small' | 'default';
}

const MetricCard: React.FC<MetricCardProps> = ({
    title,
    value,
    suffix,
    prefix,
    loading = false,
    color = '#1890ff',
    trend = null,
    size = 'default'
}) => {
    return (
        <Card
            size={size === 'small' ? 'small' : 'default'}
            loading={loading}
            style={{
                textAlign: 'center',
                background: `linear-gradient(135deg, ${color}20 0%, ${color}10 100%)`,
                border: `1px solid ${color}30`
            }}
        >
            <Statistic
                title={title}
                value={value}
                suffix={suffix}
                prefix={prefix}
                valueStyle={{
                    color: color,
                    fontSize: size === 'small' ? '20px' : '24px'
                }}
            />
            {trend && (
                <div style={{ marginTop: 8, fontSize: '12px', color: '#666' }}>
                    {trend}
                </div>
            )}
        </Card>
    );
};

export default MetricCard;
