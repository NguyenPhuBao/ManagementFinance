import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Layout, Menu, Typography } from 'antd';
import { useAuthContext } from '../../store/auth.context';

const { Sider } = Layout;
const { Title } = Typography;

const NAV_ITEMS = [
  { key: '/dashboard', icon: 'dashboard', label: 'Dashboard' },
  { key: '/users', icon: 'group', label: 'User Management' },
  { key: '/categories', icon: 'category', label: 'Category Management' },
];

const Sidebar = ({ collapsed, onCollapse }) => {
  const location = useLocation();
  const navigate = useNavigate();
  const { logout } = useAuthContext();

  const handleNav = ({ key }) => {
    if (key === 'logout') {
      logout().then(() => navigate('/login'));
      return;
    }
    navigate(key);
  };

  const getSelectedKey = () => {
    if (location.pathname === '/dashboard') return '/dashboard';
    const item = NAV_ITEMS.find(i => location.pathname.startsWith(i.key) && i.key !== '/');
    return item ? item.key : '/dashboard';
  };

  const menuItems = [
    ...NAV_ITEMS.map(item => ({
      key: item.key,
      icon: <span className="material-symbols-outlined">{item.icon}</span>,
      label: item.label,
    })),
    { type: 'divider' },
    {
      key: 'logout',
      icon: <span className="material-symbols-outlined">logout</span>,
      label: 'Logout',
    }
  ];

  return (
    <Sider
      collapsible
      collapsed={collapsed}
      onCollapse={onCollapse}
      width={280}
      breakpoint="lg"
      style={{
        height: '100vh',
        position: 'sticky',
        top: 0,
        left: 0,
      }}
      theme="dark"
    >
      <div style={{ padding: '24px 16px', display: 'flex', alignItems: 'center', gap: 12, justifyContent: collapsed ? 'center' : 'flex-start' }}>
        <div style={{
          width: 40,
          height: 40,
          borderRadius: '50%',
          backgroundColor: '#10b981', // primary-container
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: '#ffffff',
          flexShrink: 0,
        }}>
          <span className="material-symbols-outlined">account_balance</span>
        </div>
        {!collapsed && (
          <Title level={4} style={{ color: '#ffffff', margin: 0, whiteSpace: 'nowrap' }}>
            Management
          </Title>
        )}
      </div>

      <Menu
        theme="dark"
        mode="inline"
        selectedKeys={[getSelectedKey()]}
        onClick={handleNav}
        items={menuItems}
        style={{ borderRight: 0 }}
      />
    </Sider>
  );
};

export default Sidebar;
