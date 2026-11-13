import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import {
  Button,
  PageHeader,
  StatCard,
  Tabs,
  SearchInput,
  Card,
  Badge,
  DataTable,
  Pagination,
  Modal,
  ConfirmModal,
  SecurityConfirmModal,
  Spinner,
  EmptyState,
  Loading,
  PasswordInput,
} from '../components/ui';
import adminApi from '../api/admin.api';

vi.mock('../api/admin.api', () => ({
  default: { verifySecurityAction: vi.fn() },
}));

describe('Button', () => {
  it('gọi onClick khi bấm', () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Lưu</Button>);
    fireEvent.click(screen.getByRole('button', { name: 'Lưu' }));
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it('loading thì khóa nút và không gọi onClick', () => {
    const onClick = vi.fn();
    render(<Button loading onClick={onClick}>Lưu</Button>);
    const btn = screen.getByRole('button', { name: /Lưu/ });
    expect(btn).toBeDisabled();
    fireEvent.click(btn);
    expect(onClick).not.toHaveBeenCalled();
  });

  it('nút chỉ có biểu tượng dùng aria-label làm tên', () => {
    render(<Button icon="close" aria-label="Đóng" />);
    expect(screen.getByRole('button', { name: 'Đóng' })).toBeInTheDocument();
  });

  it('mặc định type="button" để không submit form ngoài ý muốn', () => {
    render(<Button>Mở</Button>);
    expect(screen.getByRole('button', { name: 'Mở' })).toHaveAttribute('type', 'button');
  });
});

