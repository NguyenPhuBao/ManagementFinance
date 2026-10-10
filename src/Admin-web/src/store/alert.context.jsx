import React, { createContext, useContext, useState, useCallback, useRef } from 'react';
import { useSettingsSafe } from './settings.context';
import soundService from '../services/sound.service';

const AlertContext = createContext(null);

export const AlertProvider = ({ children }) => {
  const [alerts, setAlerts] = useState([]);
  const timersRef = useRef({});
  const settingsCtx = useSettingsSafe();
  const settingsRef = useRef(settingsCtx?.settings);
  settingsRef.current = settingsCtx?.settings;

  // Xóa 1 alert theo ID
  const removeAlert = useCallback((id) => {
    if (timersRef.current[id]) {
      clearTimeout(timersRef.current[id]);
      delete timersRef.current[id];
    }
    setAlerts((prev) => prev.filter((alert) => alert.id !== id));
  }, []);

  // Thêm mới một Alert
  const showAlert = useCallback(({ type = 'info', title = '', message = '', duration }) => {
    const defaultDuration = settingsRef.current?.toastDuration !== undefined ? settingsRef.current.toastDuration : 4500;
    const finalDuration = duration !== undefined ? duration : defaultDuration;

    // Phát âm thanh nếu soundEnabled được bật
    if (settingsRef.current?.soundEnabled) {
      if (type === 'error') soundService.playCriticalAlarm();
      else if (type === 'info' || type === 'success') soundService.playNotificationSound();
    }

    const id = `alert-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
    const newAlert = {
      id,
      type, // 'success' | 'error' | 'warning' | 'info'
      title,
      message,
      duration: finalDuration,
      createdAt: Date.now(),
    };

    setAlerts((prev) => [newAlert, ...prev.slice(0, 4)]); // Tối đa 5 alerts xếp chồng

    if (finalDuration > 0) {
      timersRef.current[id] = setTimeout(() => {
        removeAlert(id);
      }, finalDuration);
    }

    return id;
  }, [removeAlert]);

  // Các hàm tiện ích gọi nhanh - kế thừa hoàn toàn toastDuration người dùng cài đặt
  const success = useCallback((message, title, duration) => {
    return showAlert({ type: 'success', title, message, duration });
  }, [showAlert]);

  const error = useCallback((message, title, duration) => {
    return showAlert({ type: 'error', title, message, duration });
  }, [showAlert]);

  const warning = useCallback((message, title, duration) => {
    return showAlert({ type: 'warning', title, message, duration });
  }, [showAlert]);

  const info = useCallback((message, title, duration) => {
    return showAlert({ type: 'info', title, message, duration });
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
