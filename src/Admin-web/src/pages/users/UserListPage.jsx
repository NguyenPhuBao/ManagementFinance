import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Table, Typography, Input, Space, Button, Tag, Modal, Select, Radio, Card, Tooltip } from 'antd';
import { SearchOutlined, FilterOutlined, EyeOutlined } from '@ant-design/icons';
import { USER_STATUS_LABELS } from '../../utils/constants';

const { Title, Text } = Typography;
const { Option } = Select;

// Mock user data from Stitch design
const MOCK_USERS = [
  { id: 'USR-001', name: 'Nguyễn Văn An', email: 'an.nguyen@example.com', phone: '0901234567', status: 'active', location: 'TP. Hồ Chí Minh', address: '123 Đường Lê Lợi, Quận 1', role: 'Người dùng chuẩn' },
  { id: 'USR-002', name: 'Trần Thị Bích', email: 'bich.tran@example.com', phone: '0912345678', status: 'inactive', location: 'Hà Nội', address: '456 Đường Nguyễn Huệ, Hoàn Kiếm', role: 'Người dùng chuẩn' },
  { id: 'USR-003', name: 'Lê Minh Đạt', email: 'dat.le@example.com', phone: '0987654321', status: 'active', location: 'Đà Nẵng', address: '789 Đường Hải Phòng, Hải Châu', role: 'Người dùng chuẩn' },
  { id: 'USR-004', name: 'Phạm Hoàng Nam', email: 'nam.pham@example.com', phone: '0934567890', status: 'active', location: 'Cần Thơ', address: '321 Đường 30/4, Ninh Kiều', role: 'Người dùng chuẩn' },
  { id: 'USR-005', name: 'Vũ Thị Lan', email: 'lan.vu@example.com', phone: '0945678901', status: 'inactive', location: 'TP. Hồ Chí Minh', address: '654 Đường Võ Văn Tần, Quận 3', role: 'Người dùng chuẩn' },
  { id: 'USR-006', name: 'Đặng Văn Hùng', email: 'hung.dang@example.com', phone: '0956789012', status: 'active', location: 'Hà Nội', address: '987 Đường Láng, Đống Đa', role: 'Người dùng chuẩn' },
  { id: 'USR-007', name: 'Hoàng Minh Tú', email: 'tu.hoang@example.com', phone: '0967890123', status: 'active', location: 'Đà Nẵng', address: '147 Đường Nguyễn Văn Linh', role: 'Người dùng chuẩn' },
  { id: 'USR-008', name: 'Bùi Thị Mai', email: 'mai.bui@example.com', phone: '0978901234', status: 'inactive', location: 'TP. Hồ Chí Minh', address: '258 Đường Cách Mạng Tháng 8', role: 'Người dùng chuẩn' },
  { id: 'USR-009', name: 'Đỗ Anh Quân', email: 'quan.do@example.com', phone: '0989012345', status: 'active', location: 'Hà Nội', address: '369 Đường Trần Duy Hưng', role: 'Người dùng chuẩn' },
  { id: 'USR-010', name: 'Lý Gia Bảo', email: 'bao.ly@example.com', phone: '0990123456', status: 'active', location: 'Cần Thơ', address: '753 Đường 3/2', role: 'Người dùng chuẩn' },
  { id: 'USR-011', name: 'Ngô Quốc Khánh', email: 'khanh.ngo@example.com', phone: '0901112223', status: 'active', location: 'TP. Hồ Chí Minh', address: '852 Đường Phan Đăng Lưu', role: 'Người dùng chuẩn' },
  { id: 'USR-012', name: 'Mai Thanh Trúc', email: 'truc.mai@example.com', phone: '0912223334', status: 'inactive', location: 'Đà Nẵng', address: '951 Đường Lê Duẩn', role: 'Người dùng chuẩn' },
  { id: 'USR-013', name: 'Đinh Văn Tiến', email: 'tien.dinh@example.com', phone: '0983334445', status: 'active', location: 'Hà Nội', address: '753 Đường Giải Phóng', role: 'Người dùng chuẩn' },
  { id: 'USR-014', name: 'Lương Minh Tuấn', email: 'tuan.luong@example.com', phone: '0934445556', status: 'active', location: 'TP. Hồ Chí Minh', address: '159 Đường Nguyễn Thị Minh Khai', role: 'Người dùng chuẩn' },
  { id: 'USR-015', name: 'Võ Hoàng Yến', email: 'yen.vo@example.com', phone: '0945556667', status: 'inactive', location: 'Cần Thơ', address: '357 Đường Trần Phú', role: 'Người dùng chuẩn' },
  { id: 'USR-016', name: 'Trương Văn Lâm', email: 'lam.truong@example.com', phone: '0956667778', status: 'active', location: 'Đà Nẵng', address: '951 Đường Tôn Đức Thắng', role: 'Người dùng chuẩn' },
  { id: 'USR-017', name: 'Hà Thị Ngọc', email: 'ngoc.ha@example.com', phone: '0967778889', status: 'active', location: 'Hà Nội', address: '456 Đường Kim Mã', role: 'Người dùng chuẩn' },
  { id: 'USR-018', name: 'Cao Thanh Sơn', email: 'son.cao@example.com', phone: '0978889990', status: 'inactive', location: 'TP. Hồ Chí Minh', address: '789 Đường Điện Biên Phủ', role: 'Người dùng chuẩn' },
  { id: 'USR-019', name: 'Tô Mỹ Duyên', email: 'duyen.to@example.com', phone: '0989990001', status: 'active', location: 'Đà Nẵng', address: '123 Đường Hoàng Sa', role: 'Người dùng chuẩn' },
  { id: 'USR-020', name: 'Phan Văn Toàn', email: 'toan.phan@example.com', phone: '0990001112', status: 'active', location: 'Cần Thơ', address: '456 Đường Mậu Thân', role: 'Người dùng chuẩn' },
  { id: 'USR-021', name: 'Lâm Hải Đăng', email: 'dang.lam@example.com', phone: '0901213141', status: 'active', location: 'Hà Nội', address: '789 Đường Hoàng Quốc Việt', role: 'Người dùng chuẩn' },
  { id: 'USR-022', name: 'Chu Thị Kim', email: 'kim.chu@example.com', phone: '0912324252', status: 'inactive', location: 'TP. Hồ Chí Minh', address: '321 Đường Lý Tự Trọng', role: 'Người dùng chuẩn' },
  { id: 'USR-023', name: 'Tạ Minh Châu', email: 'chau.ta@example.com', phone: '0987675747', status: 'active', location: 'Đà Nẵng', address: '654 Đường Phan Chu Trinh', role: 'Người dùng chuẩn' },
  { id: 'USR-024', name: 'Mạc Văn Cường', email: 'cuong.mac@example.com', phone: '0934546474', status: 'active', location: 'Hà Nội', address: '987 Đường Xuân Thủy', role: 'Người dùng chuẩn' },
];

