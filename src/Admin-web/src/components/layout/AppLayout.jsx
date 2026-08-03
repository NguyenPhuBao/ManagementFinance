import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Layout } from 'antd';
import AppSidebar from './Sidebar';
import AppHeader from './Header';

const { Content } = Layout;

const AppLayout = () => {
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);

  const toggleSidebar = () => setSidebarCollapsed(prev => !prev);

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <AppSidebar collapsed={sidebarCollapsed} onCollapse={setSidebarCollapsed} />
      <Layout>
        <AppHeader collapsed={sidebarCollapsed} onMenuToggle={toggleSidebar} />
        <Content
          style={{
            padding: 24,
            margin: 0,
            minHeight: 280,
            overflowY: 'auto',
          }}
        >
          <div style={{ maxWidth: 1440, margin: '0 auto', width: '100%' }}>
            <Outlet />
          </div>
        </Content>
      </Layout>
    </Layout>
  );
};

export default AppLayout;
