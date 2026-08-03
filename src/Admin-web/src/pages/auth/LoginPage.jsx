import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { Card, Form, Input, Button, Checkbox, Typography, Alert } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { useAuthContext } from '../../store/auth.context';

const { Title, Text } = Typography;

const LoginPage = () => {
  const navigate = useNavigate();
  const { login } = useAuthContext();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const onFinish = async (values) => {
    setError('');
    setLoading(true);
    try {
      await login({ username: values.email, password: values.password });
      navigate('/dashboard');
    } catch (err) {
      const msg = err.response?.data?.message || err.message || 'Đăng nhập thất bại';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundColor: '#f8f9ff',
      padding: '24px',
    }}>
      <div style={{ width: '100%', maxWidth: 420 }}>
        <Card
          bordered={false}
          style={{
            boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)',
            borderRadius: 8
          }}
        >
          {/* Header */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 32 }}>
            <div style={{
              width: 48,
              height: 48,
              backgroundColor: '#10b981', // primary-container
              color: '#ffffff',
              borderRadius: 8,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: 16,
            }}>
              <span className="material-symbols-outlined" style={{ fontSize: 28 }}>account_balance</span>
            </div>
            <Title level={3} style={{ margin: '0 0 8px 0', color: '#0b1c30' }}>
              Welcome Admin
            </Title>
            <Text type="secondary">Chào mừng quay trở lại</Text>
          </div>

          {/* Error message */}
          {error && (
            <Alert
              message={error}
              type="error"
              showIcon
              style={{ marginBottom: 24 }}
            />
          )}

          {/* Form */}
          <Form
            name="login"
            initialValues={{ rememberMe: false }}
            onFinish={onFinish}
            layout="vertical"
            size="large"
          >
            <Form.Item
              name="email"
              label="Email / Username"
              rules={[{ required: true, message: 'Vui lòng nhập Email / Username!' }]}
            >
              <Input
                prefix={<UserOutlined style={{ color: '#94a3b8' }} />}
                placeholder="admin@wealthcommand.com"
              />
            </Form.Item>

            <Form.Item
              name="password"
              label="Password"
              rules={[{ required: true, message: 'Vui lòng nhập Password!' }]}
            >
              <Input.Password
                prefix={<LockOutlined style={{ color: '#94a3b8' }} />}
                placeholder="••••••••"
              />
            </Form.Item>

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
              <Form.Item name="rememberMe" valuePropName="checked" noStyle>
                <Checkbox>Ghi nhớ đăng nhập</Checkbox>
              </Form.Item>
              <Link to="/forgot-password" style={{ color: '#10b981', fontWeight: 600 }}>
                Quên mật khẩu?
              </Link>
            </div>

            <Form.Item style={{ marginBottom: 0 }}>
              <Button type="primary" htmlType="submit" block loading={loading}>
                Đăng nhập
              </Button>
            </Form.Item>
          </Form>
        </Card>

        {/* Footer */}
        <div style={{ marginTop: 32, textAlign: 'center' }}>
          <Text type="secondary">© 2024 WealthCommand. All rights reserved.</Text>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
