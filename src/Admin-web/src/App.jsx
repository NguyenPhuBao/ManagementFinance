import React from 'react';
import { RouterProvider } from 'react-router-dom';
import { AuthProvider } from './store/auth.context';
import router from './router';

import { ConfigProvider } from 'antd';

const theme = {
  token: {
    colorPrimary: '#10b981', // Emerald Green (Primary)
    colorInfo: '#10b981',
    colorSuccess: '#10b981',
    colorError: '#ba1a1a', // Danger Red
    colorWarning: '#faad14',
    colorTextBase: '#0b1c30', // Deep Navy/Dark text
    colorBgBase: '#f8f9ff', // Background
    fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    borderRadius: 4, // 0.25rem standard radius
    wireframe: false,
  },
  components: {
    Layout: {
      headerBg: '#ffffff',
      siderBg: '#0f172a', // Deep Navy for sidebar
    },
    Menu: {
      darkItemBg: '#0f172a',
      darkItemSelectedBg: '#1e293b', // slightly lighter for active
      darkItemColor: '#94a3b8', // slate-400
      darkItemSelectedColor: '#ffffff',
    },
    Card: {
      colorBgContainer: '#ffffff',
      borderRadiusLG: 8,
    },
    Table: {
      headerBg: '#f8fafc', // Tertiary Off-White for table headers
    }
  },
};

const App = () => {
  return (
    <ConfigProvider theme={theme}>
      <AuthProvider>
        <RouterProvider router={router} />
      </AuthProvider>
    </ConfigProvider>
  );
};

export default App;
