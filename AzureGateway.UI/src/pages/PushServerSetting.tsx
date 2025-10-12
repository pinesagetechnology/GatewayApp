import React, { useState, useEffect } from 'react';
import {
    Card, Button, Space, Typography, Row, Col, Form,
    Input, Switch, Badge, Divider, Alert, Spin
} from 'antd';
import {
    PlayCircleOutlined, PauseCircleOutlined, SaveOutlined,
    ReloadOutlined, ApiOutlined, FolderOutlined, ClockCircleOutlined,
    UserOutlined
} from '@ant-design/icons';
import { useNotification } from '../contexts/NotificationContext';
import { apiService, handleApiError, formatDateTime } from '../services/apiService';
import { PushServerSetting as PushServerSettingModel } from '../models/PushServerSetting';

const { Title, Text } = Typography;

const PushServerSetting: React.FC = () => {
    const [loading, setLoading] = useState<boolean>(true);
    const [saving, setSaving] = useState<boolean>(false);
    const [setting, setSetting] = useState<PushServerSettingModel | null>(null);
    const [form] = Form.useForm();
    const { showNotification } = useNotification();

    const loadSettings = async (): Promise<void> => {
        try {
            setLoading(true);
            const response = await apiService.getPushServerSetting();
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
                const response = await apiService.enablePushServer({ updatedBy: 'UI Admin' });
                setSetting(response.data);
                form.setFieldsValue({ isEnabled: response.data.isEnabled });
                showNotification('success', 'Push Server Enabled', 'Push server has been enabled successfully');
            } else {
                const response = await apiService.disablePushServer({ updatedBy: 'UI Admin' });
                setSetting(response.data);
                form.setFieldsValue({ isEnabled: response.data.isEnabled });
                showNotification('success', 'Push Server Disabled', 'Push server has been disabled successfully');
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
                updatedBy: 'UI Admin',
            };

            const response = await apiService.updatePushServerSetting(payload);
            setSetting(response.data);
            showNotification('success', 'Settings Updated', 'Push server settings have been updated successfully');
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
                    <ApiOutlined /> Push Server Settings
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
                    message={setting.isEnabled ? 'Push Server is Active' : 'Push Server is Inactive'}
                    description={
                        setting.isEnabled
                            ? 'The push server is currently enabled and accepting incoming data from third-party services.'
                            : 'The push server is currently disabled and rejecting incoming data requests.'
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
                        Enable Push Server
                    </Button>
                    <Button
                        danger
                        size="large"
                        icon={<PauseCircleOutlined />}
                        onClick={() => handleEnableDisable(false)}
                        disabled={!setting?.isEnabled || saving}
                        loading={saving}
                    >
                        Disable Push Server
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
                        <Col xs={24} sm={12} md={6}>
                            <Space direction="vertical" style={{ width: '100%' }}>
                                <Text type="secondary"><ClockCircleOutlined /> Last Updated</Text>
                                <Text strong>{formatDateTime(setting.updatedAt)}</Text>
                            </Space>
                        </Col>
                        <Col xs={24} sm={12} md={6}>
                            <Space direction="vertical" style={{ width: '100%' }}>
                                <Text type="secondary"><UserOutlined /> Updated By</Text>
                                <Text strong>{setting.updatedBy || 'System'}</Text>
                            </Space>
                        </Col>
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
                        tooltip="The absolute path where incoming push data will be stored"
                    >
                        <Input
                            placeholder="/data/vivotek"
                            prefix={<FolderOutlined />}
                            size="large"
                        />
                    </Form.Item>

                    <Form.Item
                        name="isEnabled"
                        label="Service Status"
                        valuePropName="checked"
                        tooltip="Enable or disable the push server to accept incoming data"
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
                title="About Push Server"
                style={{ marginTop: 24 }}
                type="inner"
            >
                <Space direction="vertical" style={{ width: '100%' }}>
                    <Text>
                        The Push Server allows third-party services (like Vivotek cameras) to send data to your system via HTTP POST requests.
                    </Text>
                    <Text>
                        <Text strong>Endpoint:</Text> POST /Vivotek/push
                    </Text>
                    <Text>
                        When enabled, incoming data is saved to the configured folder path with timestamps for tracking.
                    </Text>
                    <Text type="warning">
                        Note: Disabling the push server will reject all incoming requests with HTTP 503 status.
                    </Text>
                </Space>
            </Card>
        </div>
    );
};

export default PushServerSetting;

