import React from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import CategoryPage from '../pages/categories/CategoryPage';
import adminApi from '../api/admin.api';

vi.mock('../api/admin.api', () => ({
  default: {
    getCategories: vi.fn(),
    createCategory: vi.fn(),
    updateCategory: vi.fn(),
    deleteCategory: vi.fn(),
    restoreCategory: vi.fn(),
    verifySecurityAction: vi.fn(),
  },
}));

const DATA = [
  { id: 1, name: 'Ăn uống', classify: 'Chi', is_default: true, keyword: 'pho, com' },
  { id: 2, name: 'Lương', classify: 'Thu', is_default: true, keyword: 'luong' },
  { id: 3, name: 'Vay ngân hàng', classify: 'Vay/no', is_default: true, keyword: '' },
  { id: 4, name: 'Cà phê', classify: 'Chi', is_default: true, keyword: 'cafe, highlands', delete_at: '2026-10-01T00:00:00Z' },
  { id: 5, name: 'Bí mật', classify: 'Chi', is_default: false, is_user_category: true, keyword: 'abc' },
];

const row = (name) => screen.getByRole('row', { name: new RegExp(name) });
const queryRow = (name) => screen.queryByRole('row', { name: new RegExp(name) });

const renderPage = async () => {
  render(<CategoryPage />);
  await screen.findByRole('row', { name: /Ăn uống/ });
};

const openAdd = () => {
  fireEvent.click(screen.getByRole('button', { name: 'Thêm danh mục' }));
  return screen.getByRole('dialog', { name: 'Thêm danh mục' });
};

const syncWithPin = async (pin = '246810') => {
  fireEvent.click(screen.getByRole('button', { name: 'Lưu thay đổi' }));
  const dialog = screen.getByRole('dialog', { name: 'Lưu thay đổi danh mục' });
  fireEvent.change(within(dialog).getByLabelText(/PIN/), { target: { value: pin } });
  fireEvent.click(within(dialog).getByRole('button', { name: 'Lưu' }));
  return dialog;
};

beforeEach(() => {
  adminApi.getCategories.mockReset().mockResolvedValue({ data: DATA.map((c) => ({ ...c })) });
  ['createCategory', 'updateCategory', 'deleteCategory', 'restoreCategory', 'verifySecurityAction'].forEach((fn) =>
    adminApi[fn].mockReset().mockResolvedValue({ success: true })
  );
});

describe('Hiển thị và bảo vệ dữ liệu người dùng', () => {
  it('tải danh mục mặc định, có tiêu đề và 4 thẻ số liệu', async () => {
    await renderPage();
    expect(adminApi.getCategories).toHaveBeenCalledWith({ is_default: true });
    expect(screen.getByRole('heading', { level: 1, name: 'Quản lý danh mục' })).toBeInTheDocument();
    const card = (label) => screen.getByText(label, { selector: 'div' }).parentElement;
    expect(card('Tổng danh mục')).toHaveTextContent('5');
    expect(card('Chi tiêu')).toHaveTextContent('3');
    expect(card('Thu nhập')).toHaveTextContent('1');
    expect(card('Vay / Nợ')).toHaveTextContent('1');
  });

  it('danh mục riêng của người dùng bị ẩn tên, từ khóa và không có nút sửa/xóa', async () => {
    await renderPage();
    const userRow = screen.getAllByRole('row').find((r) => within(r).queryByText('Danh mục riêng của người dùng'));
    expect(userRow).toBeTruthy();
    expect(within(userRow).queryByText('Bí mật')).not.toBeInTheDocument();
    expect(within(userRow).queryByText('abc')).not.toBeInTheDocument();
    expect(within(userRow).queryByRole('button', { name: 'Sửa' })).not.toBeInTheDocument();
    expect(within(userRow).queryByRole('button', { name: 'Xóa' })).not.toBeInTheDocument();
  });
});

