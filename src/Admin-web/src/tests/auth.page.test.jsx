import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import LoginPage from '../pages/auth/LoginPage';
import * as AuthContext from '../store/auth.context';

const mockedNavigate = vi.fn();
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual('react-router-dom');
  return {
    ...actual,
    useNavigate: () => mockedNavigate,
  };
});

describe('Admin-web Auth Suite — LoginPage', () => {
  const mockLogin = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(AuthContext, 'useAuthContext').mockReturnValue({
      login: mockLogin,
      user: null,
      isAuthenticated: false,
    });
  });

  it('1.1. Render đầy đủ form đăng nhập với email, password và nút đăng nhập', () => {
    render(
      <BrowserRouter>
        <LoginPage />
      </BrowserRouter>
    );

    expect(screen.getByText('Đăng nhập hệ thống')).toBeInTheDocument();
    expect(screen.getByLabelText(/Email hoặc Tên đăng nhập/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Mật khẩu/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Đăng nhập/i })).toBeInTheDocument();
  });

  it('1.2. Cho phép ẩn / hiện mật khẩu khi click icon visibility', () => {
    render(
      <BrowserRouter>
        <LoginPage />
      </BrowserRouter>
    );

    const passwordInput = screen.getByPlaceholderText('••••••••');
    expect(passwordInput).toHaveAttribute('type', 'password');

    // Nút toggle visibility
    const toggleBtn = screen.getByText('visibility_off').closest('button');
    fireEvent.click(toggleBtn);
    expect(passwordInput).toHaveAttribute('type', 'text');

    fireEvent.click(toggleBtn);
    expect(passwordInput).toHaveAttribute('type', 'password');
  });

  it('1.3. Đăng nhập thành công gọi login() với credentials và chuyển hướng tới /dashboard', async () => {
    mockLogin.mockResolvedValueOnce({ user: { id: 1, role: 'admin' } });

    render(
      <BrowserRouter>
        <LoginPage />
      </BrowserRouter>
    );

    fireEvent.change(screen.getByLabelText(/Email hoặc Tên đăng nhập/i), {
      target: { value: 'admin@finance.local' },
    });
    fireEvent.change(screen.getByPlaceholderText('••••••••'), {
      target: { value: 'AdminPassword123!' },
    });

    const submitBtn = screen.getByRole('button', { name: /Đăng nhập/i });
    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(mockLogin).toHaveBeenCalledWith({
        username: 'admin@finance.local',
        password: 'AdminPassword123!',
      });
      expect(mockedNavigate).toHaveBeenCalledWith('/dashboard');
    });
  });

  it('1.4. Hiển thị thông báo lỗi khi đăng nhập thất bại từ API', async () => {
    const errorResponse = {
      response: {
        data: { message: 'Tài khoản hoặc mật khẩu không chính xác' },
      },
    };
    mockLogin.mockRejectedValueOnce(errorResponse);

    render(
      <BrowserRouter>
        <LoginPage />
      </BrowserRouter>
    );

    fireEvent.change(screen.getByLabelText(/Email hoặc Tên đăng nhập/i), {
      target: { value: 'wrong_admin' },
    });
    fireEvent.change(screen.getByPlaceholderText('••••••••'), {
      target: { value: 'WrongPass' },
    });

    const submitBtn = screen.getByRole('button', { name: /Đăng nhập/i });
    fireEvent.click(submitBtn);

    await waitFor(() => {
      expect(screen.getByText('Tài khoản hoặc mật khẩu không chính xác')).toBeInTheDocument();
    });
  });
});
