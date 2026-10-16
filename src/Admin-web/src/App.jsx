import React from 'react';
import { RouterProvider } from 'react-router-dom';
import { LanguageProvider } from './store/language.context';
import { AuthProvider } from './store/auth.context';
import { SocketProvider } from './store/socket.context';
import { SettingsProvider } from './store/settings.context';
import { AlertProvider } from './store/alert.context';
import AlertContainer from './components/common/AlertToast';
import router from './router';

const App = () => {
  return (
    <LanguageProvider>
      <SettingsProvider>
        <AuthProvider>
          <SocketProvider>
            <AlertProvider>
              <AlertContainer />
              <RouterProvider router={router} />
            </AlertProvider>
          </SocketProvider>
        </AuthProvider>
      </SettingsProvider>
    </LanguageProvider>
  );
};

export default App;

