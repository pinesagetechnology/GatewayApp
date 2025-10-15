import React, { useState, useEffect } from 'react';
import {
    Card, Button, Space, Typography, Row, Col, Form,
    Input, Switch, Badge, Divider, Alert, Spin
} from 'antd';
import {
    PlayCircleOutlined, PauseCircleOutlined, SaveOutlined,
    ReloadOutlined, EnvironmentOutlined, FolderOutlined, ClockCircleOutlined,
    UserOutlined
} from '@ant-design/icons';
import { useNotification } from '../contexts/NotificationContext';
import { apiService, handleApiError, formatDateTime } from '../services/apiService';
import { GpsServerSetting as GpsServerSettingModel } from '../models/GpsServerSetting';

const { Title, Text } = Typography;

const GpsServerSetting: React.FC = () => {
    const [loading, setLoading] = useState<boolean>(true);
    const [saving, setSaving] = useState<boolean>(false);
    const [setting, setSetting] = useState<GpsServerSettingModel | null>(null);
    const [form] = Form.useForm();
    const { showNotification } = useNotification();

    const loadSettings = async (): Promise<void> => {
        try {
            setLoading(true);
            const response = await apiService.getGpsServerSetting();
            setSetting(response.data);
            
            // Update form with loaded data
            form.setFieldsValue({
                dataFolderPath: response.data.dataFolderPath,
                isEnabled: response.data.isEnabled,
            });
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Load Error', apiError.message);
        } finally {
            setLoading(false);
        }
    };

    const handleEnableDisable = async (enable: boolean) => {
        try {
            setSaving(true);
            if (enable) {
                const response = await apiService.enableGpsServer();
                setSetting(response.data);
                form.setFieldsValue({ isEnabled: response.data.isEnabled });
                showNotification('success', 'GPS Server Enabled', 'GPS server has been enabled successfully');
            } else {
                const response = await apiService.disableGpsServer();
                setSetting(response.data);
                form.setFieldsValue({ isEnabled: response.data.isEnabled });
                showNotification('success', 'GPS Server Disabled', 'GPS server has been disabled successfully');
            }
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Update Error', apiError.message);
        } finally {
            setSaving(false);
        }
    };

    const handleSubmit = async (values: any) => {
        try {
            setSaving(true);
            const payload = {
                isEnabled: values.isEnabled,
                dataFolderPath: values.dataFolderPath,
            };

            const response = await apiService.updateGpsServerSetting(payload);
            setSetting(response.data);
            showNotification('success', 'Settings Updated', 'GPS server settings have been updated successfully');
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Update Error', apiError.message);
        } finally {
            setSaving(false);
        }
    };

    useEffect(() => {
        loadSettings();
    }, []);

    if (loading) {
        return (
            <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: '400px' }}>
                <Spin size="large" />
            </div>
        );
    }

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                <Title level={2} style={{ margin: 0 }}>
                    <EnvironmentOutlined /> GPS Server Settings
                </Title>
                <Space>
                    <Button icon={<ReloadOutlined />} onClick={loadSettings} loading={loading}>
                        Refresh
                    </Button>
                </Space>
            </div>

            {/* Status Alert */}
            {setting && (
                <Alert
                    message={setting.isEnabled ? 'GPS Server is Active' : 'GPS Server is Inactive'}
                    description={
                        setting.isEnabled
                            ? 'The GPS server is currently enabled and accepting incoming GPS data from devices.'
                            : 'The GPS server is currently disabled and rejecting incoming GPS data requests.'
                    }
                    type={setting.isEnabled ? 'success' : 'warning'}
                    showIcon
                    style={{ marginBottom: 24 }}
                />
            )}

            {/* Quick Actions */}
            <Card title="Quick Actions" style={{ marginBottom: 24 }}>
                <Space size="large">
                    <Button
                        type="primary"
                        size="large"
                        icon={<PlayCircleOutlined />}
                        onClick={() => handleEnableDisable(true)}
                        disabled={setting?.isEnabled || saving}
                        loading={saving}
                    >
                        Enable GPS Server
                    </Button>
                    <Button
                        danger
                        size="large"
                        icon={<PauseCircleOutlined />}
                        onClick={() => handleEnableDisable(false)}
                        disabled={!setting?.isEnabled || saving}
                        loading={saving}
                    >
                        Disable GPS Server
                    </Button>
                </Space>
            </Card>

            {/* Current Status */}
            {setting && (
                <Card title="Current Status" style={{ marginBottom: 24 }}>
                    <Row gutter={[16, 16]}>
                        <Col xs={24} sm={12} md={6}>
                            <Space direction="vertical" style={{ width: '100%' }}>
                                <Text type="secondary">Status</Text>
                                <Badge
                                    status={setting.isEnabled ? 'processing' : 'default'}
                                    text={
                                        <Text strong style={{ fontSize: 16 }}>
                                            {setting.isEnabled ? 'Enabled' : 'Disabled'}
                                        </Text>
                                    }
                                />
                            </Space>
                        </Col>
                        <Col xs={24} sm={12} md={6}>
                            <Space direction="vertical" style={{ width: '100%' }}>
                                <Text type="secondary"><FolderOutlined /> Data Folder</Text>
                                <Text strong ellipsis style={{ maxWidth: '100%', display: 'block' }}>
                                    {setting.dataFolderPath || 'Not configured'}
                                </Text>
                            </Space>
                        </Col>
                        {setting.updatedAt && (
                            <Col xs={24} sm={12} md={6}>
                                <Space direction="vertical" style={{ width: '100%' }}>
                                    <Text type="secondary"><ClockCircleOutlined /> Last Updated</Text>
                                    <Text strong>{formatDateTime(setting.updatedAt)}</Text>
                                </Space>
                            </Col>
                        )}
                        {setting.updatedBy && (
                            <Col xs={24} sm={12} md={6}>
                                <Space direction="vertical" style={{ width: '100%' }}>
                                    <Text type="secondary"><UserOutlined /> Updated By</Text>
                                    <Text strong>{setting.updatedBy || 'System'}</Text>
                                </Space>
                            </Col>
                        )}
                    </Row>
                </Card>
            )}

            <Divider />

            {/* Configuration Form */}
            <Card title="Configuration Settings">
                <Form
                    form={form}
                    layout="vertical"
                    onFinish={handleSubmit}
                    disabled={saving}
                >
                    <Form.Item
                        name="dataFolderPath"
                        label="Data Folder Path"
                        rules={[
                            { required: true, message: 'Please enter the data folder path' },
                            { pattern: /^\//, message: 'Path must be absolute (start with /)' }
                        ]}
                        tooltip="The absolute path where incoming GPS data will be stored"
                    >
                        <Input
                            placeholder="/data/gps"
                            prefix={<FolderOutlined />}
                            size="large"
                        />
                    </Form.Item>

                    <Form.Item
                        name="isEnabled"
                        label="Service Status"
                        valuePropName="checked"
                        tooltip="Enable or disable the GPS server to accept incoming data"
                    >
                        <Switch
                            checkedChildren="Enabled"
                            unCheckedChildren="Disabled"
                        />
                    </Form.Item>

                    <Form.Item>
                        <Space>
                            <Button
                                type="primary"
                                htmlType="submit"
                                icon={<SaveOutlined />}
                                size="large"
                                loading={saving}
                            >
                                Save Configuration
                            </Button>
                        </Space>
                    </Form.Item>
                </Form>
            </Card>

            {/* Information Card */}
            <Card
                title="About GPS Server"
                style={{ marginTop: 24 }}
                type="inner"
            >
                <Space direction="vertical" style={{ width: '100%' }}>
                    <Text>
                        The GPS Server allows GPS tracking devices and services to send location data to your system via HTTP POST requests.
                    </Text>
                    <Text>
                        <Text strong>Endpoint:</Text> POST /Gps/push
                    </Text>
                    <Text>
                        When enabled, incoming GPS data is saved to the configured folder path with timestamps for tracking.
                    </Text>
                    <Text type="warning">
                        Note: Disabling the GPS server will reject all incoming requests with HTTP 503 status.
                    </Text>
                </Space>
            </Card>
        </div>
    );
};

export default GpsServerSetting;

