import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuthContext } from '../store/auth.context';
import { useSettingsSafe } from '../store/settings.context';
import { STORAGE_KEYS } from '../utils/constants';
import Loading from '../components/common/Loading';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated, loading } = useAuthContext();
  const settingsCtx = useSettingsSafe();

  if (loading) {
    return <Loading text="Đang kiểm tra đăng nhập..." fullScreen />;
  }

  const isLocked = settingsCtx?.isLocked || (typeof localStorage !== 'undefined' && localStorage.getItem(STORAGE_KEYS.IS_LOCKED) === 'true');
  const hasLockedUser = typeof localStorage !== 'undefined' && Boolean(localStorage.getItem(STORAGE_KEYS.LOCKED_USER) || localStorage.getItem(STORAGE_KEYS.USER));

  // Nếu màn hình đang bị khóa an toàn (Session Locked), cho phép render AppLayout kèm LockScreenModal
  if (isLocked && hasLockedUser) {
    return children;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return children;
};

export default ProtectedRoute;
