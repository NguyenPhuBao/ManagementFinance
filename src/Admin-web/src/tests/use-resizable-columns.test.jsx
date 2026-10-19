import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import useResizableColumns from '../hooks/useResizableColumns';

describe('Task 1: 2-Tier Test - useResizableColumns Hook', () => {
  const tableKey = 'test_table';
  const defaultWidths = { name: 200, email: 250, role: 120 };

  beforeEach(() => {
    localStorage.clear();
  });

  it('Tầng 1 (Rendering): Khởi tạo hook với độ rộng mặc định khi LocalStorage trống', () => {
    const { result } = renderHook(() => useResizableColumns({ tableKey, defaultWidths }));
    expect(result.current.widths).toEqual(defaultWidths);
    expect(result.current.totalWidth).toBe(570);
    expect(result.current.isResizing).toBe(false);
  });

  it('Tầng 2 (System Impact): Kéo thả chuột tăng 50px cập nhật state và lưu LocalStorage', () => {
    const { result } = renderHook(() => useResizableColumns({ tableKey, defaultWidths, minWidth: 60 }));

    act(() => {
      result.current.startResizing('name', 100, 200);
    });

    expect(result.current.isResizing).toBe(true);

    // Giả lập di chuyển chuột sang phải 50px (từ x=100 lên x=150)
    act(() => {
      window.dispatchEvent(new MouseEvent('mousemove', { clientX: 150 }));
    });

    expect(result.current.widths.name).toBe(250);

    // Thả chuột
    act(() => {
      window.dispatchEvent(new MouseEvent('mouseup'));
    });

    expect(result.current.isResizing).toBe(false);

    // Kiểm tra tác động LocalStorage
    const saved = JSON.parse(localStorage.getItem('admin_tbl_widths_test_table'));
    expect(saved.name).toBe(250);
  });

  it('Tầng 2 (Boundary Clamping): Không cho phép co dãn nhỏ hơn minWidth', () => {
    const { result } = renderHook(() => useResizableColumns({ tableKey, defaultWidths, minWidth: 60 }));

    act(() => {
      result.current.startResizing('role', 200, 120);
    });

    // Kéo lố sang trái 100px (120 - 100 = 20 < 60)
    act(() => {
      window.dispatchEvent(new MouseEvent('mousemove', { clientX: 100 }));
      window.dispatchEvent(new MouseEvent('mouseup'));
    });

    expect(result.current.widths.role).toBe(60);
  });

  it('Tầng 2 (Reset column & Reset all): Reset về mặc định ban đầu và xóa LocalStorage', () => {
    const { result } = renderHook(() => useResizableColumns({ tableKey, defaultWidths, minWidth: 60 }));

    act(() => {
      result.current.startResizing('email', 100, 250);
    });

    act(() => {
      window.dispatchEvent(new MouseEvent('mousemove', { clientX: 200 }));
      window.dispatchEvent(new MouseEvent('mouseup'));
    });

    expect(result.current.widths.email).toBe(350);

    // Reset 1 cột
    act(() => {
      result.current.resetColumn('email');
    });
    expect(result.current.widths.email).toBe(250);

    // Reset toàn bộ
    act(() => {
      result.current.resetWidths();
    });
    expect(result.current.widths).toEqual(defaultWidths);
    expect(localStorage.getItem('admin_tbl_widths_test_table')).toBeNull();
  });
});
