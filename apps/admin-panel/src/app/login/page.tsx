'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Form, Input, Button, Card, Typography, Alert, message } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { api } from '../../lib/api';

const { Title, Text } = Typography;

export default function LoginPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const onFinish = async (values: any) => {
    setLoading(true);
    setErrorMsg(null);
    try {
      const response = await api.post('/auth/admin/login', {
        email: values.email,
        password: values.password,
      });

      const { accessToken, user } = response.data;
      if (user.role !== 'ADMIN') {
        throw new Error('Access denied: account does not have administrator privileges');
      }

      localStorage.setItem('astro_admin_token', accessToken);
      localStorage.setItem('astro_admin_user', JSON.stringify(user));
      message.success('Welcome back, Administrator');
      router.push('/experts');
    } catch (err: any) {
      const msg = err.response?.data?.message || err.message || 'Invalid credentials';
      setErrorMsg(Array.isArray(msg) ? msg.join(', ') : msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        display: 'flex',
        minHeight: '100vh',
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#0C0E1E',
        padding: 24,
      }}
    >
      <Card
        style={{
          width: '100%',
          maxWidth: 440,
          backgroundColor: '#141733',
          border: '1px solid #2B3160',
          borderRadius: 20,
          boxShadow: '0 20px 40px rgba(0,0,0,0.4)',
        }}
      >
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div
            style={{
              width: 56,
              height: 56,
              borderRadius: '50%',
              backgroundColor: '#F5A623',
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: 16,
              boxShadow: '0 8px 24px rgba(245, 166, 35, 0.3)',
            }}
          >
            <span style={{ fontSize: 28, color: '#0C0E1E' }}>✦</span>
          </div>
          <Title level={3} style={{ color: '#F8F9FE', margin: 0 }}>
            Astro Admin Portal
          </Title>
          <Text style={{ color: '#9DA8D6', fontSize: 14 }}>
            Sign in to manage experts, approvals & platform operations
          </Text>
        </div>

        {errorMsg && (
          <Alert
            message={errorMsg}
            type="error"
            showIcon
            style={{ marginBottom: 20, backgroundColor: 'rgba(239, 68, 68, 0.1)', border: '1px solid #EF4444' }}
          />
        )}

        <Form
          name="admin_login"
          initialValues={{ email: 'admin@astro.com', password: 'admin123' }}
          onFinish={onFinish}
          layout="vertical"
          size="large"
        >
          <Form.Item
            name="email"
            rules={[
              { required: true, message: 'Please enter admin email' },
              { type: 'email', message: 'Please enter a valid email' },
            ]}
          >
            <Input
              prefix={<UserOutlined style={{ color: '#9DA8D6' }} />}
              placeholder="admin@astro.com"
              style={{ backgroundColor: '#0C0E1E' }}
            />
          </Form.Item>

          <Form.Item
            name="password"
            rules={[{ required: true, message: 'Please enter admin password' }]}
          >
            <Input.Password
              prefix={<LockOutlined style={{ color: '#9DA8D6' }} />}
              placeholder="••••••••"
              style={{ backgroundColor: '#0C0E1E' }}
            />
          </Form.Item>

          <Form.Item style={{ marginTop: 28 }}>
            <Button
              type="primary"
              htmlType="submit"
              loading={loading}
              block
              style={{
                height: 48,
                fontWeight: 700,
                fontSize: 16,
                backgroundColor: '#F5A623',
                color: '#0C0E1E',
              }}
            >
              Sign In to Admin Panel
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
}

