import LoginPage from '../pages/auth/LoginPage';
import ForgotPasswordPage from '../pages/auth/ForgotPasswordPage';
import DashboardPage from '../pages/dashboard/DashboardPage';
import CategoryPage from '../pages/categories/CategoryPage';
import UserListPage from '../pages/users/UserListPage';
import AuditLogPage from '../pages/system/AuditLogPage';
import BroadcastPage from '../pages/system/BroadcastPage';
import AIOpsPage from '../pages/system/AIOpsPage';
import PermissionManagementPage from '../pages/system/PermissionManagementPage';
import PaymentHistoryPage from '../pages/payments/PaymentHistoryPage';
import PaymentResultPage from '../pages/payment/PaymentResultPage';
import { Navigate } from 'react-router-dom';
import { isAiopsEnabled } from '../config/features';

// AIOps tạm dừng (2026-11-17): công tắc tắt thì /aiops chuyển về Dashboard.
const AIOpsRoute = () => (isAiopsEnabled() ? <AIOpsPage /> : <Navigate to="/dashboard" replace />);

const routes = [
  {
    path: '/login',
    element: <LoginPage />,
    public: true,
  },
  {
    path: '/forgot-password',
    element: <ForgotPasswordPage />,
    public: true,
  },
  {
    path: '/payment/success',
    element: <PaymentResultPage outcome="success" />,
    public: true,
  },
  {
    path: '/payment/cancel',
    element: <PaymentResultPage outcome="cancel" />,
    public: true,
  },
  {
    path: '/dashboard',
    element: <DashboardPage />,
  },
  {
    path: '/categories',
    element: <CategoryPage />,
  },
  {
    path: '/users',
    element: <UserListPage />,
  },
  {
    path: '/permissions',
    element: <PermissionManagementPage />,
  },
  {
    path: '/payments',
    element: <PaymentHistoryPage />,
  },
  {
    path: '/audit-logs',
    element: <AuditLogPage />,
  },
  {
    path: '/broadcast',
    element: <BroadcastPage />,
  },
  {
    path: '/aiops',
    element: <AIOpsRoute />,
  },
];

export default routes;
