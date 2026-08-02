import React from 'react';

const Loading = ({ text = 'Đang tải dữ liệu...', fullScreen = false, overlay = false }) => {
  const spinner = (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 16,
      padding: fullScreen ? 0 : 40,
      height: fullScreen ? '100vh' : 'auto',
      width: fullScreen ? '100vw' : '100%',
      position: fullScreen ? 'fixed' : 'relative',
      top: fullScreen ? 0 : 'auto',
      left: fullScreen ? 0 : 'auto',
      zIndex: fullScreen ? 100 : 1,
      backgroundColor: overlay ? 'rgba(248, 249, 255, 0.6)' : 'transparent',
      backdropFilter: overlay ? 'blur(2px)' : 'none',
    }}>
      <div style={{
        width: 48,
        height: 48,
        border: '4px solid #10b981',
        borderTopColor: 'transparent',
        borderRadius: '50%',
        animation: 'spin 1s linear infinite',
      }} />
      {text && (
        <p style={{
          fontSize: 12,
          fontWeight: 600,
          color: '#006c49',
          textTransform: 'uppercase',
          letterSpacing: '0.1em',
        }}>
          {text}
        </p>
      )}
    </div>
  );

  return spinner;
};

export default Loading;
