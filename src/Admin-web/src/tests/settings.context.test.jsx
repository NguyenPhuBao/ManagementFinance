import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, act } from '@testing-library/react';
import { SettingsProvider, useSettings } from '../store/settings.context';

const TestComponent = () => {
  const { settings, updateSetting, resetSettings, isLocked, lockScreen, safeClearCache } = useSettings();
  return (
    <div>
      <div data-testid="theme">{settings.theme}</div>
      <div data-testid="density">{settings.tableDensity}</div>
      <div data-testid="locked">{isLocked ? 'locked' : 'unlocked'}</div>
      <button onClick={() => updateSetting('theme', 'dark')}>Set Dark</button>
      <button onClick={() => updateSetting('tableDensity', 'compact')}>Set Compact</button>
      <button onClick={resetSettings}>Reset</button>
      <button onClick={lockScreen}>Lock Now</button>
      <button onClick={safeClearCache}>Safe Clear</button>
    </div>
  );
};

describe('Settings Context & Store Suite', () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.className = '';
    document.body.removeAttribute('data-density');
  });

  it('1. Khởi tạo mặc định chuẩn và lưu cài đặt vào LocalStorage', () => {
    render(
      <SettingsProvider>
        <TestComponent />
      </SettingsProvider>
    );

    expect(screen.getByTestId('theme').textContent).toBe('light');
    expect(screen.getByTestId('density').textContent).toBe('comfortable');
    expect(screen.getByTestId('locked').textContent).toBe('unlocked');
  });

  it('2. Cập nhật theme và áp dụng class .dark lên document.documentElement', () => {
    render(
      <SettingsProvider>
        <TestComponent />
      </SettingsProvider>
    );

    act(() => {
      screen.getByText('Set Dark').click();
    });

    expect(screen.getByTestId('theme').textContent).toBe('dark');
    expect(document.documentElement.classList.contains('dark')).toBe(true);
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
  });

  it('3. Cập nhật tableDensity và áp dụng data-density lên document.body', () => {
    render(
      <SettingsProvider>
        <TestComponent />
      </SettingsProvider>
    );

    act(() => {
      screen.getByText('Set Compact').click();
    });

    expect(screen.getByTestId('density').textContent).toBe('compact');
    expect(document.body.getAttribute('data-density')).toBe('compact');
  });

  it('4. Khóa an toàn màn hình khi gọi lockScreen', () => {
    render(
      <SettingsProvider>
        <TestComponent />
      </SettingsProvider>
    );

    act(() => {
      screen.getByText('Lock Now').click();
    });

    expect(screen.getByTestId('locked').textContent).toBe('locked');
  });

  it('5. Safe Clear Cache bảo toàn 100% token đăng nhập', () => {
    localStorage.setItem('access_token', 'jwt-token-123');
    localStorage.setItem('user', JSON.stringify({ id: 1, name: 'Admin' }));
    localStorage.setItem('temp_filter_users', 'search-hcm');

    render(
      <SettingsProvider>
        <TestComponent />
      </SettingsProvider>
    );

    act(() => {
      screen.getByText('Safe Clear').click();
    });

    // Token và user vẫn còn
    expect(localStorage.getItem('access_token')).toBe('jwt-token-123');
    expect(localStorage.getItem('user')).toBeTruthy();
    // Cache rác bị xóa
    expect(localStorage.getItem('temp_filter_users')).toBeNull();
  });
});
