import React from 'react';
import { RouterProvider } from 'react-router-dom';
import { AuthProvider } from './store/auth.context';
import { AlertProvider } from './store/alert.context';
import AlertContainer from './components/common/AlertToast';
import router from './router';

const App = () => {
  return (
    <AuthProvider>
      <AlertProvider>
        <AlertContainer />
        <RouterProvider router={router} />
      </AlertProvider>
    </AuthProvider>
  );
};

export default App;
