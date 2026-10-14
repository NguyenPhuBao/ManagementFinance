import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { STORAGE_KEYS } from '../utils/constants';
import authApi from '../api/auth.api';
import { useSettingsSafe } from './settings.context';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const settingsCtx = useSettingsSafe();

  // Initialize auth state from localStorage and softly verify session with backend
  useEffect(() => {
    let isMounted = true;

    const initAuth = async () => {
      const isLocked = localStorage.getItem(STORAGE_KEYS.IS_LOCKED) === 'true';
      if (isLocked) {
        // Đang ở trạng thái khóa an toàn: nạp user snapshot nếu có để phục vụ LockScreenModal
        const rawLockedUser = localStorage.getItem(STORAGE_KEYS.LOCKED_USER) || localStorage.getItem(STORAGE_KEYS.USER);
        if (rawLockedUser && isMounted) {
          try {
            setUser(JSON.parse(rawLockedUser));
          } catch (_) {}
        }
        if (isMounted) setLoading(false);
        return;
      }

      const token = localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN);
      const savedUser = localStorage.getItem(STORAGE_KEYS.USER);

      if (token && savedUser) {
        try {
          const parsedUser = JSON.parse(savedUser);
          if (isMounted) {
            setUser(parsedUser);
            setIsAuthenticated(true);
          }

          // Kiểm tra phiên làm việc ngầm với backend
          const meRes = await authApi.getMe();
          if (isMounted && meRes?.data) {
            const freshUser = { ...parsedUser, ...meRes.data };
            setUser(freshUser);
            localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(freshUser));
          }
        } catch (error) {
          // Nếu token không hợp lệ, hết hạn hoặc tài khoản đã bị khóa/xóa từ CSDL
          if (error.response?.status === 401 || error.response?.status === 403) {
            localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
            localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);
            localStorage.removeItem(STORAGE_KEYS.USER);
            if (isMounted) {
              setUser(null);
              setIsAuthenticated(false);
            }
          }
        }
      }

      if (isMounted) {
        setLoading(false);
      }
    };

    initAuth();

    return () => {
      isMounted = false;
    };
  }, []);

  const login = useCallback(async (credentials) => {
    const response = await authApi.login(credentials);
    const { accessToken, refreshToken, user: userData } = response.data;

    // Cho phép admin (idrole === 1 hoặc rolename: 'admin'/'Admin')
    const isAdmin = userData?.idrole === 1 || String(userData?.rolename || '').toLowerCase() === 'admin';
    if (!isAdmin) {
      throw new Error('Tài khoản không có quyền truy cập trang quản trị');
    }

    // 1. Dọn sạch 100% cờ khóa màn hình cũ khi đăng nhập mới thành công
    localStorage.removeItem(STORAGE_KEYS.IS_LOCKED);
    localStorage.removeItem(STORAGE_KEYS.LOCKED_AT);
    localStorage.removeItem(STORAGE_KEYS.LOCKED_USER);
    localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, String(Date.now()));
    if (settingsCtx?.resetLockState) {
      settingsCtx.resetLockState();
    }

    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, accessToken);
    localStorage.setItem(STORAGE_KEYS.REFRESH_TOKEN, refreshToken);
    localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify(userData));
    setUser(userData);
    setIsAuthenticated(true);
  }, [settingsCtx]);

  const logout = useCallback(async () => {
    try {
      await authApi.logout();
    } catch {
      // Vẫn xóa token local ngay cả khi API lỗi
    }
    // Dọn sạch token và trạng thái khóa khi đăng xuất
    localStorage.removeItem(STORAGE_KEYS.ACCESS_TOKEN);
    localStorage.removeItem(STORAGE_KEYS.REFRESH_TOKEN);
    localStorage.removeItem(STORAGE_KEYS.USER);
    localStorage.removeItem(STORAGE_KEYS.IS_LOCKED);
    localStorage.removeItem(STORAGE_KEYS.LOCKED_AT);
    localStorage.removeItem(STORAGE_KEYS.LOCKED_USER);
    localStorage.removeItem(STORAGE_KEYS.LAST_ACTIVE_AT);
    if (settingsCtx?.resetLockState) {
      settingsCtx.resetLockState();
    }
    setUser(null);
    setIsAuthenticated(false);
  }, [settingsCtx]);

  const value = {
    user,
    loading,
    isAuthenticated,
    login,
    logout,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuthContext = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuthContext must be used within AuthProvider');
  }
  return context;
};

export default AuthContext;
