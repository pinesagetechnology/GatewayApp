import React, { useState, useEffect } from 'react';
import {
    Row, Col, Card, Statistic, Typography,
    Button, Space, Alert, Spin, Empty
} from 'antd';
import {
    DatabaseOutlined, SyncOutlined, CloudOutlined
} from '@ant-design/icons';
import { useNotification } from '../contexts/NotificationContext';
import { apiService, formatFileSize, getStatusColor, handleApiError } from '../services/apiService';
import { AzureStorageInfo } from '../models/AzureStorageInfo';
import { Heartbeat } from '../models/Heartbeat';
import HeartbeatCard from '../components/common/HeartbeatCard';

const { Title, Text } = Typography;

interface DashboardData {
    systemHealth: any | null;
    azureInfo: AzureStorageInfo | null;
    dataSources: any[];
    apiDataSources: any[];
    apiServiceHeartbeat: Heartbeat | null;
    fileServiceHeartbeat: Heartbeat | null;
}

const Dashboard: React.FC = () => {
    const [loading, setLoading] = useState<boolean>(true);
    const [dashboardData, setDashboardData] = useState<DashboardData>({
        systemHealth: null,
        azureInfo: null,
        dataSources: [],
        apiDataSources: [],
        apiServiceHeartbeat: null,
        fileServiceHeartbeat: null,
    });
    const [refreshing, setRefreshing] = useState<boolean>(false);

    const { showNotification } = useNotification();

    const loadDashboardData = async (): Promise<void> => {
        try {
            setLoading(true);

            const [
                healthResponse,
                azureResponse,
                dataSourcesResponse,
                apiDataSourcesResponse,
                apiHeartbeatResponse,
                fileHeartbeatResponse,
            ] = await Promise.allSettled([
                apiService.getHealth(),
                apiService.getAzureStorageInfo(),
                apiService.getDataSources(),
                apiService.getAPIDataSources(),
                apiService.getApiServiceHeartbeat(),
                apiService.getFileServiceHeartbeat(),
            ]);

            const newData = { ...dashboardData };

            // Process responses
            if (healthResponse.status === 'fulfilled') {
                newData.systemHealth = healthResponse.value.data;
            }

            if (azureResponse.status === 'fulfilled') {
                newData.azureInfo = azureResponse.value.data as AzureStorageInfo;
            }

            if (dataSourcesResponse.status === 'fulfilled') {
                newData.dataSources = dataSourcesResponse.value.data || [];
            }

            if (apiDataSourcesResponse.status === 'fulfilled') {
                newData.apiDataSources = apiDataSourcesResponse.value.data || [];
            }

            if (apiHeartbeatResponse.status === 'fulfilled') {
                newData.apiServiceHeartbeat = apiHeartbeatResponse.value.data;
            }

            if (fileHeartbeatResponse.status === 'fulfilled') {
                newData.fileServiceHeartbeat = fileHeartbeatResponse.value.data;
            }

            setDashboardData(newData);
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Dashboard Error', apiError.message);
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    };

    const handleRefresh = async (): Promise<void> => {
        setRefreshing(true);
        await loadDashboardData();
    };

    useEffect(() => {
        loadDashboardData();
    }, []);

    if (loading) {
        return (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '400px' }}>
                <Spin size="large" />
            </div>
        );
    }

    const { systemHealth, azureInfo, dataSources, apiDataSources, apiServiceHeartbeat, fileServiceHeartbeat } = dashboardData;
    
    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                <Title level={2} style={{ margin: 0 }}>Dashboard</Title>
                <Space>
                    <Button
                        icon={<SyncOutlined spin={refreshing} />}
                        onClick={handleRefresh}
                        loading={refreshing}
                    >
                        Refresh
                    </Button>
                </Space>
            </div>

            {/* System Status Alert */}
            {systemHealth && 
             systemHealth !== 'Healthy' && 
             systemHealth !== 'healthy' && 
             systemHealth?.status !== 'healthy' && 
             systemHealth?.status !== 'Healthy' && (
                <Alert
                    message="System Issues Detected"
                    description="Please check the system configuration and status."
                    type="warning"
                    showIcon
                    closable
                    style={{ marginBottom: 24 }}
                />
            )}

            {/* Key Metrics */}
            <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
                <Col xs={24} sm={8}>
                    <Card>
                        <Statistic
                            title="Data Sources"
                            value={dataSources.length + apiDataSources.length}
                            prefix={<DatabaseOutlined />}
                        />
                    </Card>
                </Col>
                <Col xs={24} sm={8}>
                    <Card>
                        <Statistic
                            title="API Health"
                            value={systemHealth ? 'Online' : 'Offline'}
                            valueStyle={{ color: systemHealth ? '#52c41a' : '#ff4d4f' }}
                            suffix={
                                systemHealth ? (
                                    <span style={{ fontSize: '12px', color: '#52c41a' }}>
                                        ✓ Healthy
                                    </span>
                                ) : (
                                    <span style={{ fontSize: '12px', color: '#ff4d4f' }}>
                                        ✗ Unhealthy
                                    </span>
                                )
                            }
                        />
                    </Card>
                </Col>
                <Col xs={24} sm={8}>
                    <Card>
                        <Statistic
                            title="Azure Storage"
                            value={azureInfo?.isConnected ? 'Connected' : 'Disconnected'}
                            valueStyle={{ color: azureInfo?.isConnected ? '#52c41a' : '#ff4d4f' }}
                            prefix={<CloudOutlined />}
                        />
                    </Card>
                </Col>
            </Row>

            {/* Health Status Details */}
            {systemHealth && (
                <Card title="API Health Details" style={{ marginBottom: 24 }}>
                    <Row gutter={[16, 16]}>
                        <Col xs={24} sm={12}>
                            <Space direction="vertical" size="small" style={{ width: '100%' }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                    <Text strong>API Status:</Text>
                                    <span style={{ 
                                        color: systemHealth ? '#52c41a' : '#ff4d4f',
                                        fontWeight: 'bold'
                                    }}>
                                        {systemHealth ? '✓ Online' : '✗ Offline'}
                                    </span>
                                </div>
                                {typeof systemHealth === 'string' && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Response:</Text>
                                        <Text>{systemHealth}</Text>
                                    </div>
                                )}
                                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                    <Text type="secondary">Endpoint:</Text>
                                    <Text code>/health</Text>
                                </div>
                                {systemHealth.timestamp && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Last Check:</Text>
                                        <Text>{new Date(systemHealth.timestamp).toLocaleString()}</Text>
                                    </div>
                                )}
                                {systemHealth.version && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Version:</Text>
                                        <Text>{systemHealth.version}</Text>
                                    </div>
                                )}
                            </Space>
                        </Col>
                        <Col xs={24} sm={12}>
                            <Space direction="vertical" size="small" style={{ width: '100%' }}>
                                {systemHealth.uptime && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Uptime:</Text>
                                        <Text>{systemHealth.uptime}</Text>
                                    </div>
                                )}
                                {systemHealth.environment && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Environment:</Text>
                                        <Text>{systemHealth.environment}</Text>
                                    </div>
                                )}
                                {systemHealth.dependencies && (
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Dependencies:</Text>
                                        <Text style={{ color: systemHealth.dependencies.allHealthy ? '#52c41a' : '#ff4d4f' }}>
                                            {systemHealth.dependencies.allHealthy ? 'All Healthy' : 'Issues Detected'}
                                        </Text>
                                    </div>
                                )}
                            </Space>
                        </Col>
                    </Row>
                </Card>
            )}

            {/* Azure Storage Status */}
            <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
                <Col xs={24} lg={12}>
                    <Card title="Azure Storage Status" size="small">
                        <Space direction="vertical" size="small" style={{ width: '100%' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                <Text strong>Connection Status</Text>
                                <Text style={{ color: azureInfo?.isConnected ? '#52c41a' : '#ff4d4f' }}>
                                    {azureInfo?.isConnected ? 'Connected' : 'Disconnected'}
                                </Text>
                            </div>

                            {azureInfo?.isConnected ? (
                                <>
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Account:</Text>
                                        <Text>{azureInfo.accountName}</Text>
                                    </div>
                                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                        <Text type="secondary">Containers:</Text>
                                        <Text>{azureInfo.containers?.length || 0}</Text>
                                    </div>
                                </>
                            ) : (
                                <Text type="danger">
                                    {azureInfo?.errorMessage || 'Azure Storage not configured'}
                                </Text>
                            )}
                        </Space>
                    </Card>
                </Col>
                <Col xs={24} lg={12}>
                    <Card title="Data Sources Summary" size="small">
                        <Space direction="vertical" size="small" style={{ width: '100%' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                <Text strong>Total Sources:</Text>
                                <Text>{dataSources.length + apiDataSources.length}</Text>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                <Text strong>File Sources:</Text>
                                <Text>{dataSources.length}</Text>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                <Text strong>API Sources:</Text>
                                <Text>{apiDataSources.length}</Text>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                <Text strong>Enabled:</Text>
                                <Text>{dataSources.filter(s => s.isEnabled).length + apiDataSources.filter(s => s.isEnabled).length}</Text>
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                                <Text strong>Refreshing:</Text>
                                <Text>{dataSources.filter(s => s.isRefreshing).length + apiDataSources.filter(s => s.isRefreshing).length}</Text>
                            </div>
                        </Space>
                    </Card>
                </Col>
            </Row>

            {/* Service Heartbeats */}
            <Row gutter={[16, 16]}>
                <Col xs={24} sm={12}>
                    <HeartbeatCard 
                        title="API Service Heartbeat"
                        heartbeat={apiServiceHeartbeat}
                        loading={refreshing}
                    />
                </Col>
                <Col xs={24} sm={12}>
                    <HeartbeatCard 
                        title="File Service Heartbeat"
                        heartbeat={fileServiceHeartbeat}
                        loading={refreshing}
                    />
                </Col>
            </Row>
        </div>
    );
};

export default Dashboard;
