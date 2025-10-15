import React, { useState } from 'react';
import { Layout, Menu, theme, Avatar, Dropdown, Space, Typography, MenuProps } from 'antd';
import { useNavigate, useLocation } from 'react-router-dom';
import {
    DashboardOutlined,
    CloudUploadOutlined,
    DatabaseOutlined,
    MonitorOutlined,
    CloudOutlined,
    SettingOutlined,
    UserOutlined,
    LogoutOutlined,
    MenuFoldOutlined,
    MenuUnfoldOutlined,
    SyncOutlined,
    ApiOutlined,
    SendOutlined,
    EnvironmentOutlined,
} from '@ant-design/icons';
import SystemStatusIndicator from '../common/SystemStatusIndicator';

const { Header, Sider, Content } = Layout;
const { Title } = Typography;

interface AppLayoutProps {
    children: React.ReactNode;
}

type MenuItem = Required<MenuProps>['items'][number];
type UserMenuItem = Required<MenuProps>['items'][number];

const AppLayout: React.FC<AppLayoutProps> = ({ children }) => {
    const [collapsed, setCollapsed] = useState<boolean>(false);
    const navigate = useNavigate();
    const location = useLocation();
    const {
        token: { colorBgContainer },
    } = theme.useToken();

    const menuItems: MenuItem[] = [
        {
            key: '/dashboard',
            icon: <DashboardOutlined />,
            label: 'Dashboard',
        },
        {
            key: '/data-sources',
            icon: <DatabaseOutlined />,
            label: 'Data Sources',
        },
        {
            key: '/api-data-sources',
            icon: <ApiOutlined />,
            label: 'API Data Sources',
        },
        {
            key: '/push-server',
            icon: <SendOutlined />,
            label: 'Push Server',
        },
        {
            key: '/gps-server',
            icon: <EnvironmentOutlined />,
            label: 'GPS Server',
        },
        {
            key: '/upload-processor',
            icon: <SyncOutlined />,
            label: 'Upload Queue',
        },
        {
            key: '/azure-storage',
            icon: <CloudOutlined />,
            label: 'Azure Storage',
        },
        {
            key: '/settings',
            icon: <SettingOutlined />,
            label: 'Settings',
        },
    ];

    const userMenuItems: UserMenuItem[] = [
        {
            key: 'profile',
            icon: <UserOutlined />,
            label: 'Profile',
        },
        {
            key: 'logout',
            icon: <LogoutOutlined />,
            label: 'Logout',
        },
    ];

    const onMenuClick = ({ key }: { key: string }) => {
        navigate(key);
    };

    const onUserMenuClick = ({ key }: { key: string }) => {
        if (key === 'logout') {
            // Handle logout logic here
            localStorage.removeItem('authToken');
            window.location.href = '/login';
        } else if (key === 'profile') {
            // Handle profile logic here
            // Could navigate to profile page or show profile modal
        }
    };

    return (
        <Layout style={{ minHeight: '100vh' }}>
            <Sider
                trigger={null}
                collapsible
                collapsed={collapsed}
                style={{
                    background: colorBgContainer,
                    boxShadow: '2px 0 8px 0 rgba(29, 35, 41, 0.05)',
                }}
            >
                <div style={{
                    height: 64,
                    padding: '16px',
                    display: 'flex',
                    alignItems: 'center',
                    borderBottom: '1px solid #f0f0f0'
                }}>
                    {!collapsed && (
                        <Title level={4} style={{ margin: 0, color: '#1890ff' }}>
                            Azure Gateway
                        </Title>
                    )}
                </div>
                <Menu
                    theme="light"
                    mode="inline"
                    selectedKeys={[location.pathname]}
                    items={menuItems}
                    onClick={onMenuClick}
                    style={{ border: 'none' }}
                />
            </Sider>
            <Layout>
                <Header
                    style={{
                        padding: '0 24px',
                        background: colorBgContainer,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        boxShadow: '0 2px 8px 0 rgba(29, 35, 41, 0.05)',
                    }}
                >
                    <div style={{ display: 'flex', alignItems: 'center' }}>
                        <button
                            type="button"
                            onClick={() => setCollapsed(!collapsed)}
                            style={{
                                fontSize: '16px',
                                width: 32,
                                height: 32,
                                background: 'none',
                                border: 'none',
                                cursor: 'pointer',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                marginRight: '16px',
                            }}
                        >
                            {collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
                        </button>
                        <SystemStatusIndicator />
                    </div>

                    <Space>
                        <Dropdown
                            menu={{ items: userMenuItems, onClick: onUserMenuClick }}
                            placement="bottomRight"
                        >
                            <Space style={{ cursor: 'pointer' }}>
                                <Avatar icon={<UserOutlined />} />
                                <span>Admin</span>
                            </Space>
                        </Dropdown>
                    </Space>
                </Header>
                <Content
                    style={{
                        margin: '24px',
                        padding: '24px',
                        minHeight: 'calc(100vh - 112px)',
                        background: colorBgContainer,
                        borderRadius: '8px',
                        boxShadow: '0 2px 8px 0 rgba(29, 35, 41, 0.05)',
                    }}
                >
                    {children}
                </Content>
            </Layout>
        </Layout>
    );
};

export default AppLayout;
