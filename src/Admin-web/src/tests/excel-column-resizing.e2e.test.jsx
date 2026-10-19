import React from 'react';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import useResizableColumns from '../hooks/useResizableColumns';
import ResizableTh from '../components/common/ResizableTh';
import TruncateCell from '../components/common/TruncateCell';

// Demo table component reproducing the exact pattern used across Admin-web pages
const ResizableTestTable = ({ tableKey = 'test_table_e2e' }) => {
  const DEFAULT_WIDTHS = {
    id: 80,
    name: 180,
    email: 220,
    action: 100,
  };

  const { widths, totalWidth, startResizing, resetColumn } = useResizableColumns({
    tableKey,
    defaultWidths: DEFAULT_WIDTHS,
    minWidth: 50,
  });

  const sampleData = [
    {
      id: 'USR-001',
      name: 'Nguyen Van A - Senior Software Engineer with very long name',
      email: 'nguyen.van.a.really.long.email.address.that.exceeds.column@example.com',
      action: 'Active',
    },
  ];

  return (
    <div className="overflow-x-auto">
      <table className="text-left border-collapse table-fixed" style={{ width: `${totalWidth}px` }}>
        <thead>
          <tr className="bg-gray-100">
            <ResizableTh colKey="id" width={widths.id} onResize={startResizing} onReset={resetColumn}>
              ID
            </ResizableTh>
            <ResizableTh colKey="name" width={widths.name} onResize={startResizing} onReset={resetColumn}>
              Tên người dùng
            </ResizableTh>
            <ResizableTh colKey="email" width={widths.email} onResize={startResizing} onReset={resetColumn}>
              Email
            </ResizableTh>
            <ResizableTh colKey="action" width={widths.action} resizable={false} align="right">
              Thao tác
            </ResizableTh>
          </tr>
        </thead>
        <tbody>
          {sampleData.map((row) => (
            <tr key={row.id}>
              <td className="overflow-hidden">
                <TruncateCell text={row.id} />
              </td>
              <td className="overflow-hidden">
                <TruncateCell text={row.name} className="font-semibold text-primary" />
              </td>
              <td className="overflow-hidden">
                <TruncateCell text={row.email} />
              </td>
              <td className="text-right overflow-hidden">
                <span>{row.action}</span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

describe('Excel Column Resizing & Truncation Suite (Rule 11: 2-Tier Testing)', () => {
  beforeEach(() => {
    localStorage.clear();
    vi.restoreAllMocks();
  });

  afterEach(() => {
    localStorage.clear();
  });

  /* =========================================================================
   * TẦNG 1: KIỂM THỬ HIỂN THỊ & THAO TÁC TẠI GIAO DIỆN (UI Rendering & Interaction)
   * ========================================================================= */
  describe('Tầng 1: UI Rendering, Resizer Handles & Ellipsis Tooltips', () => {
    it('1.1. Render đầy đủ các cột với kích thước khởi tạo và thanh kéo resizer handle', () => {
      render(<ResizableTestTable />);

      const idTh = screen.getByText('ID').closest('th');
      const nameTh = screen.getByText('Tên người dùng').closest('th');
      const emailTh = screen.getByText('Email').closest('th');
      const actionTh = screen.getByText('Thao tác').closest('th');

      expect(idTh).toHaveStyle({ width: '80px' });
      expect(nameTh).toHaveStyle({ width: '180px' });
      expect(emailTh).toHaveStyle({ width: '220px' });
      expect(actionTh).toHaveStyle({ width: '100px' });

      // Cột cho phép resize phải có separator handle
      const resizers = screen.getAllByRole('separator');
      expect(resizers).toHaveLength(3); // id, name, email (action resizable={false})
    });

    it('1.2. Mặc định text dài được truncate dấu ba chấm và có thuộc tính title tooltip hiển thị đầy đủ', () => {
      render(<ResizableTestTable />);

      const nameCell = screen.getByText('Nguyen Van A - Senior Software Engineer with very long name');
      expect(nameCell).toBeInTheDocument();
      expect(nameCell).toHaveClass('truncate');
      expect(nameCell).toHaveAttribute('title', 'Nguyen Van A - Senior Software Engineer with very long name');

      const emailCell = screen.getByText('nguyen.van.a.really.long.email.address.that.exceeds.column@example.com');
      expect(emailCell).toBeInTheDocument();
      expect(emailCell).toHaveClass('truncate');
      expect(emailCell).toHaveAttribute('title', 'nguyen.van.a.really.long.email.address.that.exceeds.column@example.com');
    });

    it('1.3. Double click vào thanh resizer handle gọi onReset khôi phục độ rộng mặc định', () => {
      // Đặt trước width khác trong localStorage
      localStorage.setItem('admin_tbl_widths_test_table_e2e', JSON.stringify({ name: 350 }));
      render(<ResizableTestTable />);

      const nameTh = screen.getByText('Tên người dùng').closest('th');
      expect(nameTh).toHaveStyle({ width: '350px' });

      const nameResizer = nameTh.querySelector('[role="separator"]');
      expect(nameResizer).toBeInTheDocument();

      // Double click
      fireEvent.doubleClick(nameResizer);

      // Trở lại mặc định 180px
      expect(nameTh).toHaveStyle({ width: '180px' });
    });
  });

  /* =========================================================================
   * TẦNG 2: KIỂM THỬ HOẠT ĐỘNG THỰC TẾ & TÁC ĐỘNG HỆ THỐNG (Real System Impact)
   * ========================================================================= */
  describe('Tầng 2: DOM Width Impact, LocalStorage Persistence & Boundary Enforcement', () => {
    it('2.1. Thao tác kéo chuột (mousedown -> mousemove -> mouseup) thay đổi độ rộng trực tiếp trên DOM', () => {
      render(<ResizableTestTable />);

      const nameTh = screen.getByText('Tên người dùng').closest('th');
      const nameResizer = nameTh.querySelector('[role="separator"]');

      // 1. Mousedown tại X = 100
      fireEvent.mouseDown(nameResizer, { clientX: 100 });

      // 2. Mousemove sang phải thêm 70px -> X = 170
      act(() => {
        fireEvent.mouseMove(window, { clientX: 170 });
      });

      // 3. Mouseup kết thúc kéo
      act(() => {
        fireEvent.mouseUp(window);
      });

      // Width cũ 180 + 70 = 250px
      expect(nameTh).toHaveStyle({ width: '250px' });
    });

    it('2.2. Tác động hệ thống: Kích thước tùy chỉnh được ghi đè và lưu thực tế vào LocalStorage', () => {
      render(<ResizableTestTable />);

      const emailTh = screen.getByText('Email').closest('th');
      const emailResizer = emailTh.querySelector('[role="separator"]');

      // Kéo dãn cột Email từ X = 200 sang X = 280 (+80px)
      fireEvent.mouseDown(emailResizer, { clientX: 200 });
      act(() => {
        fireEvent.mouseMove(window, { clientX: 280 });
      });
      act(() => {
        fireEvent.mouseUp(window);
      });

      // Kiểm tra LocalStorage
      const savedRaw = localStorage.getItem('admin_tbl_widths_test_table_e2e');
      expect(savedRaw).not.toBeNull();
      const savedData = JSON.parse(savedRaw);
      expect(savedData.email).toBe(300); // 220 + 80 = 300
    });

    it('2.3. Tác động hệ thống: Tải lại trang/component khôi phục chính xác kích thước từ LocalStorage', () => {
      // Giả lập người dùng đã tinh chỉnh các cột trong phiên làm việc trước
      const previousSessionWidths = {
        id: 110,
        name: 290,
        email: 340,
      };
      localStorage.setItem('admin_tbl_widths_test_table_e2e', JSON.stringify(previousSessionWidths));

      const { unmount } = render(<ResizableTestTable />);

      const idTh = screen.getByText('ID').closest('th');
      const nameTh = screen.getByText('Tên người dùng').closest('th');
      const emailTh = screen.getByText('Email').closest('th');

      // Khôi phục đúng từ LocalStorage thay vì lấy mặc định 80, 180, 220
      expect(idTh).toHaveStyle({ width: '110px' });
      expect(nameTh).toHaveStyle({ width: '290px' });
      expect(emailTh).toHaveStyle({ width: '340px' });

      unmount();
    });

    it('2.4. Chống lỗi co dãn quá mức: Giới hạn minWidth không cho cột bị thu nhỏ biến mất', () => {
      render(<ResizableTestTable />);

      const idTh = screen.getByText('ID').closest('th');
      const idResizer = idTh.querySelector('[role="separator"]');

      // ID hiện tại 80px, minWidth là 50px.
      // Kéo sang trái cực mạnh 200px (X = 300 -> X = 100: delta = -200px)
      fireEvent.mouseDown(idResizer, { clientX: 300 });
      act(() => {
        fireEvent.mouseMove(window, { clientX: 100 });
      });
      act(() => {
        fireEvent.mouseUp(window);
      });

      // Độ rộng không được tụt dưới 50px
      expect(idTh).toHaveStyle({ width: '50px' });
      const saved = JSON.parse(localStorage.getItem('admin_tbl_widths_test_table_e2e'));
      expect(saved.id).toBe(50);
    });

    it('2.5. BẤT BIẾN ĐỘC LẬP EXCEL (CRITICAL INVARIANT): Co dãn một cột TUYỆT ĐỐI KHÔNG làm thay đổi kích thước của các cột phía trước và các cột phía sau', () => {
      render(<ResizableTestTable />);

      const table = screen.getByRole('table');
      const idTh = screen.getByText('ID').closest('th');
      const nameTh = screen.getByText('Tên người dùng').closest('th');
      const emailTh = screen.getByText('Email').closest('th');
      const actionTh = screen.getByText('Thao tác').closest('th');

      // Ban đầu: id=80, name=180, email=220, action=100 -> table=580px
      expect(table).toHaveStyle({ width: '580px' });
      expect(idTh).toHaveStyle({ width: '80px', minWidth: '80px', maxWidth: '80px' });
      expect(nameTh).toHaveStyle({ width: '180px', minWidth: '180px', maxWidth: '180px' });
      expect(emailTh).toHaveStyle({ width: '220px', minWidth: '220px', maxWidth: '220px' });
      expect(actionTh).toHaveStyle({ width: '100px', minWidth: '100px', maxWidth: '100px' });

      // Kéo dãn cột Email (cột thứ 3) từ 220px tăng thêm +130px -> 350px
      const emailResizer = emailTh.querySelector('[role="separator"]');
      fireEvent.mouseDown(emailResizer, { clientX: 200 });
      act(() => {
        fireEvent.mouseMove(window, { clientX: 330 });
      });
      act(() => {
        fireEvent.mouseUp(window);
      });

      // BẢO CHỨNG:
      // 1. Cột Email thay đổi đúng 350px
      expect(emailTh).toHaveStyle({ width: '350px', minWidth: '350px', maxWidth: '350px' });
      // 2. CÁC CỘT PHÍA TRƯỚC (ID, Name) TUYỆT ĐỐI KHÔNG BỊ CO DÃN THEO (GIỮ NGUYÊN 100%)
      expect(idTh).toHaveStyle({ width: '80px', minWidth: '80px', maxWidth: '80px' });
      expect(nameTh).toHaveStyle({ width: '180px', minWidth: '180px', maxWidth: '180px' });
      // 3. Cột phía sau (Action) TUYỆT ĐỐI KHÔNG BỊ ẢNH HƯỞNG
      expect(actionTh).toHaveStyle({ width: '100px', minWidth: '100px', maxWidth: '100px' });
      // 4. Toàn bộ bảng mở rộng thêm đúng 130px (580 + 130 = 710px)
      expect(table).toHaveStyle({ width: '710px' });

      // Bây giờ thử thu nhỏ cột Tên người dùng (cột thứ 2) từ 180px xuống 120px (-60px)
      const nameResizer = nameTh.querySelector('[role="separator"]');
      fireEvent.mouseDown(nameResizer, { clientX: 300 });
      act(() => {
        fireEvent.mouseMove(window, { clientX: 240 });
      });
      act(() => {
        fireEvent.mouseUp(window);
      });

      // BẢO CHỨNG:
      // 1. Cột Tên người dùng thay đổi đúng 120px
      expect(nameTh).toHaveStyle({ width: '120px', minWidth: '120px', maxWidth: '120px' });
      // 2. Cột phía trước (ID) vẫn nguyên vẹn 80px
      expect(idTh).toHaveStyle({ width: '80px', minWidth: '80px', maxWidth: '80px' });
      // 3. Các cột phía sau (Email 350px, Action 100px) vẫn nguyên vẹn
      expect(emailTh).toHaveStyle({ width: '350px', minWidth: '350px', maxWidth: '350px' });
      expect(actionTh).toHaveStyle({ width: '100px', minWidth: '100px', maxWidth: '100px' });
      // 4. Bảng co lại đúng 60px (710 - 60 = 650px)
      expect(table).toHaveStyle({ width: '650px' });
    });
  });
});
