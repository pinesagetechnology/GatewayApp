import React, { useState, useEffect } from 'react';
import {
    Card, Button, Table, Space, Typography, Row, Col, Modal, Form,
    Input, Switch, Tooltip, Badge,
    Popconfirm, Statistic
} from 'antd';
import {
    PlusOutlined, EditOutlined, DeleteOutlined, PlayCircleOutlined,
    PauseCircleOutlined, FolderOutlined, ReloadOutlined
} from '@ant-design/icons';
import { useNotification } from '../contexts/NotificationContext';
import { apiService, handleApiError } from '../services/apiService';
import { FileDataSourceConfig } from '../models/FileDataSource';

const { Title, Text } = Typography;

const DataSources: React.FC = () => {
    const [loading, setLoading] = useState<boolean>(true);
    const [dataSources, setDataSources] = useState<FileDataSourceConfig[]>([]);
    const [modalVisible, setModalVisible] = useState<boolean>(false);
    const [editingSource, setEditingSource] = useState<FileDataSourceConfig | null>(null);

    const [form] = Form.useForm();
    const { showNotification } = useNotification();

    const loadDataSources = async (): Promise<void> => {
        try {
            setLoading(true);
            const response = await apiService.getDataSources();
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
            filePattern: '*.*'
        });
        setModalVisible(true);
    };

    const handleEdit = (source: FileDataSourceConfig) => {
        setEditingSource(source);
        form.setFieldsValue({
            name: source.name,
            isEnabled: source.isEnabled,
            isRefreshing: source.isRefreshing,
            filePattern: source.filePattern,
            folderPath: source.folderPath
        });
        setModalVisible(true);
    };

    const handleDelete = async (id: number) => {
        try {
            await apiService.deleteDataSource(id);
            showNotification('success', 'Data Source Deleted', 'Data source has been deleted successfully');
            loadDataSources();
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Delete Error', apiError.message);
        }
    };

    // Function to enable/disable data sources
    const handleToggleStatus = async (source: FileDataSourceConfig) => {
        try {
            const updatedSource = { ...source, isEnabled: !source.isEnabled };
            await apiService.updateDataSource(source.id, updatedSource);
            
            showNotification(
                'success',
                'Data Source Status Updated',
                `Data source "${source.name}" has been ${updatedSource.isEnabled ? 'enabled' : 'disabled'}`
            );
            
            loadDataSources();
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Data Source Update Error', apiError.message);
        }
    };

    // Bulk function to enable/disable all data sources
    const handleToggleAllDataSources = async (enable: boolean) => {
        try {
            if (dataSources.length === 0) {
                showNotification('info', 'No Data Sources', 'No data sources found');
                return;
            }

            const updatePromises = dataSources.map(source => 
                apiService.updateDataSource(source.id, { ...source, isEnabled: enable })
            );

            await Promise.all(updatePromises);
            
            showNotification(
                'success',
                'Bulk Data Source Update',
                `All data sources have been ${enable ? 'enabled' : 'disabled'}`
            );
            
            loadDataSources();
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Bulk Data Source Update Error', apiError.message);
        }
    };

    const handleSubmit = async (values: any) => {
        try {
            const payload = {
                name: values.name,
                isEnabled: values.isEnabled,
                isRefreshing: values.isRefreshing,
                filePattern: values.filePattern,
                folderPath: values.folderPath,
            };

            if (editingSource) {
                await apiService.updateDataSource(editingSource.id, payload);
                showNotification('success', 'Data Source Updated', 'Data source has been updated successfully');
            } else {
                await apiService.createDataSource(payload);
                showNotification('success', 'Data Source Created', 'Data source has been created successfully');
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
            render: (text: string, record: FileDataSourceConfig) => (
                <Space>
                    <FolderOutlined />
                    <Text strong>{text}</Text>
                </Space>
            ),
        },
        {
            title: 'Status',
            dataIndex: 'isEnabled',
            key: 'isEnabled',
            render: (isEnabled: boolean, record: FileDataSourceConfig) => (
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
            title: 'Folder Path',
            dataIndex: 'folderPath',
            key: 'folderPath',
            ellipsis: true,
        },
        {
            title: 'File Pattern',
            dataIndex: 'filePattern',
            key: 'filePattern',
            ellipsis: true,
        },
        {
            title: 'Actions',
            key: 'actions',
            render: (text: any, record: FileDataSourceConfig) => (
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
                <Title level={2} style={{ margin: 0 }}>Data Sources</Title>
                <Space>
                    <Button icon={<ReloadOutlined />} onClick={loadDataSources}>
                        Refresh
                    </Button>
                    <Button type="primary" icon={<PlusOutlined />} onClick={handleCreateNew}>
                        Add Data Source
                    </Button>
                </Space>
            </div>

            {/* Bulk Actions */}
            <Card style={{ marginBottom: 24 }}>
                <Title level={4} style={{ marginBottom: 16 }}>Bulk Actions</Title>
                <Row gutter={[16, 16]}>
                    <Col xs={24} sm={12} md={6}>
                        <Space direction="vertical" style={{ width: '100%' }}>
                            <Text strong>All Data Sources</Text>
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
                            title="Total Data Sources"
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
                title={editingSource ? 'Edit Data Source' : 'Add Data Source'}
                open={modalVisible}
                onCancel={() => setModalVisible(false)}
                footer={null}
                width={500}
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
                        <Input placeholder="Enter data source name" />
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
                        name="folderPath"
                        label="Folder Path"
                        rules={[{ required: true, message: 'Please enter folder path' }]}
                    >
                        <Input placeholder="C:\\path\\to\\incoming" />
                    </Form.Item>

                    <Form.Item
                        name="filePattern"
                        label={
                            <Tooltip title="example: *.*, *.txt, *.{json,jpg,jpeg,png,txt,csv}">
                                File Pattern
                            </Tooltip>
                        }
                        rules={[{ required: true, message: 'Please enter file pattern' }]}
                    >
                        <Input placeholder="e.g., *.*" />
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

export default DataSources;