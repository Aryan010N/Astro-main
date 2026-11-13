'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  Table,
  Button,
  Tag,
  Space,
  Card,
  Typography,
  Modal,
  Input,
  message,
  Tabs,
  Row,
  Col,
  Statistic,
  Descriptions,
} from 'antd';
import {
  CheckCircleOutlined,
  CloseCircleOutlined,
  EyeOutlined,
  LogoutOutlined,
  UsergroupAddOutlined,
  SafetyCertificateOutlined,
  ClockCircleOutlined,
} from '@ant-design/icons';
import { api } from '../../lib/api';

const { Title, Text } = Typography;
const { TextArea } = Input;

export default function ExpertsAdminPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [pendingExperts, setPendingExperts] = useState<any[]>([]);
  const [allExperts, setAllExperts] = useState<any[]>([]);
  const [selectedExpert, setSelectedExpert] = useState<any | null>(null);
  const [detailsModalOpen, setDetailsModalOpen] = useState(false);
  const [rejectModalOpen, setRejectModalOpen] = useState(false);
  const [rejectReason, setRejectReason] = useState('');
  const [actionLoading, setActionLoading] = useState(false);

  const fetchExperts = async () => {
    setLoading(true);
    try {
      const [pendingRes, allRes] = await Promise.all([
        api.get('/admin/experts/pending'),
        api.get('/admin/experts'),
      ]);
      setPendingExperts(pendingRes.data);
      setAllExperts(allRes.data);
    } catch (err: any) {
      message.error(err.response?.data?.message || 'Failed to fetch expert records');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const token = localStorage.getItem('astro_admin_token');
    if (!token) {
      router.replace('/login');
      return;
    }
    fetchExperts();
  }, [router]);

  const handleLogout = () => {
    localStorage.removeItem('astro_admin_token');
    localStorage.removeItem('astro_admin_user');
    router.push('/login');
  };

  const handleApprove = async (id: string, name: string) => {
    setActionLoading(true);
    try {
      await api.post(`/admin/experts/${id}/approve`);
      message.success(`Expert "${name}" has been approved and is now live!`);
      fetchExperts();
    } catch (err: any) {
      message.error(err.response?.data?.message || 'Failed to approve expert');
    } finally {
      setActionLoading(false);
    }
  };

  const handleReject = async () => {
    if (!selectedExpert) return;
    setActionLoading(true);
    try {
      await api.post(`/admin/experts/${selectedExpert.id}/reject`, {
        rejectionReason: rejectReason,
      });
      message.warning(`Expert "${selectedExpert.name}" application rejected`);
      setRejectModalOpen(false);
      setRejectReason('');
      fetchExperts();
    } catch (err: any) {
      message.error(err.response?.data?.message || 'Failed to reject expert');
    } finally {
      setActionLoading(false);
    }
  };

  const formatPaiseToRupees = (paise: string | number) => {
    const num = typeof paise === 'string' ? parseInt(paise, 10) : paise;
    return `₹${(num / 100).toFixed(0)}/min`;
  };

  const columns = [
    {
      title: 'Expert Name',
      key: 'name',
      render: (_: any, record: any) => (
        <div>
          <Text strong style={{ color: '#F8F9FE', fontSize: 15 }}>
            {record.name}
          </Text>
          <br />
          <Text type="secondary" style={{ fontSize: 12 }}>
            {record.user?.phoneNumber || 'No phone'} • {record.experienceYears} yrs exp
          </Text>
        </div>
      ),
    },
    {
      title: 'Languages',
      dataIndex: 'languages',
      key: 'languages',
      render: (languages: string[]) => (
        <>
          {languages?.map((lang) => (
            <Tag color="geekblue" key={lang}>
              {lang}
            </Tag>
          ))}
        </>
      ),
    },
    {
      title: 'Expertise',
      dataIndex: 'expertise',
      key: 'expertise',
      render: (expertise: string[]) => (
        <>
          {expertise?.map((tag) => (
            <Tag color="gold" key={tag}>
              {tag}
            </Tag>
          ))}
        </>
      ),
    },
    {
      title: 'Consultation Rates',
      key: 'rates',
      render: (_: any, record: any) => (
        <Space direction="vertical" size={2}>
          <Text style={{ fontSize: 12 }}>Chat: {formatPaiseToRupees(record.chatRateInPaise)}</Text>
          <Text style={{ fontSize: 12 }}>Call: {formatPaiseToRupees(record.callRateInPaise)}</Text>
          <Text style={{ fontSize: 12 }}>Video: {formatPaiseToRupees(record.videoRateInPaise)}</Text>
        </Space>
      ),
    },
    {
      title: 'Status',
      dataIndex: 'kycStatus',
      key: 'kycStatus',
      render: (status: string) => {
        let color = 'gold';
        if (status === 'APPROVED') color = 'green';
        if (status === 'REJECTED') color = 'red';
        return <Tag color={color}>{status}</Tag>;
      },
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_: any, record: any) => (
        <Space direction="horizontal" size="small">
          <Button
            size="small"
            icon={<EyeOutlined />}
            onClick={() => {
              setSelectedExpert(record);
              setDetailsModalOpen(true);
            }}
          >
            Review KYC
          </Button>

          {record.kycStatus === 'PENDING' && (
            <>
              <Button
                type="primary"
                size="small"
                style={{ backgroundColor: '#10B981', borderColor: '#10B981' }}
                icon={<CheckCircleOutlined />}
                loading={actionLoading}
                onClick={() => handleApprove(record.id, record.name)}
              >
                Approve
              </Button>

              <Button
                danger
                size="small"
                icon={<CloseCircleOutlined />}
                onClick={() => {
                  setSelectedExpert(record);
                  setRejectModalOpen(true);
                }}
              >
                Reject
              </Button>
            </>
          )}
        </Space>
      ),
    },
  ];

  const approvedCount = allExperts.filter((e) => e.kycStatus === 'APPROVED').length;

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#0C0E1E' }}>
      {/* Top Header */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '16px 32px',
          backgroundColor: '#141733',
          borderBottom: '1px solid #2B3160',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 24, color: '#F5A623' }}>✦</span>
          <Title level={4} style={{ color: '#F8F9FE', margin: 0 }}>
            Astro Platform Admin
          </Title>
        </div>

        <Button icon={<LogoutOutlined />} onClick={handleLogout} style={{ color: '#EF4444' }}>
          Sign Out
        </Button>
      </div>

      <div style={{ padding: '32px' }}>
        {/* Metric Cards */}
        <Row gutter={24} style={{ marginBottom: 32 }}>
          <Col span={8}>
            <Card style={{ backgroundColor: '#141733', border: '1px solid #2B3160' }}>
              <Statistic
                title={<span style={{ color: '#9DA8D6' }}>Pending KYC Reviews</span>}
                value={pendingExperts.length}
                valueStyle={{ color: '#F5A623', fontWeight: 'bold' }}
                prefix={<ClockCircleOutlined />}
              />
            </Card>
          </Col>
          <Col span={8}>
            <Card style={{ backgroundColor: '#141733', border: '1px solid #2B3160' }}>
              <Statistic
                title={<span style={{ color: '#9DA8D6' }}>Approved Live Astrologers</span>}
                value={approvedCount}
                valueStyle={{ color: '#10B981', fontWeight: 'bold' }}
                prefix={<SafetyCertificateOutlined />}
              />
            </Card>
          </Col>
          <Col span={8}>
            <Card style={{ backgroundColor: '#141733', border: '1px solid #2B3160' }}>
              <Statistic
                title={<span style={{ color: '#9DA8D6' }}>Total Registered Applicants</span>}
                value={allExperts.length}
                valueStyle={{ color: '#F8F9FE', fontWeight: 'bold' }}
                prefix={<UsergroupAddOutlined />}
              />
            </Card>
          </Col>
        </Row>

        {/* Tabbed Table Container */}
        <Card style={{ backgroundColor: '#141733', border: '1px solid #2B3160' }}>
          <Tabs
            defaultActiveKey="pending"
            items={[
              {
                key: 'pending',
                label: `Pending Reviews (${pendingExperts.length})`,
                children: (
                  <Table
                    columns={columns}
                    dataSource={pendingExperts}
                    rowKey="id"
                    loading={loading}
                    pagination={{ pageSize: 8 }}
                  />
                ),
              },
              {
                key: 'all',
                label: `All Astrologers (${allExperts.length})`,
                children: (
                  <Table
                    columns={columns}
                    dataSource={allExperts}
                    rowKey="id"
                    loading={loading}
                    pagination={{ pageSize: 8 }}
                  />
                ),
              },
            ]}
          />
        </Card>
      </div>

      {/* KYC Details Modal */}
      <Modal
        title={
          <span style={{ color: '#F8F9FE', fontSize: 18 }}>
            KYC Verification Dossier: {selectedExpert?.name}
          </span>
        }
        open={detailsModalOpen}
        onCancel={() => setDetailsModalOpen(false)}
        footer={[
          <Button key="close" onClick={() => setDetailsModalOpen(false)}>
            Close
          </Button>,
          selectedExpert?.kycStatus === 'PENDING' && (
            <Button
              key="approve"
              type="primary"
              style={{ backgroundColor: '#10B981', borderColor: '#10B981' }}
              onClick={() => {
                handleApprove(selectedExpert.id, selectedExpert.name);
                setDetailsModalOpen(false);
              }}
            >
              Approve Astrologer
            </Button>
          ),
        ]}
        width={680}
      >
        {selectedExpert && (
          <Descriptions column={2} bordered size="small" style={{ marginTop: 16 }}>
            <Descriptions.Item label="Full Name">{selectedExpert.name}</Descriptions.Item>
            <Descriptions.Item label="Phone">{selectedExpert.user?.phoneNumber}</Descriptions.Item>
            <Descriptions.Item label="Email">{selectedExpert.email || '—'}</Descriptions.Item>
            <Descriptions.Item label="Experience">{selectedExpert.experienceYears} Years</Descriptions.Item>
            <Descriptions.Item label="ID Document Type">{selectedExpert.idProofType}</Descriptions.Item>
            <Descriptions.Item label="ID Number">{selectedExpert.idProofNumber}</Descriptions.Item>
            <Descriptions.Item label="Payout UPI ID" span={2}>
              <Text copyable strong style={{ color: '#F5A623' }}>
                {selectedExpert.payoutUpiId}
              </Text>
            </Descriptions.Item>
            <Descriptions.Item label="Languages" span={2}>
              {selectedExpert.languages?.join(', ')}
            </Descriptions.Item>
            <Descriptions.Item label="Expertise Tags" span={2}>
              {selectedExpert.expertise?.join(', ')}
            </Descriptions.Item>
            <Descriptions.Item label="Bio / Intro" span={2}>
              {selectedExpert.bio || 'No bio provided'}
            </Descriptions.Item>
            <Descriptions.Item label="Chat Rate">
              {formatPaiseToRupees(selectedExpert.chatRateInPaise)}
            </Descriptions.Item>
            <Descriptions.Item label="Call Rate">
              {formatPaiseToRupees(selectedExpert.callRateInPaise)}
            </Descriptions.Item>
            <Descriptions.Item label="Video Rate" span={2}>
              {formatPaiseToRupees(selectedExpert.videoRateInPaise)}
            </Descriptions.Item>
            <Descriptions.Item label="Current KYC Status" span={2}>
              <Tag color={selectedExpert.kycStatus === 'APPROVED' ? 'green' : 'gold'}>
                {selectedExpert.kycStatus}
              </Tag>
              {selectedExpert.rejectionReason && (
                <Text type="danger" style={{ marginLeft: 8 }}>
                  Reason: {selectedExpert.rejectionReason}
                </Text>
              )}
            </Descriptions.Item>
          </Descriptions>
        )}
      </Modal>

      {/* Reject Modal */}
      <Modal
        title="Reject Expert KYC Application"
        open={rejectModalOpen}
        onCancel={() => setRejectModalOpen(false)}
        onOk={handleReject}
        okText="Confirm Rejection"
        okButtonProps={{ danger: true, loading: actionLoading }}
      >
        <Text type="secondary" style={{ display: 'block', marginBottom: 12 }}>
          Please specify the reason for rejection. This feedback will be sent to the expert applicant.
        </Text>
        <TextArea
          rows={4}
          value={rejectReason}
          onChange={(e) => setRejectReason(e.target.value)}
          placeholder="e.g. Identity document image is unreadable, please re-submit clear photo ID."
        />
      </Modal>
    </div>
  );
}
