import React, { useState, useEffect } from 'react';
import { Card, Row, Col, Typography, Table, Space, Button, Modal, Select, Input, Radio, Badge } from 'antd';
import { FilterOutlined, LineChartOutlined } from '@ant-design/icons';
import { TIME_FILTERS, TIME_FILTER_LABELS } from '../../utils/constants';

const { Title, Text } = Typography;

const StatCard = ({ icon, title, value, badge, badgeColor }) => (
  <Card bordered={false} style={{ height: '100%' }}>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
      <div style={{
        width: 40,
        height: 40,
        borderRadius: 8,
        backgroundColor: '#e5eeff',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: '#10b981',
      }}>
        <span className="material-symbols-outlined">{icon}</span>
      </div>
      {badge && (
        <Badge
          count={badge}
          style={{
            backgroundColor: badgeColor === 'green' ? '#dcfce7' : '#eff4ff',
            color: badgeColor === 'green' ? '#166534' : '#565e74',
            fontWeight: 600
          }}
        />
      )}
    </div>
    <div>
      <Text type="secondary" style={{ display: 'block', marginBottom: 4 }}>
        {title}
      </Text>
      <Title level={2} style={{ margin: 0 }}>
        {value}
      </Title>
    </div>
  </Card>
);

const DashboardPage = () => {
  const [loading, setLoading] = useState(true);
  const [timeFilter, setTimeFilter] = useState(TIME_FILTERS.MONTH);
  const [showFilterModal, setShowFilterModal] = useState(false);

  // Simulated data
  const stats = {
    totalUsers: { value: '12,205', badge: '12%', badgeColor: 'green' },
    totalCategories: { value: '48', badge: null },
    systemUptime: { value: '99.9%', badge: 'Ổn định' },
    newUsersToday: { value: '331', badge: '5%', badgeColor: 'green' },
    loginAvg: '91',
    loginPeak: '113',
  };

  const recentActivities = [
    { key: '1', user: 'Nguyễn Văn A', action: 'Tạo giao dịch mới', time: '10:45 AM' },
    { key: '2', user: 'Trần Thị B', action: 'Cập nhật hồ sơ', time: '09:12 AM' },
    { key: '3', user: 'Lê Văn C', action: 'Xóa danh mục', time: 'Hôm qua' },
  ];

  const columns = [
    {
      title: 'Người dùng',
      dataIndex: 'user',
      key: 'user',
      render: (text) => (
        <Space>
          <div style={{
            width: 32,
            height: 32,
            borderRadius: '50%',
            backgroundColor: '#dae2fd',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontWeight: 600,
            color: '#5c647a',
          }}>
            {text.split(' ').pop().charAt(0)}
          </div>
          <Text strong>{text}</Text>
        </Space>
      ),
    },
    {
      title: 'Hành động',
      dataIndex: 'action',
      key: 'action',
      render: (text) => <Text type="secondary">{text}</Text>
    },
    {
      title: 'Thời gian',
      dataIndex: 'time',
      key: 'time',
      align: 'right',
      render: (text) => <Text type="secondary">{text}</Text>
    },
  ];

  useEffect(() => {
    // Simulate data loading
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, [timeFilter]);

  return (
    <div>
      {/* Page Header */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginBottom: 24 }}>
        <div>
          <Title level={3} style={{ margin: 0 }}>Tổng quan hệ thống</Title>
          <Text type="secondary">Dữ liệu tài chính và hoạt động được cập nhật liên tục.</Text>
        </div>

        {/* Time Filter */}
        <Radio.Group 
          value={timeFilter} 
          onChange={e => setTimeFilter(e.target.value)}
          buttonStyle="solid"
        >
          {Object.entries(TIME_FILTER_LABELS).map(([key, label]) => (
            <Radio.Button key={key} value={key}>{label}</Radio.Button>
          ))}
        </Radio.Group>
      </div>

      {/* Stat Cards Grid */}
      <Row gutter={[24, 24]} style={{ marginBottom: 24 }}>
        <Col xs={24} sm={12} xl={6}>
          <StatCard icon="group" title="Total Users" value={stats.totalUsers.value} badge={stats.totalUsers.badge} badgeColor={stats.totalUsers.badgeColor} />
        </Col>
        <Col xs={24} sm={12} xl={6}>
          <StatCard icon="category" title="Total Categories" value={stats.totalCategories.value} badge={stats.totalCategories.badge} />
        </Col>
        <Col xs={24} sm={12} xl={6}>
          <StatCard icon="dns" title="System Uptime" value={stats.systemUptime.value} badge={stats.systemUptime.badge} />
        </Col>
        <Col xs={24} sm={12} xl={6}>
          <StatCard icon="person_add" title="New Users Today" value={stats.newUsersToday.value} badge={stats.newUsersToday.badge} badgeColor={stats.newUsersToday.badgeColor} />
        </Col>
      </Row>

      {/* Two-column section */}
      <Row gutter={[24, 24]} style={{ marginBottom: 24 }}>
        {/* Recent Activities */}
        <Col xs={24} lg={14}>
          <Card 
            title="Hoạt động gần đây" 
            bordered={false}
            extra={
              <Space>
                <Button icon={<FilterOutlined />} onClick={() => setShowFilterModal(true)}>
                  Lọc
                </Button>
                <Button type="link">Xem tất cả</Button>
              </Space>
            }
            bodyStyle={{ padding: 0 }}
          >
            <Table 
              columns={columns} 
              dataSource={recentActivities}
              pagination={false}
              loading={loading}
            />
          </Card>
        </Col>

        {/* Login Statistics */}
        <Col xs={24} lg={10}>
          <Card 
            title="Thống kê đăng nhập" 
            bordered={false}
            extra={<LineChartOutlined style={{ color: '#94a3b8' }} />}
          >
            <Text type="secondary" style={{ display: 'block', marginBottom: 24 }}>
              Số lần đăng nhập theo giờ/ngày
            </Text>

            {/* Mock Chart */}
            <div style={{ height: 200, position: 'relative', marginBottom: 24 }}>
              <svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none">
                <path d="M 0 39 Q 20 29 40 42 T 80 45 T 100 37" fill="none" stroke="#10b981" strokeWidth="3" />
                {[0, 20, 40, 60, 80, 100].map((x, i) => (
                  <circle key={i} cx={x} cy={[39, 29, 42, 30, 45, 37][i]} r="2" fill="#10b981" />
                ))}
              </svg>
              <div style={{
                position: 'absolute',
                bottom: '-24px',
                left: 0,
                right: 0,
                display: 'flex',
                justifyContent: 'space-between',
                fontSize: 10,
                color: '#94a3b8',
              }}>
                <span>00:00</span>
                <span>08:00</span>
                <span>16:00</span>
                <span>23:59</span>
              </div>
            </div>

            <Row justify="space-between" style={{ marginTop: 32 }}>
              <Col>
                <Text type="secondary">Trung bình/giờ</Text>
                <Title level={4} style={{ margin: 0 }}>{stats.loginAvg}</Title>
              </Col>
              <Col style={{ textAlign: 'right' }}>
                <Text type="secondary">Cao nhất</Text>
                <Title level={4} style={{ margin: 0 }}>{stats.loginPeak}</Title>
              </Col>
            </Row>
          </Card>
        </Col>
      </Row>

      {/* Request Statistics */}
      <Card bordered={false}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 24 }}>
          <div>
            <Title level={4} style={{ margin: 0 }}>Thống kê Request thời gian thực</Title>
            <Text type="secondary">Theo dõi lưu lượng truy cập hệ thống theo thời gian thực</Text>
          </div>
          <Space>
            <Badge color="#10b981" text="Số lượng Request" />
            <LineChartOutlined style={{ color: '#94a3b8' }} />
          </Space>
        </div>

        <div style={{ width: '100%', aspectRatio: '5/2', position: 'relative' }}>
          <svg width="100%" height="100%" viewBox="0 0 1000 400" preserveAspectRatio="none">
            <defs>
              <linearGradient id="requestGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor="#10b981" />
                <stop offset="100%" stopColor="#10b981" stopOpacity="0" />
              </linearGradient>
            </defs>
            <path d="M 0 155 Q 100 125 200 165 T 400 289 T 600 239 T 800 186 T 1000 155" fill="none" stroke="#10b981" strokeWidth="3" />
            <path d="M 0 155 Q 100 125 200 165 T 400 289 T 600 239 T 800 186 T 1000 155 L 1000 400 L 0 400 Z" fill="url(#requestGradient)" opacity="0.1" />
          </svg>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 12, color: '#94a3b8' }}>
            {['14:00', '14:15', '14:30', '14:45', '15:00', '15:15', '15:30'].map((time) => (
              <Text type="secondary" key={time}>{time}</Text>
            ))}
          </div>
        </div>
      </Card>

      {/* Filter Modal */}
      <Modal
        title="Lọc hoạt động"
        open={showFilterModal}
        onCancel={() => setShowFilterModal(false)}
        onOk={() => setShowFilterModal(false)}
        okText="Áp dụng"
        cancelText="Hủy"
      >
        <Space direction="vertical" style={{ width: '100%', marginTop: 16 }} size="large">
          <div>
            <Text strong style={{ display: 'block', marginBottom: 8 }}>Hành động</Text>
            <Input placeholder="Nhập hành động..." />
          </div>
          <div>
            <Text strong style={{ display: 'block', marginBottom: 8 }}>Người dùng</Text>
            <Select
              style={{ width: '100%' }}
              placeholder="Tất cả người dùng"
              options={[
                { value: '1', label: 'Nguyễn Văn A' },
                { value: '2', label: 'Trần Thị B' },
                { value: '3', label: 'Lê Văn C' },
              ]}
            />
          </div>
        </Space>
      </Modal>
    </div>
  );
};

export default DashboardPage;
