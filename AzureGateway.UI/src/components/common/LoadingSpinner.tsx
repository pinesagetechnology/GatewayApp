import React from 'react';
import { Spin } from 'antd';

interface LoadingSpinnerProps {
    size?: 'small' | 'default' | 'large';
    tip?: string;
}

const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({ size = 'large', tip = 'Loading...' }) => {
    return (
        <div style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            minHeight: '200px',
            flexDirection: 'column'
        }}>
            <Spin size={size} tip={tip}>
                <div style={{ padding: '50px' }} />
            </Spin>
        </div>
    );
};

export default LoadingSpinner;
