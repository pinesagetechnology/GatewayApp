import React, { useState, useEffect } from 'react';
import {
    Card, Button, Space, Typography, Row, Col, Alert, List,
    Input, Form, Modal, Table, Popconfirm,
    InputNumber
} from 'antd';
import {
    CloudOutlined, ReloadOutlined, SettingOutlined,
    InboxOutlined, DeleteOutlined, EyeOutlined,
    CheckCircleOutlined
} from '@ant-design/icons';
import { useNotification } from '../contexts/NotificationContext';
import { apiService, handleApiError } from '../services/apiService';
import { AzureStorageInfo, BlobItem } from '../models/AzureStorageInfo';
import { AzureStorageConfigRequest } from '../models/Requests';
import MetricCard from '../components/common/MetricCard';
import LoadingSpinner from '../components/common/LoadingSpinner';
import { DatabaseConfig } from '../models/DatabaseConfig';

const { Title } = Typography;

const AzureStorage: React.FC = () => {
    const [loading, setLoading] = useState<boolean>(true);
    const [azureInfo, setAzureInfo] = useState<AzureStorageInfo | null>(null);
    const [containers, setContainers] = useState<string[]>([]);
    const [selectedContainer, setSelectedContainer] = useState<string | null>(null);
    const [blobs, setBlobs] = useState<BlobItem[]>([]);
    const [configModalVisible, setConfigModalVisible] = useState<boolean>(false);

    const [form] = Form.useForm();
    const { showNotification } = useNotification();

    const loadAzureInfo = async (): Promise<void> => {
        try {
            const response = await apiService.getAzureStorageInfo();

            setAzureInfo(response.data);

            if (response.data.isConnected) {
                setContainers(response.data.containers || []);
            } else {
                console.log('Azure is not connected');
            }
        } catch (error) {
            console.error('Azure Storage load error:', error);
            const apiError = handleApiError(error);
            showNotification('error', 'Load Error', apiError.message);
        } finally {
            setLoading(false);
        }
    };

    const loadBlobs = async (containerName: string): Promise<void> => {
        try {
            const response = await apiService.listBlobs(containerName);
            // Convert string array to BlobItem objects for the table
            const blobItems: BlobItem[] = response.data.blobs.map((name: string, index: number) => ({
                name,
                url: azureInfo?.accountName ?
                    `https://${azureInfo.accountName}.blob.core.windows.net/${containerName}/${name}` :
                    undefined
            }));
            setBlobs(blobItems);
            setSelectedContainer(containerName);
        } catch (error) {
            console.error('Blobs load error:', error);
            const apiError = handleApiError(error);
            showNotification('error', 'Load Error', apiError.message);
        }
    };

    const handleConfigureAzure = async (values: AzureStorageConfigRequest): Promise<void> => {
        try {
            await apiService.configureAzureStorage(values);
            showNotification('success', 'Configuration Updated', 'Azure Storage configured successfully');

            setConfigModalVisible(false);
            form.resetFields();
            await loadAzureInfo();
        } catch (error) {
            console.error('Azure Storage configuration error:', error);
            const apiError = handleApiError(error);
            showNotification('error', 'Configuration Error', apiError.message);
        }
    };

    const handleDeleteBlob = async (blobName: string): Promise<void> => {
        if (!selectedContainer) {
            showNotification('error', 'Error', 'No container selected');
            return;
        }

        try {
            await apiService.deleteBlob(selectedContainer, blobName);
            showNotification('success', 'Deleted', 'Blob deleted successfully');
            await loadBlobs(selectedContainer);
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Delete Error', apiError.message);
        }
    };

    const openConfigModal = async (): Promise<void> => {
        try {
            setConfigModalVisible(true);
            const response = await apiService.getConfigurations();
            const configs: DatabaseConfig[] = response.data || [];

            const formValues: any = {};

            // Find keys by name heuristics (case-insensitive substring match)
            configs.forEach((c) => {
                const key = c.key?.toLowerCase?.() || '';
                if (key.includes('defaultcontainer')) {
                    formValues.defaultContainer = c.value;
                }
                if (key.includes('maxconcurrentuploads')) {
                    const num = Number(c.value);
                    if (!Number.isNaN(num)) formValues.maxConcurrentUploads = num;
                }
            });

            // Do NOT prefill connection string for security
            form.setFieldsValue(formValues);
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Load Config Error', apiError.message);
        }
    };

    useEffect(() => {
        loadAzureInfo();
    }, []);

    if (loading) {
        return <LoadingSpinner tip="Loading Azure Storage info..." />;
    }

    const containerColumns = [
        {
            title: 'Container Name',
            dataIndex: 'name',
            key: 'name',
        },
        {
            title: 'Actions',
            key: 'actions',
            render: (_: unknown, record: { name: string }) => (
                <Button
                    type="link"
                    onClick={() => loadBlobs(record.name)}
                >
                    View Blobs
                </Button>
            ),
        },
    ];

    const blobColumns = [
        {
            title: 'Blob Name',
            dataIndex: 'name',
            key: 'name',
        },
        // {
        //     title: 'Size',
        //     dataIndex: 'size',
        //     key: 'size',
        //     render: (size: number | undefined) =>
        //         size ? `${(size / 1024 / 1024).toFixed(2)} MB` : 'Unknown',
        // },
        // {
        //     title: 'Last Modified',
        //     dataIndex: 'lastModified',
        //     key: 'lastModified',
        //     render: (date: string | undefined) =>
        //         date ? new Date(date).toLocaleString() : 'Unknown',
        // },
        {
            title: 'Actions',
            key: 'actions',
            render: (_: unknown, record: BlobItem) => (
                <Space>
                    <Button
                        size="small"
                        icon={<EyeOutlined />}
                        onClick={() => {
                            if (record.url) {
                                window.open(record.url, '_blank');
                            } else if (azureInfo?.accountName && selectedContainer) {
                                window.open(`https://${azureInfo.accountName}.blob.core.windows.net/${selectedContainer}/${record.name}`, '_blank');
                            }
                        }}
                    >
                        View
                    </Button>
                    {/* <Popconfirm
                        title="Are you sure you want to delete this blob?"
                        onConfirm={() => handleDeleteBlob(record.name)}
                        okText="Yes"
                        cancelText="No"
                    >
                        <Button
                            size="small"
                            danger
                            icon={<DeleteOutlined />}
                        >
                            Delete
                        </Button>
                    </Popconfirm> */}
                </Space>
            ),
        },
    ];

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                <Title level={2} style={{ margin: 0 }}>Azure Storage</Title>
                <Space>
                    <Button
                        icon={<ReloadOutlined />}
                        onClick={loadAzureInfo}
                        loading={loading}
                    >
                        Refresh
                    </Button>
                    <Button
                        type="primary"
                        icon={<SettingOutlined />}
                        onClick={openConfigModal}
                    >
                        Configure
                    </Button>
                </Space>
            </div>

            {/* Connection Status */}
            {!azureInfo?.isConnected && (
                <Alert
                    message="Azure Storage Not Connected"
                    description="Please configure Azure Storage connection to view containers and blobs."
                    type="warning"
                    showIcon
                    style={{ marginBottom: 24 }}
                />
            )}

            {/* Storage Metrics */}
            {azureInfo?.isConnected && (
                <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
                    <Col xs={24} sm={12} md={6}>
                        <MetricCard
                            title="Account Name"
                            value={azureInfo.accountName || 'N/A'}
                            color="#1890ff"
                            size="small"
                        />
                    </Col>
                    <Col xs={24} sm={12} md={6}>
                        <MetricCard
                            title="Containers"
                            value={containers.length}
                            color="#52c41a"
                            size="small"
                        />
                    </Col>
                    <Col xs={24} sm={12} md={6}>
                        <MetricCard
                            title="Total Blobs"
                            value={blobs.length || 0}
                            color="#faad14"
                            size="small"
                        />
                    </Col>
                    <Col xs={24} sm={12} md={6}>
                        <MetricCard
                            title="Connection Status"
                            value={azureInfo.isConnected ? 'Connected' : 'Disconnected'}
                            color={azureInfo.isConnected ? '#52c41a' : '#ff4d4f'}
                            size="small"
                        />
                    </Col>
                </Row>
            )}

            <Row gutter={[16, 16]}>
                {/* Containers */}
                <Col xs={24} lg={12}>
                    <Card title="Storage Containers" size="small">
                        {containers.length > 0 ? (
                            <Table
                                columns={containerColumns}
                                dataSource={containers.map((name, index) => ({ name, key: index }))}
                                rowKey="key"
                                size="small"
                                pagination={false}
                            />
                        ) : (
                            <div style={{ textAlign: 'center', padding: '20px' }}>
                                <InboxOutlined style={{ fontSize: '48px', color: '#d9d9d9' }} />
                                <p>No containers found</p>
                            </div>
                        )}
                    </Card>
                </Col>

                {/* Blobs */}
                <Col xs={24} lg={12}>
                    <Card
                        title={`Blobs in ${selectedContainer || 'Select Container'}`}
                        size="small"
                        extra={
                            selectedContainer && (
                                <Button
                                    size="small"
                                    icon={<ReloadOutlined />}
                                    onClick={() => loadBlobs(selectedContainer)}
                                >
                                    Refresh
                                </Button>
                            )
                        }
                    >
                        {selectedContainer ? (
                            blobs.length > 0 ? (
                                <Table
                                    columns={blobColumns}
                                    dataSource={blobs}
                                    rowKey={(record) => record.name}
                                    size="small"
                                    pagination={{ pageSize: 10 }}
                                />
                            ) : (
                                <div style={{ textAlign: 'center', padding: '20px' }}>
                                    <InboxOutlined style={{ fontSize: '48px', color: '#d9d9d9' }} />
                                    <p>No blobs found in this container</p>
                                </div>
                            )
                        ) : (
                            <div style={{ textAlign: 'center', padding: '20px' }}>
                                <CloudOutlined style={{ fontSize: '48px', color: '#d9d9d9' }} />
                                <p>Select a container to view blobs</p>
                            </div>
                        )}
                    </Card>
                </Col>
            </Row>

            {/* Configuration Modal */}
            <Modal
                title="Configure Azure Storage"
                open={configModalVisible}
                onCancel={() => setConfigModalVisible(false)}
                footer={null}
                width={600}
            >
                <Form
                    form={form}
                    layout="vertical"
                    onFinish={handleConfigureAzure}
                    initialValues={{}}
                >
                    <Form.Item
                        name="connectionString"
                        label="Connection String"
                        rules={[{ required: true, message: 'Please enter the connection string' }]}
                    >
                        <Input.Password placeholder="DefaultEndpointsProtocol=https;AccountName=...;" />
                    </Form.Item>

                    <Form.Item
                        name="defaultContainer"
                        label="Default Container"
                    >
                        <Input placeholder="uploads" />
                    </Form.Item>

                    <Form.Item
                        name="maxConcurrentUploads"
                        label="Max Concurrent Uploads"
                    >
                        <InputNumber placeholder="5" min={1} max={20} />
                    </Form.Item>

                    <Form.Item>
                        <Space>
                            <Button type="primary" htmlType="submit">
                                Save Configuration
                            </Button>
                            <Button onClick={() => setConfigModalVisible(false)}>
                                Cancel
                            </Button>
                        </Space>
                    </Form.Item>
                </Form>
            </Modal>
        </div>
    );
};

export default AzureStorage;