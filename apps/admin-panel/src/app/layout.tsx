'use client';

import React from 'react';
import { AntdRegistry } from '@ant-design/nextjs-registry';
import { ConfigProvider, theme } from 'antd';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body style={{ margin: 0, padding: 0, backgroundColor: '#0C0E1E', color: '#F8F9FE', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
        <AntdRegistry>
          <ConfigProvider
            theme={{
              algorithm: theme.darkAlgorithm,
              token: {
                colorPrimary: '#F5A623',
                colorBgBase: '#0C0E1E',
                colorBgContainer: '#141733',
                colorBgElevated: '#1D2147',
                colorBorder: '#2B3160',
                colorText: '#F8F9FE',
                colorTextSecondary: '#9DA8D6',
                borderRadius: 12,
              },
            }}
          >
            {children}
          </ConfigProvider>
        </AntdRegistry>
      </body>
    </html>
  );
}
