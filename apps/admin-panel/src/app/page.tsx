'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Spin } from 'antd';

export default function HomePage() {
  const router = useRouter();

  useEffect(() => {
    const token = localStorage.getItem('astro_admin_token');
    if (token) {
      router.replace('/experts');
    } else {
      router.replace('/login');
    }
  }, [router]);

  return (
    <div style={{ display: 'flex', height: '100vh', justifyContent: 'center', alignItems: 'center' }}>
      <Spin size="large" />
    </div>
  );
}

