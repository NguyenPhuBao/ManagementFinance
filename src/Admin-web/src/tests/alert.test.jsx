import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import { AlertProvider, useAlert } from '../store/alert.context';
import AlertContainer from '../components/common/AlertToast';

const Trigger = () => {
  const alert = useAlert();
  return (
    <>
      <button onClick={() => alert.success('Đã lưu cấu hình.')}>ok</button>
      <button onClick={() => alert.error('Không kết nối được.', 'Lỗi mạng')}>loi</button>
    </>
  );
};

const setup = () =>
  render(
    <AlertProvider>
      <Trigger />
      <AlertContainer />
    </AlertProvider>
  );

describe('AlertToast', () => {
  it('hiện thông báo thành công với tiêu đề mặc định và nội dung', () => {
    setup();
    fireEvent.click(screen.getByRole('button', { name: 'ok' }));
    const toast = screen.getByTestId('alert-toast-success');
    expect(toast).toHaveTextContent('Thành công');
    expect(toast).toHaveTextContent('Đã lưu cấu hình.');
  });

  it('thông báo lỗi dùng tiêu đề truyền vào; nút đóng có tên truy cập và gỡ thông báo', () => {
    setup();
    fireEvent.click(screen.getByRole('button', { name: 'loi' }));
    const toast = screen.getByTestId('alert-toast-error');
    expect(toast).toHaveTextContent('Lỗi mạng');
    fireEvent.click(screen.getByRole('button', { name: 'Đóng thông báo' }));
    expect(screen.queryByTestId('alert-toast-error')).not.toBeInTheDocument();
  });
});
