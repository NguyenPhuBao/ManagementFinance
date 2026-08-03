import React, { useState } from 'react';
import { Layout, Input, Badge, Dropdown, Avatar, Button, Typography, Space } from 'antd';
import { SearchOutlined, BellOutlined, MenuOutlined, UserOutlined } from '@ant-design/icons';

const { Header: AntHeader } = Layout;
const { Text } = Typography;

const Header = ({ collapsed, onMenuToggle }) => {
  const [searchValue, setSearchValue] = useState('');

  const notificationItems = [
    {
      key: '1',
      label: (
        <div style={{ textAlign: 'center', padding: '12px 0' }}>
          <span className="material-symbols-outlined" style={{ fontSize: 24, color: '#94a3b8', marginBottom: 8, display: 'block' }}>
            notifications_off
          </span>
          <Text type="secondary">Danh sách thông báo trống</Text>
        </div>
      ),
    }
  ];

  return (
    <AntHeader
      style={{
        padding: '0 24px',
        background: '#ffffff',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        borderBottom: '1px solid #e2e8f0',
        position: 'sticky',
        top: 0,
        zIndex: 30,
        height: 64,
        lineHeight: '64px',
      }}
    >
      {/* Left side */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 16, flex: 1 }}>
        <Button
          type="text"
          icon={<MenuOutlined />}
          onClick={onMenuToggle}
          style={{
            fontSize: '16px',
            width: 40,
            height: 40,
            display: 'none', // Shown on mobile in real responsive setup
          }}
          className="mobile-menu-btn"
        />
        
        <Text strong style={{ fontSize: 20 }}>
          Personal Finance Admin
        </Text>

        {/* Search */}
        <div style={{ maxWidth: 400, width: '100%', marginLeft: 16 }}>
          <Input
            placeholder="Search..."
            prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
            value={searchValue}
            onChange={(e) => setSearchValue(e.target.value)}
            style={{ borderRadius: 20, backgroundColor: '#eff4ff', border: '1px solid #e2e8f0' }}
          />
        </div>
      </div>

      {/* Right side */}
      <Space size={24} align="center">
        {/* Notifications */}
        <Dropdown menu={{ items: notificationItems }} placement="bottomRight" trigger={['click']}>
          <Badge dot offset={[-4, 4]} style={{ backgroundColor: '#ba1a1a' }}>
            <Button type="text" shape="circle" icon={<BellOutlined style={{ fontSize: 20, color: '#64748b' }} />} />
          </Badge>
        </Dropdown>

        {/* User avatar */}
        <Avatar
          style={{ backgroundColor: '#dae2fd', color: '#5c647a', border: '1px solid #e2e8f0', cursor: 'pointer' }}
          icon={<UserOutlined />}
        />
      </Space>
    </AntHeader>
  );
};

export default Header;
