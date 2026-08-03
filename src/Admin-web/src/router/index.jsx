import React from 'react';
import { createBrowserRouter, Navigate } from 'react-router-dom';
import AppLayout from '../components/layout/AppLayout';
import ProtectedRoute from './ProtectedRoute';
import routes from './routes.jsx';

// Separate public and protected routes
const publicRoutes = routes.filter(r => r.public);
const protectedRoutes = routes.filter(r => !r.public);

const router = createBrowserRouter([
  // Public routes
  ...publicRoutes.map(r => ({
    path: r.path,
    element: r.element,
  })),
  // Protected routes wrapped in AppLayout
  {
    path: '/',
    element: (
      <ProtectedRoute>
        <AppLayout />
      </ProtectedRoute>
    ),
    children: [
      ...protectedRoutes.map(r => ({
        path: r.path.replace('/', ''),
        element: r.element,
      })),
      // Redirect root to dashboard
      {
        index: true,
        element: <Navigate to="/dashboard" replace />,
      },
    ],
  },
  // Catch-all redirect
  {
    path: '*',
    element: <Navigate to="/dashboard" replace />,
  },
]);

export default router;