describe('Lọc và tìm kiếm', () => {
  it('tab loại lọc danh sách', async () => {
    await renderPage();
    fireEvent.click(within(screen.getByRole('tablist', { name: 'Lọc theo loại' })).getByRole('tab', { name: /Thu nhập/ }));
    expect(row('Lương')).toBeInTheDocument();
    expect(queryRow('Ăn uống')).not.toBeInTheDocument();
  });

  it('tìm không dấu vẫn ra tên có dấu', async () => {
    await renderPage();
    fireEvent.change(screen.getByLabelText('Tìm danh mục'), { target: { value: 'an uong' } });
    expect(row('Ăn uống')).toBeInTheDocument();
    expect(queryRow('Lương')).not.toBeInTheDocument();
  });

  it('bộ lọc gửi loại và từ khóa lên máy chủ', async () => {
    await renderPage();
    fireEvent.click(screen.getByRole('button', { name: 'Bộ lọc' }));
    const dialog = screen.getByRole('dialog', { name: 'Bộ lọc' });
    fireEvent.change(within(dialog).getByLabelText('Loại'), { target: { value: 'income' } });
    fireEvent.change(within(dialog).getByLabelText('Từ khóa'), { target: { value: ' luong ' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Áp dụng' }));
    await waitFor(() => expect(adminApi.getCategories).toHaveBeenLastCalledWith({ is_default: true, classify: 'Thu', keyword: 'luong' }));
  });
});

describe('Bản nháp', () => {
  it('thêm danh mục vào bản nháp, chưa gọi API; nút lưu báo số thay đổi', async () => {
    await renderPage();
    expect(screen.getByRole('button', { name: 'Lưu thay đổi' })).toBeDisabled();
    const dialog = openAdd();
    fireEvent.change(within(dialog).getByLabelText('Tên danh mục'), { target: { value: 'Mua sắm' } });
    fireEvent.change(within(dialog).getByLabelText('Từ khóa'), { target: { value: 'shopee, tiki' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Thêm vào bản nháp' }));
    expect(within(row('Mua sắm')).getByText('Mới')).toBeInTheDocument();
    expect(screen.getByText('1 thay đổi chưa lưu')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Lưu thay đổi' })).toBeEnabled();
    expect(adminApi.createCategory).not.toHaveBeenCalled();
  });

  it('chặn trùng tên với danh mục đang hoạt động cùng loại', async () => {
    await renderPage();
    const dialog = openAdd();
    fireEvent.change(within(dialog).getByLabelText('Tên danh mục'), { target: { value: '  ăn uống ' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Thêm vào bản nháp' }));
    expect(within(dialog).getByRole('alert')).toHaveTextContent('Ăn uống');
    expect(screen.queryByText('1 thay đổi chưa lưu')).not.toBeInTheDocument();
  });

  it('thêm lại tên đã xóa mềm với từ khóa trống thì kế thừa từ khóa cũ', async () => {
    await renderPage();
    const dialog = openAdd();
    fireEvent.change(within(dialog).getByLabelText('Tên danh mục'), { target: { value: 'Cà phê' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Thêm vào bản nháp' }));
    await syncWithPin();
    await waitFor(() =>
      expect(adminApi.createCategory).toHaveBeenCalledWith({ name: 'Cà phê', classify: 'Chi', is_default: true, keyword: 'cafe, highlands' })
    );
  });

  it('xóa qua hộp xác nhận rồi khôi phục được trong bản nháp', async () => {
    await renderPage();
    fireEvent.click(within(row('Lương')).getByRole('button', { name: 'Xóa' }));
    const dialog = screen.getByRole('dialog', { name: 'Xóa danh mục?' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Xóa' }));
    expect(within(row('Lương')).getByText('Đã xóa')).toBeInTheDocument();
    fireEvent.click(within(row('Lương')).getByRole('button', { name: 'Khôi phục' }));
    expect(within(row('Lương')).queryByText('Đã xóa')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Lưu thay đổi' })).toBeDisabled();
  });

  it('hủy thay đổi đưa danh sách về như lúc tải', async () => {
    await renderPage();
    const dialog = openAdd();
    fireEvent.change(within(dialog).getByLabelText('Tên danh mục'), { target: { value: 'Mua sắm' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Thêm vào bản nháp' }));
    fireEvent.click(screen.getByRole('button', { name: 'Hủy thay đổi' }));
    fireEvent.click(within(screen.getByRole('dialog', { name: 'Hủy các thay đổi chưa lưu?' })).getByRole('button', { name: 'Hủy thay đổi' }));
    expect(queryRow('Mua sắm')).not.toBeInTheDocument();
  });
});

describe('Lưu bằng PIN', () => {
  it('xác thực PIN rồi gửi đủ thêm / sửa / khôi phục / xóa, sau đó tải lại', async () => {
    await renderPage();
    const add = openAdd();
    fireEvent.change(within(add).getByLabelText('Tên danh mục'), { target: { value: 'Mua sắm' } });
    fireEvent.change(within(add).getByLabelText('Loại'), { target: { value: 'expense' } });
    fireEvent.click(within(add).getByRole('button', { name: 'Thêm vào bản nháp' }));

    fireEvent.click(within(row('Lương')).getByRole('button', { name: 'Sửa' }));
    const edit = screen.getByRole('dialog', { name: 'Sửa danh mục' });
    fireEvent.change(within(edit).getByLabelText('Từ khóa'), { target: { value: 'luong, thuong' } });
    fireEvent.click(within(edit).getByRole('button', { name: 'Cập nhật bản nháp' }));
    expect(within(row('Lương')).getByText('Đã sửa')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('tab', { name: /Tất cả/ }));
    fireEvent.click(within(row('Cà phê')).getByRole('button', { name: 'Khôi phục' }));

    fireEvent.click(within(row('Vay ngân hàng')).getByRole('button', { name: 'Xóa' }));
    fireEvent.click(within(screen.getByRole('dialog', { name: 'Xóa danh mục?' })).getByRole('button', { name: 'Xóa' }));

    expect(screen.getByText('4 thay đổi chưa lưu')).toBeInTheDocument();
    await syncWithPin('246810');

    await waitFor(() => expect(adminApi.deleteCategory).toHaveBeenCalledWith(3));
    expect(adminApi.verifySecurityAction).toHaveBeenCalledWith({ pin: '246810', password: '', action: 'SYNC_CATEGORIES', targetId: 'SYSTEM_CATEGORIES' });
    expect(adminApi.createCategory).toHaveBeenCalledWith({ name: 'Mua sắm', classify: 'Chi', is_default: true, keyword: null });
    expect(adminApi.updateCategory).toHaveBeenCalledWith(2, { name: 'Lương', classify: 'Thu', is_default: true, keyword: 'luong, thuong' });
    expect(adminApi.restoreCategory).toHaveBeenCalledWith(4);
    await waitFor(() => expect(adminApi.getCategories).toHaveBeenCalledTimes(2));
  });

  it('lưu thất bại: hiện lỗi trong hộp PIN và giữ nguyên bản nháp', async () => {
    adminApi.createCategory.mockRejectedValue({ response: { data: { message: 'Tên danh mục đã tồn tại' } } });
    await renderPage();
    const add = openAdd();
    fireEvent.change(within(add).getByLabelText('Tên danh mục'), { target: { value: 'Mua sắm' } });
    fireEvent.click(within(add).getByRole('button', { name: 'Thêm vào bản nháp' }));
    const dialog = await syncWithPin();
    expect(await within(dialog).findByRole('alert')).toHaveTextContent('Tên danh mục đã tồn tại');
    expect(screen.getByText('1 thay đổi chưa lưu')).toBeInTheDocument();
  });
});
