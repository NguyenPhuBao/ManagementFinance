import React from 'react';
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import TruncateCell from '../components/common/TruncateCell';

describe('2-Tier Test - TruncateCell Enterprise Text Overflow Component', () => {
  it('Tầng 1 (UI Rendering): TruncateCell hiển thị text và render các thuộc tính cơ bản', () => {
    const sampleText = 'Nguyen Van A';
    render(<TruncateCell text={sampleText} className="font-medium text-slate-800" />);

    const cell = screen.getByText(sampleText);
    expect(cell).toBeInTheDocument();
    expect(cell.tagName).toBe('DIV');
    expect(cell.className).toContain('font-medium');
    expect(cell.className).toContain('text-slate-800');
  });

  it('Tầng 2 (System Impact): TruncateCell kích hoạt class truncate và gán title tooltip đầy đủ cho văn bản dài', () => {
    const longEmail = 'nguyenvanb_dai_dien_phap_luat_doanh_nghiep_123456@finance.management.vn';
    render(<TruncateCell text={longEmail} />);

    const cell = screen.getByText(longEmail);
    expect(cell).toBeInTheDocument();
    // System Impact 1: Ellipsis CSS class 'truncate' is applied to prevent table column disruption
    expect(cell.className).toContain('truncate');
    expect(cell.className).toContain('overflow-hidden');
    // System Impact 2: Native HTML title tooltip is set with full string for admin accessibility
    expect(cell.getAttribute('title')).toBe(longEmail);
  });

  it('Tầng 2 (Edge Case): TruncateCell xử lý text rỗng hoặc falsy một cách an toàn mà không bị crash', () => {
    const { container } = render(<TruncateCell text="" />);
    const div = container.querySelector('div');
    expect(div).toBeInTheDocument();
    expect(div.getAttribute('title')).toBeNull();
  });
});
