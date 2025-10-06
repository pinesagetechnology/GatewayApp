import React, { useState, useEffect } from 'react';
import {
    Card, Button, Table, Space, Typography, Row, Col, Badge, Statistic,
    Tooltip, Tag, Progress, Alert, Tabs
} from 'antd';
import {
    ReloadOutlined, FileOutlined, ClockCircleOutlined,
    CheckCircleOutlined, ExclamationCircleOutlined, CloseCircleOutlined
} from '@ant-design/icons';
import { useNotification } from '../contexts/NotificationContext';
import { apiService, handleApiError, formatFileSize, formatDateTime } from '../services/apiService';
import { QueueItem, QueueSummary, QueueItemStatus, FileType } from '../models/UploadProcessor';

const { Title, Text } = Typography;

const UploadProcessor: React.FC = () => {
    const [loading, setLoading] = useState<boolean>(true);
    const [retrying, setRetrying] = useState<Set<number>>(new Set());
    const [queueItems, setQueueItems] = useState<QueueItem[]>([]);
    const [summary, setSummary] = useState<QueueSummary | null>(null);
    const [activeTab, setActiveTab] = useState<string>('all');

    const { showNotification } = useNotification();

    const loadQueueData = async (): Promise<void> => {
        try {
            setLoading(true);
            const [itemsResponse, summaryResponse] = await Promise.all([
                apiService.getQueueItems(),
                apiService.getQueueSummary()
            ]);
            
            setQueueItems(itemsResponse.data || []);
            setSummary(summaryResponse.data || null);
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Load Error', apiError.message);
        } finally {
            setLoading(false);
        }
    };

    const loadTabData = async (tab: string): Promise<void> => {
        try {
            setLoading(true);
            let itemsResponse;
            
            switch (tab) {
                case 'pending':
                    itemsResponse = await apiService.getPendingQueueItems();
                    break;
                case 'failed':
                    itemsResponse = await apiService.getFailedQueueItems();
                    break;
                default:
                    itemsResponse = await apiService.getQueueItems();
                    break;
            }
            
            setQueueItems(itemsResponse.data || []);
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Load Error', apiError.message);
        } finally {
            setLoading(false);
        }
    };

    const handleRetry = async (item: QueueItem): Promise<void> => {
        try {
            setRetrying(prev => new Set(prev).add(item.id));
            await apiService.reprocessQueueItem(item.id);
            showNotification('success', 'Retry Initiated', `Retry initiated for ${item.fileName}`);
            loadQueueData(); // Refresh all data
        } catch (error) {
            const apiError = handleApiError(error);
            showNotification('error', 'Retry Error', apiError.message);
        } finally {
            setRetrying(prev => {
                const newSet = new Set(prev);
                newSet.delete(item.id);
                return newSet;
            });
        }
    };

    const getStatusConfig = (status: number) => {
        switch (status) {
            case QueueItemStatus.Pending:
                return { color: 'processing', text: 'Pending', icon: <ClockCircleOutlined /> };
            case QueueItemStatus.Processing:
                return { color: 'processing', text: 'Processing', icon: <FileOutlined /> };
            case QueueItemStatus.Failed:
                return { color: 'error', text: 'Failed', icon: <CloseCircleOutlined /> };
            case QueueItemStatus.Completed:
                return { color: 'success', text: 'Completed', icon: <CheckCircleOutlined /> };
            default:
                return { color: 'default', text: 'Unknown', icon: <ExclamationCircleOutlined /> };
        }
    };

    const getFileTypeText = (fileType: number) => {
        switch (fileType) {
            case FileType.Other:
                return 'Json';
            case FileType.Image:
                return 'Image';
            default:
                return 'Others';
        }
    };

    const canRetry = (item: QueueItem): boolean => {
        return (item.status === QueueItemStatus.Failed || 
                item.status === QueueItemStatus.Pending) && 
               item.attemptCount < item.maxRetries;
    };

    useEffect(() => {
        loadQueueData();
    }, []);

    useEffect(() => {
        if (activeTab !== 'all') {
            loadTabData(activeTab);
        } else {
            loadQueueData();
        }
    }, [activeTab]);

    const columns = [
        {
            title: 'File Name',
            dataIndex: 'fileName',
            key: 'fileName',
            render: (text: string, record: QueueItem) => (
                <Space>
                    <FileOutlined />
                    <div>
                        <Text strong>{text}</Text>
                        <br />
                        <Text type="secondary" style={{ fontSize: '12px' }}>
                            {record.filePath}
                        </Text>
                    </div>
                </Space>
            ),
            ellipsis: true,
        },
        {
            title: 'Type',
            dataIndex: 'fileType',
            key: 'fileType',
            render: (fileType: number) => (
                <Tag>{getFileTypeText(fileType)}</Tag>
            ),
            width: 100,
        },
        {
            title: 'Size',
            dataIndex: 'fileSizeBytes',
            key: 'fileSizeBytes',
            render: (bytes: number) => formatFileSize(bytes),
            width: 100,
        },
        {
            title: 'Status',
            dataIndex: 'status',
            key: 'status',
            render: (status: number, record: QueueItem) => {
                const config = getStatusConfig(status);
                return (
                    <Space direction="vertical" size="small">
                        <Badge 
                            status={config.color as any} 
                            text={
                                <Space>
                                    {config.icon}
                                    {config.text}
                                </Space>
                            } 
                        />
                        {record.errorMessage && (
                            <Tooltip title={record.errorMessage}>
                                <Text type="danger" style={{ fontSize: '11px' }}>
                                    {record.errorMessage.length > 50 
                                        ? `${record.errorMessage.substring(0, 50)}...` 
                                        : record.errorMessage}
                                </Text>
                            </Tooltip>
                        )}
                    </Space>
                );
            },
            width: 150,
        },
        {
            title: 'Attempts',
            dataIndex: 'attemptCount',
            key: 'attemptCount',
            render: (attemptCount: number, record: QueueItem) => (
                <Space direction="vertical" size="small">
                    <Text>{attemptCount} / {record.maxRetries}</Text>
                    <Progress 
                        percent={(attemptCount / record.maxRetries) * 100} 
                        size="small" 
                        status={attemptCount >= record.maxRetries ? 'exception' : 'active'}
                    />
                </Space>
            ),
            width: 100,
        },
        {
            title: 'Created',
            dataIndex: 'createdAt',
            key: 'createdAt',
            render: (date: string) => (
                <Text type="secondary" style={{ fontSize: '12px' }}>
                    {formatDateTime(date)}
                </Text>
            ),
            width: 120,
        },
        {
            title: 'Completed',
            dataIndex: 'completedAt',
            key: 'completedAt',
            render: (date: string | null, record: QueueItem) => {
                if (!date) return <Text type="secondary">-</Text>;
                return (
                    <Space direction="vertical" size="small">
                        <Text style={{ fontSize: '12px' }}>
                            {formatDateTime(date)}
                        </Text>
                        {record.uploadDurationMs && (
                            <Text type="secondary" style={{ fontSize: '11px' }}>
                                {record.uploadDurationMs}ms
                            </Text>
                        )}
                    </Space>
                );
            },
            width: 120,
        },
        {
            title: 'Actions',
            key: 'actions',
            render: (text: any, record: QueueItem) => (
                <Space>
                    {canRetry(record) && (
                        <Tooltip title="Retry processing this item">
                            <Button
                                type="link"
                                icon={<ReloadOutlined />}
                                onClick={() => handleRetry(record)}
                                loading={retrying.has(record.id)}
                                style={{ color: '#1890ff' }}
                            >
                                Retry
                            </Button>
                        </Tooltip>
                    )}
                </Space>
            ),
            width: 100,
        },
    ];

    const tabItems = [
        {
            key: 'all',
            label: `All Items (${queueItems.length})`,
            children: null
        },
        {
            key: 'pending',
            label: `Pending (${queueItems.filter(item => item.status === QueueItemStatus.Pending).length})`,
            children: null
        },
        {
            key: 'failed',
            label: `Failed (${queueItems.filter(item => item.status === QueueItemStatus.Failed).length})`,
            children: null
        }
    ];

    return (
        <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
                <Title level={2} style={{ margin: 0 }}>Upload Processor Queue</Title>
                <Space>
                    <Button icon={<ReloadOutlined />} onClick={() => loadQueueData()}>
                        Refresh
                    </Button>
                </Space>
            </div>

            {/* Summary Statistics */}
            {summary && (
                <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
                    <Col xs={24} sm={6}>
                        <Card>
                            <Statistic
                                title="Total Files"
                                value={summary.totalFiles}
                                prefix={<FileOutlined />}
                            />
                        </Card>
                    </Col>
                    {summary.statusBreakdown.map((breakdown, index) => {
                        const config = getStatusConfig(breakdown.status);
                        return (
                            <Col xs={24} sm={6} key={index}>
                                <Card>
                                    <Statistic
                                        title={config.text}
                                        value={breakdown.count}
                                        prefix={config.icon}
                                    />
                                </Card>
                            </Col>
                        );
                    })}
                </Row>
            )}

            {/* Queue Items Table */}
            <Card>
                <Tabs
                    activeKey={activeTab}
                    onChange={setActiveTab}
                    items={tabItems}
                    style={{ marginBottom: 16 }}
                />
                
                <Table
                    columns={columns}
                    dataSource={queueItems}
                    rowKey="id"
                    loading={loading}
                    pagination={{
                        pageSize: 20,
                        showSizeChanger: true,
                        showQuickJumper: true,
                        showTotal: (total, range) => `${range[0]}-${range[1]} of ${total} items`,
                    }}
                    scroll={{ x: 1200 }}
                />
            </Card>
        </div>
    );
};

export default UploadProcessor;
