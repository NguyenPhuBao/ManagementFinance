import React, { useState, useEffect } from 'react';
import { Table, Button, Input, Space, Tag, Typography, Modal, Form, Select, Card, Popconfirm } from 'antd';
import { SearchOutlined, FilterOutlined, PlusOutlined, EditOutlined, DeleteOutlined, SyncOutlined } from '@ant-design/icons';
import { TRANSACTION_TYPE_LABELS } from '../../utils/constants';

const { Title, Text } = Typography;
const { Option } = Select;

// Mock data from Stitch design
const MOCK_CATEGORIES = [
  { id: 1, icon: 'restaurant', name: 'Ăn uống', keywords: 'ăn uống, food, restaurant, cafe, grabfood, shopeefood', isDefault: true, type: 'expense' },
  { id: 2, icon: 'commute', name: 'Di chuyển', keywords: 'di chuyển, taxi, grab, be, xăng, vé xe, gửi xe', isDefault: false, type: 'expense' },
  { id: 3, icon: 'payments', name: 'Lương', keywords: 'lương, salary, thưởng, bonus, thu nhập, được cho', isDefault: true, type: 'income' },
  { id: 4, icon: 'home', name: 'Nhà ở', keywords: 'tiền nhà, rent, điện, nước, internet, wifi, cáp', isDefault: true, type: 'expense' },
  { id: 5, icon: 'shopping_cart', name: 'Mua sắm', keywords: 'shopee, lazada, tiki, siêu thị, bách hóa xanh', isDefault: true, type: 'expense' },
  { id: 6, icon: 'credit_score', name: 'Trả nợ', keywords: 'trả nợ, thanh toán thẻ, lãi vay', isDefault: false, type: 'debt' },
  { id: 7, icon: 'health_and_safety', name: 'Sức khỏe', keywords: 'thuốc, bệnh viện, khám bệnh, bảo hiểm', isDefault: true, type: 'expense' },
  { id: 8, icon: 'school', name: 'Giáo dục', keywords: 'học phí, sách vở, khóa học', isDefault: true, type: 'expense' },
  { id: 9, icon: 'savings', name: 'Tiết kiệm', keywords: 'gửi tiết kiệm, heo đất, đầu tư', isDefault: false, type: 'income' },
  { id: 10, icon: 'redeem', name: 'Quà tặng', keywords: 'quà tặng, biếu, mừng tuổi', isDefault: false, type: 'expense' },
  { id: 11, icon: 'flight', name: 'Du lịch', keywords: 'vé máy bay, khách sạn, tour, visa', isDefault: false, type: 'expense' },
  { id: 12, icon: 'theater_comedy', name: 'Giải trí', keywords: 'phim, netflix, spotify, game, concert', isDefault: false, type: 'expense' },
  { id: 13, icon: 'build', name: 'Sửa chữa', keywords: 'sửa xe, sửa nhà, bảo trì, thay nhớt', isDefault: false, type: 'expense' },
  { id: 14, icon: 'local_atm', name: 'Lãi tiết kiệm', keywords: 'lãi ngân hàng, cổ tức, lãi suất', isDefault: true, type: 'income' },
  { id: 15, icon: 'styler', name: 'Làm đẹp', keywords: 'cắt tóc, mỹ phẩm, spa, skincare', isDefault: false, type: 'expense' },
  { id: 16, icon: 'volunteer_activism', name: 'Từ thiện', keywords: 'quyên góp, ủng hộ, giúp đỡ', isDefault: false, type: 'expense' },
  { id: 17, icon: 'pets', name: 'Thú cưng', keywords: 'thức ăn chó mèo, thú y, cát vệ sinh', isDefault: false, type: 'expense' },
  { id: 18, icon: 'work', name: 'Kinh doanh', keywords: 'doanh thu, bán hàng, lợi nhuận', isDefault: false, type: 'income' },
  { id: 19, icon: 'handyman', name: 'Dụng cụ', keywords: 'kìm, búa, tua vít, máy khoan', isDefault: false, type: 'expense' },
  { id: 20, icon: 'fastfood', name: 'Ăn uống ngoài', keywords: 'nhà hàng, tiệc tùng, liên hoan', isDefault: false, type: 'expense' },
  { id: 21, icon: 'security', name: 'Bảo hiểm', keywords: 'bảo hiểm nhân thọ, bảo hiểm y tế', isDefault: true, type: 'expense' },
  { id: 22, icon: 'account_balance', name: 'Thuế', keywords: 'thuế thu nhập cá nhân, thuế đất', isDefault: false, type: 'expense' },
  { id: 23, icon: 'atm', name: 'Tiền mặt', keywords: 'rút tiền, tiền mặt, ví, cash', isDefault: true, type: 'debt' },
  { id: 24, icon: 'volunteer_activism', name: 'Từ thiện', keywords: 'quyên góp, ủng hộ, từ thiện', isDefault: false, type: 'expense' },
  { id: 25, icon: 'trending_up', name: 'Đầu tư', keywords: 'chứng khoán, cổ phiếu, lãi đầu tư', isDefault: false, type: 'income' },
];

