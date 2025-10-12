import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ConfigProvider, theme } from 'antd';
import AppLayout from './components/layout/AppLayout';
import Dashboard from './pages/Dashboard';
import DataSources from './pages/FileDataSources';
import APIDataSources from './pages/APIDataSources';
import AzureStorage from './pages/AzureStorage';
import UploadProcessor from './pages/UploadProcessor';
import Settings from './pages/Settings';
import PushServerSetting from './pages/PushServerSetting';
import { NotificationProvider } from './contexts/NotificationContext';
import 'antd/dist/reset.css';
import './App.css';

const App: React.FC = () => {
    return (
        <ConfigProvider
            theme={{
                algorithm: theme.defaultAlgorithm,
                token: {
                    colorPrimary: '#1890ff',
                    borderRadius: 6,
                },
            }}
        >
            <NotificationProvider>
                <Router>
                    <AppLayout>
                        <Routes>
                            <Route path="/" element={<Dashboard />} />
                            <Route path="/dashboard" element={<Dashboard />} />
                            <Route path="/data-sources" element={<DataSources />} />
                            <Route path="/api-data-sources" element={<APIDataSources />} />
                            <Route path="/push-server" element={<PushServerSetting />} />
                            <Route path="/azure-storage" element={<AzureStorage />} />
                            <Route path="/upload-processor" element={<UploadProcessor />} />
                            <Route path="/settings" element={<Settings />} />
                        </Routes>
                    </AppLayout>
                </Router>
            </NotificationProvider>
        </ConfigProvider>
    );
};

export default App;
