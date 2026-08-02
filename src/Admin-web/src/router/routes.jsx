import LoginPage from '../pages/auth/LoginPage';
import ForgotPasswordPage from '../pages/auth/ForgotPasswordPage';
import DashboardPage from '../pages/dashboard/DashboardPage';
import CategoryPage from '../pages/categories/CategoryPage';
import UserListPage from '../pages/users/UserListPage';
import UserDetailPage from '../pages/users/UserDetailPage';

const routes = [
  // Public routes
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
  // Protected routes (wrapped in AppLayout)
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
    path: '/users/:id',
    element: <UserDetailPage />,
  },
];

export default routes;
