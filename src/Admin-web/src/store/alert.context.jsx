import React, { createContext, useContext, useState, useCallback, useRef } from 'react';

const AlertContext = createContext(null);

export const AlertProvider = ({ children }) => {
  const [alerts, setAlerts] = useState([]);
  const timersRef = useRef({});

  // Xóa 1 alert theo ID
  const removeAlert = useCallback((id) => {
    if (timersRef.current[id]) {
      clearTimeout(timersRef.current[id]);
      delete timersRef.current[id];
    }
    setAlerts((prev) => prev.filter((alert) => alert.id !== id));
  }, []);

  // Thêm mới một Alert
  const showAlert = useCallback(({ type = 'info', title = '', message = '', duration = 4500 }) => {
    const id = `alert-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
    const newAlert = {
      id,
      type, // 'success' | 'error' | 'warning' | 'info'
      title,
      message,
      duration,
      createdAt: Date.now(),
    };

    setAlerts((prev) => [newAlert, ...prev.slice(0, 4)]); // Tối đa 5 alerts xếp chồng

    if (duration > 0) {
      timersRef.current[id] = setTimeout(() => {
        removeAlert(id);
      }, duration);
    }

    return id;
  }, [removeAlert]);

  // Các hàm tiện ích gọi nhanh
  const success = useCallback((message, title = 'Thành công') => {
    return showAlert({ type: 'success', title, message });
  }, [showAlert]);

  const error = useCallback((message, title = 'Lỗi / Thất bại') => {
    return showAlert({ type: 'error', title, message, duration: 6000 });
  }, [showAlert]);

  const warning = useCallback((message, title = 'Cảnh báo') => {
    return showAlert({ type: 'warning', title, message, duration: 5500 });
  }, [showAlert]);

  const info = useCallback((message, title = 'Thông báo') => {
    return showAlert({ type: 'info', title, message });
  }, [showAlert]);

  const clearAllAlerts = useCallback(() => {
    Object.values(timersRef.current).forEach(clearTimeout);
    timersRef.current = {};
    setAlerts([]);
  }, []);

  const value = {
    alerts,
    showAlert,
    removeAlert,
    clearAllAlerts,
    success,
    error,
    warning,
    info,
  };

  return (
    <AlertContext.Provider value={value}>
      {children}
    </AlertContext.Provider>
  );
};

export const useAlert = () => {
  const context = useContext(AlertContext);
  if (!context) {
    throw new Error('useAlert must be used within an AlertProvider');
  }
  return context;
};

export const useAlertSafe = () => {
  return useContext(AlertContext) || null;
};

export default AlertContext;
