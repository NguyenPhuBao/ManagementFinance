import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import ResizableTh from '../components/common/ResizableTh';
import TruncateCell from '../components/common/TruncateCell';

describe('Task 2: 2-Tier Test - ResizableTh and TruncateCell Components', () => {
  it('Tầng 1 (UI Rendering): ResizableTh render thẻ th với độ rộng style, cursor-col-resize và vạch phân cách', () => {
    const handleResize = vi.fn();
    render(
      <table>
        <thead>
          <tr>
            <ResizableTh colKey="name" width={220} minWidth={80} onResize={handleResize}>
              Họ và tên
            </ResizableTh>
          </tr>
        </thead>
      </table>
    );

    const th = screen.getByText('Họ và tên').closest('th');
    expect(th).toBeInTheDocument();
    expect(th.style.width).toBe('220px');
    expect(th.style.minWidth).toBe('220px');
    expect(th.style.maxWidth).toBe('220px');

    const handle = screen.getByTestId('resize-handle-name');
    expect(handle).toBeInTheDocument();
    expect(handle.className).toContain('cursor-col-resize');
  });

  it('Tầng 2 (System Impact): ResizableTh kích hoạt onResize khi mousedown và onReset khi double-click', () => {
    const handleResize = vi.fn();
    const handleReset = vi.fn();

    render(
      <table>
        <thead>
          <tr>
            <ResizableTh
              colKey="email"
              width={250}
              onResize={handleResize}
              onReset={handleReset}
            >
              Email
            </ResizableTh>
          </tr>
        </thead>
      </table>
    );

    const handle = screen.getByTestId('resize-handle-email');
    fireEvent.mouseDown(handle, { clientX: 180 });
    expect(handleResize).toHaveBeenCalledWith('email', 180, 250);

    fireEvent.doubleClick(handle);
    expect(handleReset).toHaveBeenCalledWith('email');
  });

  it('Tầng 1 & Tầng 2: TruncateCell tự động gán class truncate và thuộc tính title hiển thị tooltip đầy đủ', () => {
    const longText = 'nguyenvanb_dai_dien_phap_luat_doanh_nghiep_123456@finance.management.vn';
    render(<TruncateCell text={longText} />);

    const cell = screen.getByText(longText);
    expect(cell).toBeInTheDocument();
    expect(cell.className).toContain('truncate');
    expect(cell.getAttribute('title')).toBe(longText);
  });
});
