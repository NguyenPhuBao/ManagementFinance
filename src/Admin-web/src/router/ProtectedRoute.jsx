import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuthContext } from '../store/auth.context';
import Loading from '../components/common/Loading';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated, loading } = useAuthContext();

  if (loading) {
    return <Loading text="Đang kiểm tra đăng nhập..." fullScreen />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return children;
};

export default ProtectedRoute;
