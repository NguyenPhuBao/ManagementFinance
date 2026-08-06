import React from 'react';
import { RouterProvider } from 'react-router-dom';
import { AuthProvider } from './store/auth.context';
import router from './router';

const App = () => {
  return (
    <AuthProvider>
      <RouterProvider router={router} />
    </AuthProvider>
  );
};

export default App;
