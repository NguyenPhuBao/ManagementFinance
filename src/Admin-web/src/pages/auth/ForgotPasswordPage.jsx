import React from 'react';
import { Link } from 'react-router-dom';

const ForgotPasswordPage = () => {
  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundColor: 'var(--color-background)',
      padding: 16,
    }}>
      <div style={{ width: '100%', maxWidth: 448, backgroundColor: '#ffffff', borderRadius: 'var(--radius-xl)', border: '1px solid var(--color-outline-variant)', padding: '40px 32px', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)' }}>
        {/* Brand Header */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: 32 }}>
          <div style={{ width: 48, height: 48, backgroundColor: 'var(--color-primary-container)', borderRadius: 6, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 16 }}>
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M8 14v3m4-3v3m4-3v3M3 21h18M3 10h18M3 7l9-4 9 4M4 10h16v11H4V10z" />
            </svg>
          </div>
          <h1 style={{ fontSize: 24, fontWeight: 700, color: '#111827', letterSpacing: '-0.01em' }}>WealthCommand</h1>
          <p style={{ fontSize: 14, color: '#6b7280', marginTop: 4 }}>Hệ thống Quản trị Viên</p>
        </div>

        {/* Content */}
        <div style={{ textAlign: 'center' }}>
          <h2 style={{ fontSize: 20, fontWeight: 600, color: '#1f2937', marginBottom: 24 }}>Quên mật khẩu?</h2>

          {/* Warning */}
          <div style={{ backgroundColor: '#fffbeb', borderLeft: '4px solid #fbbf24', padding: 16, textAlign: 'left', marginBottom: 24 }}>
            <div style={{ display: 'flex', gap: 12 }}>
              <svg width="20" height="20" viewBox="0 0 20 20" fill="#fbbf24">
                <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
              </svg>
              <p style={{ fontSize: 14, fontWeight: 500, color: '#92400e' }}>
                Vì lý do bảo mật, tài khoản Admin không thể tự đặt lại mật khẩu.
              </p>
            </div>
          </div>

          <p style={{ fontSize: 14, color: '#4b5563', marginBottom: 24 }}>
            Vui lòng liên hệ Hotline hỗ trợ kỹ thuật để được cấp lại mật khẩu mới:
          </p>

          {/* Hotline */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, padding: 16, backgroundColor: '#f9fafb', borderRadius: 8, border: '1px solid var(--color-outline-variant)', marginBottom: 32 }}>
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--color-primary)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
            </svg>
            <a href="tel:+84355281276" style={{ fontSize: 24, fontWeight: 700, color: '#111827', textDecoration: 'none' }}>
              +84 355 281 276
            </a>
          </div>
        </div>

        {/* Footer */}
        <div style={{ paddingTop: 24, borderTop: '1px solid var(--color-outline-variant)', textAlign: 'center' }}>
          <Link to="/login" style={{ display: 'inline-flex', alignItems: 'center', gap: 8, fontSize: 14, fontWeight: 600, color: 'var(--color-primary)', textDecoration: 'none' }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Quay lại Đăng nhập
          </Link>
        </div>
      </div>
    </div>
  );
};

export default ForgotPasswordPage;