const UserListPage = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState(MOCK_USERS);
  const [search, setSearch] = useState('');
  const [showFilterModal, setShowFilterModal] = useState(false);
  const [filter, setFilter] = useState({ location: 'all', status: 'all' });

  const filteredUsers = users.filter((u) => {
    const matchSearch = u.name.toLowerCase().includes(search.toLowerCase()) || u.email.toLowerCase().includes(search.toLowerCase()) || u.phone.includes(search);
    const matchStatus = filter.status === 'all' || u.status === filter.status;
    const matchLocation = filter.location === 'all' || 
      (filter.location === 'hcm' && u.location === 'TP. Hồ Chí Minh') ||
      (filter.location === 'hn' && u.location === 'Hà Nội') ||
      (filter.location === 'dn' && u.location === 'Đà Nẵng') ||
      (filter.location === 'ct' && u.location === 'Cần Thơ');
    return matchSearch && matchStatus && matchLocation;
  });

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const toggleUserStatus = (userId) => {
    setUsers(users.map(u => (u.id === userId ? { ...u, status: u.status === 'active' ? 'inactive' : 'active' } : u)));
  };

  const columns = [
    {
      title: 'STT',
      key: 'index',
      render: (text, record, index) => <Text type="secondary">{String(index + 1).padStart(2, '0')}</Text>,
      width: 80,
    },
    {
      title: 'HỌ TÊN',
      dataIndex: 'name',
      key: 'name',
      render: (text) => <Text strong>{text}</Text>,
    },
    {
      title: 'EMAIL',
      dataIndex: 'email',
      key: 'email',
      render: (text) => <Text type="secondary">{text}</Text>,
    },
    {
      title: 'SỐ ĐIỆN THOẠI',
      dataIndex: 'phone',
      key: 'phone',
      render: (text) => <Text type="secondary">{text}</Text>,
    },
    {
      title: 'TRẠNG THÁI',
      dataIndex: 'status',
      key: 'status',
      render: (status) => (
        <Tag color={status === 'active' ? 'success' : 'default'} style={{ borderRadius: 9999, fontWeight: 600 }}>
          {USER_STATUS_LABELS[status]}
        </Tag>
      ),
    },
    {
      title: 'HÀNH ĐỘNG',
      key: 'action',
      align: 'right',
      render: (_, record) => {
        const isActive = record.status === 'active';
        return (
          <Space>
            <Button 
              type={isActive ? "default" : "primary"}
              danger={isActive}
              onClick={() => toggleUserStatus(record.id)}
            >
              {isActive ? 'Vô hiệu hóa' : 'Kích hoạt'}
            </Button>
            <Tooltip title="Xem chi tiết">
              <Button 
                icon={<EyeOutlined />} 
                onClick={() => navigate(`/users/${record.id}`, { state: { user: record } })}
              />
            </Tooltip>
          </Space>
        );
      },
    },
  ];

  return (
    <div>
      {/* Page Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <Title level={3} style={{ margin: 0 }}>Quản lý người dùng</Title>
        <Space>
          <Input
            placeholder="Tìm kiếm người dùng..."
            prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ width: 256, borderRadius: 6 }}
          />
          <Button icon={<FilterOutlined />} onClick={() => setShowFilterModal(true)}>
            Lọc
          </Button>
        </Space>
      </div>

      {/* Table */}
      <Card bordered={false} bodyStyle={{ padding: 0 }}>
        <Table
          columns={columns}
          dataSource={filteredUsers}
          rowKey="id"
          loading={loading}
          pagination={{ 
            pageSize: 10, 
            showSizeChanger: false, 
            showTotal: (total, range) => `Hiển thị ${range[0]} - ${range[1]} của ${total} người dùng` 
          }}
        />
      </Card>

      {/* Filter Modal */}
      <Modal
        title="Lọc dữ liệu"
        open={showFilterModal}
        onCancel={() => setShowFilterModal(false)}
        onOk={() => setShowFilterModal(false)}
        okText="Áp dụng"
        cancelText="Hủy"
      >
        <Space direction="vertical" style={{ width: '100%', marginTop: 16 }} size="large">
          <div>
            <Text strong style={{ display: 'block', marginBottom: 8, textTransform: 'uppercase', fontSize: 12 }}>
              Khu vực (Location)
            </Text>
            <Select 
              style={{ width: '100%' }} 
              value={filter.location} 
              onChange={(v) => setFilter({ ...filter, location: v })}
            >
              <Option value="all">Tất cả khu vực</Option>
              <Option value="hcm">TP. Hồ Chí Minh</Option>
              <Option value="hn">Hà Nội</Option>
              <Option value="dn">Đà Nẵng</Option>
              <Option value="ct">Cần Thơ</Option>
            </Select>
          </div>
          <div>
            <Text strong style={{ display: 'block', marginBottom: 8, textTransform: 'uppercase', fontSize: 12 }}>
              Trạng thái
            </Text>
            <Radio.Group 
              value={filter.status} 
              onChange={(e) => setFilter({ ...filter, status: e.target.value })}
              style={{ display: 'flex', flexDirection: 'column', gap: 8 }}
            >
              <Radio value="all">Tất cả</Radio>
              <Radio value="active">{USER_STATUS_LABELS['active']}</Radio>
              <Radio value="inactive">{USER_STATUS_LABELS['inactive']}</Radio>
            </Radio.Group>
          </div>
        </Space>
      </Modal>
    </div>
  );
};

export default UserListPage;