const getTypeBadgeColor = (type) => {
  switch (type) {
    case 'income': return 'success';
    case 'expense': return 'error';
    case 'debt': return 'default';
    default: return 'default';
  }
};

const CategoryPage = () => {
  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState(MOCK_CATEGORIES);
  const [search, setSearch] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showFilterModal, setShowFilterModal] = useState(false);
  const [editingCategory, setEditingCategory] = useState(null);

  const [form] = Form.useForm();
  const [filter, setFilter] = useState({ isDefault: 'all', type: 'all' });

  const filtered = categories.filter(c =>
    (c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.keywords.toLowerCase().includes(search.toLowerCase())) &&
    (filter.isDefault === 'all' || (filter.isDefault === 'yes' ? c.isDefault : !c.isDefault)) &&
    (filter.type === 'all' || c.type === filter.type)
  );

  useEffect(() => {
    const timer = setTimeout(() => setLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const handleAdd = (values) => {
    const newCategory = {
      id: categories.length + 1,
      icon: 'category',
      ...values,
      isDefault: values.isDefault === 'yes',
    };
    setCategories([...categories, newCategory]);
    setShowAddModal(false);
    form.resetFields();
  };

  const handleEdit = (values) => {
    if (!editingCategory) return;
    setCategories(categories.map(c =>
      c.id === editingCategory.id ? { ...c, ...values, isDefault: values.isDefault === 'yes' } : c
    ));
    setShowEditModal(false);
    setEditingCategory(null);
  };

  const handleDelete = (id) => {
    setCategories(categories.filter(c => c.id !== id));
  };

  const openEditModal = (cat) => {
    setEditingCategory(cat);
    form.setFieldsValue({
      name: cat.name,
      keywords: cat.keywords,
      isDefault: cat.isDefault ? 'yes' : 'no',
      type: cat.type
    });
    setShowEditModal(true);
  };

  const startAdd = () => {
    form.resetFields();
    form.setFieldsValue({ isDefault: 'yes', type: 'expense' });
    setShowAddModal(true);
  };

  const syncCategories = () => {
    Modal.confirm({
      title: 'Đồng bộ danh mục',
      content: 'Bạn có chắc chắn muốn đồng bộ các danh mục mặc định?',
      onOk: () => {
        // sync logic
      }
    });
  };

  const columns = [
    {
      title: 'TÊN DANH MỤC',
      dataIndex: 'name',
      key: 'name',
      render: (text, record) => (
        <Space>
          <div style={{ width: 32, height: 32, borderRadius: '50%', backgroundColor: '#e5eeff', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#10b981' }}>
            <span className="material-symbols-outlined" style={{ fontSize: 18 }}>{record.icon}</span>
          </div>
          <Text strong>{text}</Text>
        </Space>
      ),
    },
    {
      title: 'KEYWORD NHẬN DIỆN',
      dataIndex: 'keywords',
      key: 'keywords',
      render: (text) => <Text type="secondary">{text}</Text>
    },
    {
      title: 'MẶC ĐỊNH',
      dataIndex: 'isDefault',
      key: 'isDefault',
      render: (isDefault) => <Text type="secondary">{isDefault ? 'Yes' : 'No'}</Text>
    },
    {
      title: 'LOẠI',
      dataIndex: 'type',
      key: 'type',
      render: (type) => (
        <Tag color={getTypeBadgeColor(type)} style={{ borderRadius: 9999, fontWeight: 600 }}>
          {TRANSACTION_TYPE_LABELS[type] || type}
        </Tag>
      )
    },
    {
      title: 'HÀNH ĐỘNG',
      key: 'action',
      align: 'right',
      render: (_, record) => (
        <Space size="middle">
          <Button type="text" icon={<EditOutlined />} onClick={() => openEditModal(record)} />
          <Popconfirm title="Bạn có chắc muốn xóa danh mục này?" onConfirm={() => handleDelete(record.id)}>
            <Button type="text" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <div>
      {/* Page Header */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginBottom: 24 }}>
        <Title level={3} style={{ margin: 0 }}>Quản lý danh mục mặc định</Title>
        <Space wrap>
          <Input
            placeholder="Tìm kiếm danh mục..."
            prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ width: 256, borderRadius: 6 }}
          />
          <Button icon={<FilterOutlined />} onClick={() => setShowFilterModal(true)}>
            Lọc
          </Button>
          <Button type="primary" icon={<PlusOutlined />} onClick={startAdd}>
            Thêm danh mục mới
          </Button>
        </Space>
      </div>

      <Card bordered={false} bodyStyle={{ padding: 0 }}>
        <Table
          columns={columns}
          dataSource={filtered}
          rowKey="id"
          loading={loading}
          pagination={{ pageSize: 10, showSizeChanger: false, showTotal: (total, range) => `Hiển thị ${range[0]} - ${range[1]} của ${total} danh mục` }}
        />
        <div style={{ padding: '16px 24px', borderTop: '1px solid #f0f0f0', display: 'flex', justifyContent: 'flex-end', backgroundColor: '#fafafa', borderRadius: '0 0 8px 8px' }}>
          <Button type="primary" icon={<SyncOutlined />} onClick={syncCategories}>
            Đồng bộ danh mục
          </Button>
        </div>
      </Card>

      {/* Add / Edit Modal */}
      <Modal
        title={editingCategory ? "Chỉnh sửa danh mục" : "Thêm danh mục mới"}
        open={showAddModal || showEditModal}
        onCancel={() => { setShowAddModal(false); setShowEditModal(false); setEditingCategory(null); }}
        onOk={() => form.submit()}
        okText="Lưu"
        cancelText="Hủy"
      >
        <Form form={form} layout="vertical" onFinish={editingCategory ? handleEdit : handleAdd} style={{ marginTop: 16 }}>
          <Form.Item name="name" label="Tên danh mục" rules={[{ required: true, message: 'Vui lòng nhập tên danh mục' }]}>
            <Input placeholder="Nhập tên danh mục" />
          </Form.Item>
          <Row gutter={16}>
            <Col span={12}>
              <Form.Item name="isDefault" label="Mặc định">
                <Select>
                  <Option value="yes">Yes</Option>
                  <Option value="no">No</Option>
                </Select>
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item name="type" label="Phân loại">
                <Select>
                  {Object.keys(TRANSACTION_TYPE_LABELS).map(key => (
                    <Option key={key} value={key}>{TRANSACTION_TYPE_LABELS[key]}</Option>
                  ))}
                </Select>
              </Form.Item>
            </Col>
          </Row>
          <Form.Item name="keywords" label="Keyword nhận diện danh mục">
            <Input.TextArea rows={3} placeholder="ăn uống, food, nhà hàng..." />
          </Form.Item>
        </Form>
      </Modal>

      {/* Filter Modal */}
      <Modal
        title="Lọc danh mục"
        open={showFilterModal}
        onCancel={() => setShowFilterModal(false)}
        onOk={() => setShowFilterModal(false)}
        okText="Áp dụng"
        cancelText="Đặt lại"
      >
        <Space direction="vertical" style={{ width: '100%', marginTop: 16 }}>
          <div>
            <Text strong style={{ display: 'block', marginBottom: 8 }}>Mặc định</Text>
            <Select style={{ width: '100%' }} value={filter.isDefault} onChange={(v) => setFilter({...filter, isDefault: v})}>
              <Option value="all">Tất cả</Option>
              <Option value="yes">Yes</Option>
              <Option value="no">No</Option>
            </Select>
          </div>
          <div>
            <Text strong style={{ display: 'block', marginBottom: 8 }}>Loại danh mục</Text>
            <Select style={{ width: '100%' }} value={filter.type} onChange={(v) => setFilter({...filter, type: v})}>
              <Option value="all">Tất cả</Option>
              {Object.keys(TRANSACTION_TYPE_LABELS).map(key => (
                <Option key={key} value={key}>{TRANSACTION_TYPE_LABELS[key]}</Option>
              ))}
            </Select>
          </div>
        </Space>
      </Modal>
    </div>
  );
};

export default CategoryPage;