describe('PageHeader, StatCard, Card, Badge', () => {
  it('PageHeader hiện h1, mô tả và vùng hành động', () => {
    render(<PageHeader title="Quản lý người dùng" description="Mô tả ngắn" actions={<button>Làm mới</button>} />);
    expect(screen.getByRole('heading', { level: 1, name: 'Quản lý người dùng' })).toBeInTheDocument();
    expect(screen.getByText('Mô tả ngắn')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Làm mới' })).toBeInTheDocument();
  });

  it('StatCard hiện nhãn, giá trị, dòng phụ', () => {
    render(<StatCard label="Tổng người dùng" value="1.248" hint="+3%" />);
    expect(screen.getByText('Tổng người dùng')).toBeInTheDocument();
    expect(screen.getByText('1.248')).toBeInTheDocument();
    expect(screen.getByText('+3%')).toBeInTheDocument();
  });

  it('Card có tiêu đề khối dạng h2', () => {
    render(<Card title="Hoạt động gần đây">nội dung</Card>);
    expect(screen.getByRole('heading', { level: 2, name: 'Hoạt động gần đây' })).toBeInTheDocument();
    expect(screen.getByText('nội dung')).toBeInTheDocument();
  });

  it('Badge mang tông màu', () => {
    render(<Badge tone="warning">Chờ xóa</Badge>);
    expect(screen.getByText('Chờ xóa')).toHaveAttribute('data-tone', 'warning');
  });
});

describe('Tabs', () => {
  const items = [
    { key: 'all', label: 'Tất cả' },
    { key: 'active', label: 'Hoạt động' },
  ];

  it('có tablist và đúng một tab được chọn', () => {
    render(<Tabs items={items} value="active" onChange={() => {}} ariaLabel="Trạng thái" />);
    expect(screen.getByRole('tablist', { name: 'Trạng thái' })).toBeInTheDocument();
    const selected = screen.getAllByRole('tab').filter((tab) => tab.getAttribute('aria-selected') === 'true');
    expect(selected).toHaveLength(1);
    expect(selected[0]).toHaveTextContent('Hoạt động');
  });

  it('bấm tab gọi onChange với khóa của tab', () => {
    const onChange = vi.fn();
    render(<Tabs items={items} value="active" onChange={onChange} ariaLabel="Trạng thái" />);
    fireEvent.click(screen.getByRole('tab', { name: 'Tất cả' }));
    expect(onChange).toHaveBeenCalledWith('all');
  });
});

describe('SearchInput', () => {
  it('có nhãn truy cập và trả giá trị khi gõ', () => {
    const onChange = vi.fn();
    render(<SearchInput label="Tìm người dùng" value="" onChange={onChange} />);
    fireEvent.change(screen.getByLabelText('Tìm người dùng'), { target: { value: 'an' } });
    expect(onChange).toHaveBeenCalledWith('an');
  });
});

describe('DataTable', () => {
  const columns = [
    { key: 'name', title: 'Họ tên' },
    { key: 'status', title: 'Trạng thái', render: (row) => <Badge tone="success">{row.status}</Badge> },
  ];

  it('hiện tiêu đề cột và hàng dữ liệu', () => {
    render(<DataTable columns={columns} rows={[{ id: 1, name: 'An', status: 'Hoạt động' }]} rowKey="id" />);
    expect(screen.getByRole('columnheader', { name: 'Họ tên' })).toBeInTheDocument();
    expect(screen.getByRole('cell', { name: 'An' })).toBeInTheDocument();
    expect(screen.getByText('Hoạt động')).toHaveAttribute('data-tone', 'success');
  });

  it('rỗng thì hiện EmptyState', () => {
    render(<DataTable columns={columns} rows={[]} rowKey="id" emptyTitle="Chưa có người dùng" />);
    expect(screen.getByText('Chưa có người dùng')).toBeInTheDocument();
  });

  it('đang tải thì hiện trạng thái tải, không hiện EmptyState', () => {
    render(<DataTable columns={columns} rows={[]} rowKey="id" loading emptyTitle="Chưa có người dùng" />);
    expect(screen.getByRole('status')).toBeInTheDocument();
    expect(screen.queryByText('Chưa có người dùng')).not.toBeInTheDocument();
  });
});

describe('Pagination', () => {
  it('bấm số trang gọi onPageChange(n)', () => {
    const onPageChange = vi.fn();
    render(<Pagination currentPage={1} pageSize={10} total={35} onPageChange={onPageChange} />);
    fireEvent.click(screen.getByRole('button', { name: '2' }));
    expect(onPageChange).toHaveBeenCalledWith(2);
  });

  it('trang hiện tại có aria-current, nút trước bị khóa ở trang 1', () => {
    render(<Pagination currentPage={1} pageSize={10} total={35} onPageChange={() => {}} />);
    expect(screen.getByRole('button', { name: '1' })).toHaveAttribute('aria-current', 'page');
    expect(screen.getByRole('button', { name: /trước/i })).toBeDisabled();
  });

  it('đổi số dòng gọi onPageSizeChange', () => {
    const onPageSizeChange = vi.fn();
    render(<Pagination currentPage={1} pageSize={10} total={35} onPageChange={() => {}} onPageSizeChange={onPageSizeChange} />);
    fireEvent.change(screen.getByRole('combobox'), { target: { value: '20' } });
    expect(onPageSizeChange).toHaveBeenCalledWith(20);
  });
});

describe('Modal', () => {
  it('đóng thì không hiện gì', () => {
    render(<Modal open={false} title="Bộ lọc" onClose={() => {}}>x</Modal>);
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  it('mở thì có dialog mang tên tiêu đề; Esc và nút đóng gọi onClose', () => {
    const onClose = vi.fn();
    render(<Modal open title="Bộ lọc" onClose={onClose}>nội dung</Modal>);
    expect(screen.getByRole('dialog', { name: 'Bộ lọc' })).toBeInTheDocument();
    fireEvent.keyDown(window, { key: 'Escape' });
    fireEvent.click(screen.getByRole('button', { name: 'Đóng' }));
    expect(onClose).toHaveBeenCalledTimes(2);
  });

  it('hideClose ẩn nút đóng; closeDisabled thì Esc và bấm nền không gọi onClose', () => {
    const onClose = vi.fn();
    const { container } = render(<Modal open hideClose closeDisabled title="Khóa" onClose={onClose}>nội dung</Modal>);
    expect(screen.queryByRole('button', { name: 'Đóng' })).not.toBeInTheDocument();
    fireEvent.keyDown(window, { key: 'Escape' });
    fireEvent.click(container.firstChild);
    expect(onClose).not.toHaveBeenCalled();
  });

  it('backdrop="solid" dùng nền đặc che hẳn nội dung phía sau', () => {
    const { container, rerender } = render(<Modal open title="Khóa" onClose={() => {}}>x</Modal>);
    expect(container.firstChild).toHaveClass('bg-overlay');
    rerender(<Modal open backdrop="solid" title="Khóa" onClose={() => {}}>x</Modal>);
    expect(container.firstChild).toHaveClass('bg-canvas');
    expect(container.firstChild).not.toHaveClass('bg-overlay');
  });
});

describe('PasswordInput', () => {
  it('nút mắt đổi kiểu ô nhập và nhãn truy cập; chuyển tiếp thuộc tính', () => {
    const onChange = vi.fn();
    render(<PasswordInput id="pw" value="abc" onChange={onChange} data-testid="pw-input" />);
    const input = screen.getByTestId('pw-input');
    expect(input).toHaveAttribute('type', 'password');
    fireEvent.click(screen.getByRole('button', { name: 'Hiện mật khẩu' }));
    expect(input).toHaveAttribute('type', 'text');
    fireEvent.click(screen.getByRole('button', { name: 'Ẩn mật khẩu' }));
    expect(input).toHaveAttribute('type', 'password');
    fireEvent.change(input, { target: { value: 'abcd' } });
    expect(onChange).toHaveBeenCalledTimes(1);
  });
});

describe('ConfirmModal', () => {
  it('xác nhận gọi onConfirm đúng một lần, hủy gọi onCancel', () => {
    const onConfirm = vi.fn();
    const onCancel = vi.fn();
    render(<ConfirmModal open title="Xóa sự cố" message="Không hoàn tác được." confirmText="Xóa" confirmDanger onConfirm={onConfirm} onCancel={onCancel} />);
    fireEvent.click(screen.getByRole('button', { name: 'Xóa' }));
    fireEvent.click(screen.getByRole('button', { name: 'Hủy bỏ' }));
    expect(onConfirm).toHaveBeenCalledTimes(1);
    expect(onCancel).toHaveBeenCalledTimes(1);
  });

  it('loading thì khóa cả hai nút', () => {
    render(<ConfirmModal open title="Xóa" confirmText="Xóa" loading onConfirm={() => {}} onCancel={() => {}} />);
    screen.getAllByRole('button').filter((b) => b.textContent).forEach((b) => expect(b).toBeDisabled());
  });
});

describe('SecurityConfirmModal', () => {
  beforeEach(() => {
    adminApi.verifySecurityAction.mockReset();
  });

  const setup = (props = {}) => {
    const onConfirm = vi.fn();
    const onClose = vi.fn();
    render(
      <SecurityConfirmModal
        isOpen
        title="Vô hiệu hóa người dùng"
        confirmText="Vô hiệu hóa"
        actionType="USER_INACTIVATE"
        targetLabel="user-42"
        onConfirm={onConfirm}
        onClose={onClose}
        {...props}
      />
    );
    return { onConfirm, onClose };
  };

  it('onVerify: gửi PIN thẳng cho hàm của nơi gọi thay vì verifySecurityAction; lỗi thì giữ hộp và hiện lỗi', async () => {
    const onVerify = vi.fn().mockRejectedValueOnce({ response: { data: { message: 'Mã PIN sai' } } }).mockResolvedValueOnce();
    const { onClose } = setup({ onVerify, onConfirm: undefined });
    fireEvent.change(screen.getByLabelText(/PIN/), { target: { value: '111111' } });
    fireEvent.click(screen.getByRole('button', { name: 'Vô hiệu hóa' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Mã PIN sai');
    expect(onClose).not.toHaveBeenCalled();
    fireEvent.change(screen.getByLabelText(/PIN/), { target: { value: '246810' } });
    fireEvent.click(screen.getByRole('button', { name: 'Vô hiệu hóa' }));
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
    expect(onVerify).toHaveBeenLastCalledWith({ pin: '246810', password: '' });
    expect(adminApi.verifySecurityAction).not.toHaveBeenCalled();
  });

  it('chưa đủ 6 số PIN thì nút xác nhận bị khóa', () => {
    setup();
    fireEvent.change(screen.getByLabelText(/PIN/), { target: { value: '123' } });
    expect(screen.getByRole('button', { name: 'Vô hiệu hóa' })).toBeDisabled();
  });

  it('PIN đúng: gọi verifySecurityAction với PIN, hành động, đối tượng rồi mới gọi onConfirm và đóng', async () => {
    adminApi.verifySecurityAction.mockResolvedValue({ success: true });
    const { onConfirm, onClose } = setup();
    fireEvent.change(screen.getByLabelText(/PIN/), { target: { value: '123456' } });
    fireEvent.click(screen.getByRole('button', { name: 'Vô hiệu hóa' }));
    await waitFor(() => expect(onConfirm).toHaveBeenCalledTimes(1));
    expect(adminApi.verifySecurityAction).toHaveBeenCalledWith({
      pin: '123456',
      password: '',
      action: 'USER_INACTIVATE',
      targetId: 'user-42',
    });
    expect(onClose).toHaveBeenCalled();
  });

  it('PIN sai: hiện lỗi, không gọi onConfirm, không đóng', async () => {
    adminApi.verifySecurityAction.mockRejectedValue({ response: { data: { message: 'Mã PIN không đúng' } } });
    const { onConfirm, onClose } = setup();
    fireEvent.change(screen.getByLabelText(/PIN/), { target: { value: '000000' } });
    fireEvent.click(screen.getByRole('button', { name: 'Vô hiệu hóa' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Mã PIN không đúng');
    expect(onConfirm).not.toHaveBeenCalled();
    expect(onClose).not.toHaveBeenCalled();
  });

  it('chuyển sang mật khẩu thì gửi mật khẩu thay PIN', async () => {
    adminApi.verifySecurityAction.mockResolvedValue({ success: true });
    const { onConfirm } = setup();
    fireEvent.click(screen.getByRole('button', { name: /mật khẩu/i }));
    fireEvent.change(screen.getByLabelText(/Mật khẩu/), { target: { value: 'Secret#1' } });
    fireEvent.click(screen.getByRole('button', { name: 'Vô hiệu hóa' }));
    await waitFor(() => expect(onConfirm).toHaveBeenCalled());
    expect(adminApi.verifySecurityAction).toHaveBeenCalledWith(expect.objectContaining({ pin: '', password: 'Secret#1' }));
  });
});

describe('Spinner, EmptyState, Loading', () => {
  it('Spinner có role status', () => {
    render(<Spinner label="Đang tải" />);
    expect(screen.getByRole('status', { name: 'Đang tải' })).toBeInTheDocument();
  });

  it('EmptyState hiện tiêu đề và hành động', () => {
    render(<EmptyState title="Trống" description="Chưa có gì" action={<button>Thêm</button>} />);
    expect(screen.getByText('Trống')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Thêm' })).toBeInTheDocument();
  });

  it('Loading toàn màn hình hiện chữ', () => {
    render(<Loading text="Đang kiểm tra đăng nhập..." fullScreen />);
    expect(screen.getByText('Đang kiểm tra đăng nhập...')).toBeInTheDocument();
  });
});
