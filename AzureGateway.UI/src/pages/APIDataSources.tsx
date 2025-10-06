import React, { useState, useEffect } from 'react';
import {
    Card, Button, Table, Space, Typography, Row, Col, Modal, Form,
    Input, Switch, Tooltip, Badge, InputNumber,
    Popconfirm, Statistic
} from 'antd';
import {
    PlusOutlined, EditOutlined, DeleteOutlined, PlayCircleOutlined,
    PauseCircleOutlined, ApiOutlined, ReloadOutlined
} from '@ant-design/icons';
import { useNotification } from '../contexts/NotificationContext';
import { apiService, handleApiError } from '../services/apiService';
import { APIDataSourceConfig } from '../models/APIDataSource';

const { Title, Text } = Typography;

const APIDataSources: React.FC = () => {
    const [loading, setLoading] = useState<boolean>(true);
    const [dataSources, setDataSources] = useState<APIDataSourceConfig[]>([]);
    const [modalVisible, setModalVisible] = useState<boolean>(false);
    const [editingSource, setEditingSource] = useState<APIDataSourceConfig | null>(null);

    const [form] = Form.useForm();
    const { showNotification } = useNotification();

    const loadDataSources = async (): Promise<void> => {
        try {
            setLoading(true);
            const response = await apiService.getAPIDataSources();
            setDataSources(response.data || []);
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Load Error', apiError.message);
        } finally {
            setLoading(false);
        }
    };

    const handleCreateNew = () => {
        setEditingSource(null);
        form.resetFields();
        form.setFieldsValue({
            isEnabled: true,
            isRefreshing: true,
            pollingIntervalMinutes: 5
        });
        setModalVisible(true);
    };

    const handleEdit = (source: APIDataSourceConfig) => {
        setEditingSource(source);
        form.setFieldsValue({
            name: source.name,
            isEnabled: source.isEnabled,
            isRefreshing: source.isRefreshing,
            tempFolderPath: source.tempFolderPath,
            apiEndpoint: source.apiEndpoint,
            apiKey: source.apiKey,
            pollingIntervalMinutes: source.pollingIntervalMinutes,
            additionalSettings: source.additionalSettings
        });
        setModalVisible(true);
    };

    const handleDelete = async (id: number) => {
        try {
            await apiService.deleteAPIDataSource(id);
            showNotification('success', 'API Data Source Deleted', 'API data source has been deleted successfully');
            loadDataSources();
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Delete Error', apiError.message);
        }
    };

    // Function to enable/disable data sources
    const handleToggleStatus = async (source: APIDataSourceConfig) => {
        try {
            const updatedSource = { ...source, isEnabled: !source.isEnabled };
            await apiService.updateAPIDataSource(source.id, updatedSource);
            
            showNotification(
                'success',
                'API Data Source Status Updated',
                `API data source "${source.name}" has been ${updatedSource.isEnabled ? 'enabled' : 'disabled'}`
            );
            
            loadDataSources();
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'API Data Source Update Error', apiError.message);
        }
    };

    // Bulk function to enable/disable all data sources
    const handleToggleAllDataSources = async (enable: boolean) => {
        try {
            if (dataSources.length === 0) {
                showNotification('info', 'No API Data Sources', 'No API data sources found');
                return;
            }

            const updatePromises = dataSources.map(source => 
                apiService.updateAPIDataSource(source.id, { ...source, isEnabled: enable })
            );

            await Promise.all(updatePromises);
            
            showNotification(
                'success',
                'Bulk API Data Source Update',
                `All API data sources have been ${enable ? 'enabled' : 'disabled'}`
            );
            
            loadDataSources();
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Bulk API Data Source Update Error', apiError.message);
        }
    };

    const handleSubmit = async (values: any) => {
        try {
            const payload = {
                name: values.name,
                isEnabled: values.isEnabled,
                isRefreshing: values.isRefreshing,
                tempFolderPath: values.tempFolderPath,
                apiEndpoint: values.apiEndpoint,
                apiKey: values.apiKey,
                pollingIntervalMinutes: values.pollingIntervalMinutes,
                additionalSettings: values.additionalSettings,
            };

            if (editingSource) {
                await apiService.updateAPIDataSource(editingSource.id, payload);
                showNotification('success', 'API Data Source Updated', 'API data source has been updated successfully');
            } else {
                await apiService.createAPIDataSource(payload);
                showNotification('success', 'API Data Source Created', 'API data source has been created successfully');
            }
            setModalVisible(false);
            loadDataSources();
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Save Error', apiError.message);
        }
    };

    useEffect(() => {
        loadDataSources();
    }, []);

    const columns = [
        {
            title: 'Name',
            dataIndex: 'name',
            key: 'name',
            render: (text: string, record: APIDataSourceConfig) => (
                <Space>
                    <ApiOutlined />
                    <Text strong>{text}</Text>
                </Space>
            ),
        },
        {
            title: 'Status',
            dataIndex: 'isEnabled',
            key: 'isEnabled',
            render: (isEnabled: boolean, record: APIDataSourceConfig) => (
                <Switch
                    checked={isEnabled}
                    onChange={() => handleToggleStatus(record)}
                    checkedChildren="Enabled"
                    unCheckedChildren="Disabled"
                />
            ),
        },
        {
            title: 'Refreshing',
            dataIndex: 'isRefreshing',
            key: 'isRefreshing',
            render: (isRefreshing: boolean) => (
                <Badge
                    status={isRefreshing ? 'processing' : 'default'}
                    text={isRefreshing ? 'Yes' : 'No'}
                />
            ),
        },
        {
            title: 'API Endpoint',
            dataIndex: 'apiEndpoint',
            key: 'apiEndpoint',
            ellipsis: true,
        },
        {
            title: 'Polling Interval',
            dataIndex: 'pollingIntervalMinutes',
            key: 'pollingIntervalMinutes',
            render: (minutes: number) => `${minutes} min`,
        },
        {
            title: 'Last Processed',
            dataIndex: 'lastProcessedAt',
            key: 'lastProcessedAt',
            render: (date: string | null) => date ? new Date(date).toLocaleString() : 'Never',
        },
        {
            title: 'Actions',
            key: 'actions',
            render: (text: any, record: APIDataSourceConfig) => (
                <Space>
                    <Tooltip 
                        title={record.isEnabled ? "Disable the data source before editing configuration" : "Edit data source configuration"}
                        placement="top"
                    >
                        <Button
                            type="link"
                            icon={<EditOutlined />}
                            onClick={() => handleEdit(record)}
                            disabled={record.isEnabled}
                            style={{ 
                                color: record.isEnabled ? '#d9d9d9' : undefined,
                                cursor: record.isEnabled ? 'not-allowed' : 'pointer'
                            }}
                        >
                            Edit
                        </Button>
                    </Tooltip>
                    
                    <Button
                        type="link"
                        icon={record.isEnabled ? <PauseCircleOutlined /> : <PlayCircleOutlined />}
                        onClick={() => handleToggleStatus(record)}
                        style={{ color: record.isEnabled ? '#ff4d4f' : '#52c41a' }}
                    >
                        {record.isEnabled ? 'Disable' : 'Enable'}
                    </Button>
                </Space>
            ),
        },
    ];

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                <Title level={2} style={{ margin: 0 }}>API Data Sources</Title>
                <Space>
                    <Button icon={<ReloadOutlined />} onClick={loadDataSources}>
                        Refresh
                    </Button>
                    <Button type="primary" icon={<PlusOutlined />} onClick={handleCreateNew}>
                        Add API Data Source
                    </Button>
                </Space>
            </div>

            {/* Bulk Actions */}
            <Card style={{ marginBottom: 24 }}>
                <Title level={4} style={{ marginBottom: 16 }}>Bulk Actions</Title>
                <Row gutter={[16, 16]}>
                    <Col xs={24} sm={12} md={6}>
                        <Space direction="vertical" style={{ width: '100%' }}>
                            <Text strong>All API Data Sources</Text>
                            <Space>
                                <Button 
                                    type="primary" 
                                    size="small"
                                    icon={<PlayCircleOutlined />}
                                    onClick={() => handleToggleAllDataSources(true)}
                                    disabled={dataSources.length === 0}
                                >
                                    Enable All
                                </Button>
                                <Button 
                                    size="small"
                                    icon={<PauseCircleOutlined />}
                                    onClick={() => handleToggleAllDataSources(false)}
                                    disabled={dataSources.length === 0}
                                >
                                    Disable All
                                </Button>
                            </Space>
                        </Space>
                    </Col>
                </Row>
            </Card>

            {/* Summary Cards */}
            <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
                <Col xs={24} sm={8}>
                    <Card>
                        <Statistic
                            title="Total API Data Sources"
                            value={dataSources.length}
                        />
                    </Card>
                </Col>
                <Col xs={24} sm={8}>
                    <Card>
                        <Statistic
                            title="Enabled Sources"
                            value={dataSources.filter(s => s.isEnabled).length}
                        />
                    </Card>
                </Col>
                <Col xs={24} sm={8}>
                    <Card>
                        <Statistic
                            title="Refreshing Sources"
                            value={dataSources.filter(s => s.isRefreshing).length}
                        />
                    </Card>
                </Col>
            </Row>

            {/* Data Sources Table */}
            <Card>
                <Table
                    columns={columns}
                    dataSource={dataSources}
                    rowKey="id"
                    loading={loading}
                    pagination={{
                        pageSize: 10,
                        showSizeChanger: true,
                        showQuickJumper: true,
                        showTotal: (total, range) => `${range[0]}-${range[1]} of ${total} items`,
                    }}
                />
            </Card>

            {/* Add/Edit Modal */}
            <Modal
                title={editingSource ? 'Edit API Data Source' : 'Add API Data Source'}
                open={modalVisible}
                onCancel={() => setModalVisible(false)}
                footer={null}
                width={600}
            >
                <Form
                    form={form}
                    layout="vertical"
                    onFinish={handleSubmit}
                >
                    <Form.Item
                        name="name"
                        label="Name"
                        rules={[{ required: true, message: 'Please enter a name' }]}
                    >
                        <Input placeholder="Enter API data source name" />
                    </Form.Item>

                    <Form.Item
                        name="isEnabled"
                        label="Enabled"
                        valuePropName="checked"
                    >
                        <Switch />
                    </Form.Item>

                    <Form.Item
                        name="isRefreshing"
                        label="Refreshing"
                        valuePropName="checked"
                    >
                        <Switch />
                    </Form.Item>

                    <Form.Item
                        name="tempFolderPath"
                        label="Temp Folder Path"
                        rules={[{ required: true, message: 'Please enter temp folder path' }]}
                    >
                        <Input placeholder="C:\\temp\\api-data" />
                    </Form.Item>

                    <Form.Item
                        name="apiEndpoint"
                        label="API Endpoint"
                        rules={[{ required: true, message: 'Please enter API endpoint' }]}
                    >
                        <Input placeholder="https://api.example.com/data" />
                    </Form.Item>

                    <Form.Item
                        name="apiKey"
                        label="API Key"
                        rules={[{ required: false }]}
                    >
                        <Input.Password placeholder="Enter API key (optional)" />
                    </Form.Item>

                    <Form.Item
                        name="pollingIntervalMinutes"
                        label="Polling Interval (Minutes)"
                        rules={[{ required: true, message: 'Please enter polling interval' }]}
                    >
                        <InputNumber 
                            min={1} 
                            max={1440} 
                            placeholder="5" 
                            style={{ width: '100%' }}
                        />
                    </Form.Item>

                    <Form.Item
                        name="additionalSettings"
                        label="Additional Settings"
                    >
                        <Input.TextArea 
                            rows={3} 
                            placeholder="JSON configuration or additional settings"
                        />
                    </Form.Item>

                    <Form.Item>
                        <Space>
                            <Button type="primary" htmlType="submit">
                                {editingSource ? 'Update' : 'Create'}
                            </Button>
                            <Button onClick={() => setModalVisible(false)}>
                                Cancel
                            </Button>
                        </Space>
                    </Form.Item>
                </Form>
            </Modal>
        </div>
    );
};

export default APIDataSources;
