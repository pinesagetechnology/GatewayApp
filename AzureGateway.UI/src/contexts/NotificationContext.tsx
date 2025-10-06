import React, { createContext, useContext, ReactNode } from 'react';
import { notification } from 'antd';

type NotificationType = 'success' | 'error' | 'info' | 'warning';

interface NotificationOptions {
    message: string;
    description?: string;
    placement?: 'topLeft' | 'topRight' | 'bottomLeft' | 'bottomRight';
    duration?: number;
    [key: string]: any;
}

interface NotificationContextType {
    showNotification: (type: NotificationType, message: string, description?: string, options?: Partial<NotificationOptions>) => void;
    api: ReturnType<typeof notification.useNotification>[0];
}

const NotificationContext = createContext<NotificationContextType | undefined>(undefined);

export const useNotification = (): NotificationContextType => {
    const context = useContext(NotificationContext);
    if (!context) {
        throw new Error('useNotification must be used within a NotificationProvider');
    }
    return context;
};

interface NotificationProviderProps {
    children: ReactNode;
}

export const NotificationProvider: React.FC<NotificationProviderProps> = ({ children }) => {
    const [api, contextHolder] = notification.useNotification();

    const showNotification = (
        type: NotificationType, 
        message: string, 
        description?: string, 
        options: Partial<NotificationOptions> = {}
    ): void => {
        api[type]({
            message,
            description,
            placement: 'topRight',
            duration: type === 'error' ? 6 : 4,
            ...options,
        });
    };

    const value: NotificationContextType = {
        showNotification,
        api,
    };

    return (
        <NotificationContext.Provider value={value}>
            {contextHolder}
            {children}
        </NotificationContext.Provider>
    );
};
