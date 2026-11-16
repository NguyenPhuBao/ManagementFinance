import React from 'react';
import { render, screen } from '@testing-library/react';
import { formatNumber, formatPercent, formatCurrency, useNumberFormat } from '../utils/format';
import { LanguageProvider } from '../store/language.context';
import { STORAGE_KEY } from '../locales';

describe('Định dạng số theo ngôn ngữ (1.4)', () => {
  it('số nguyên và số thập phân: vi dùng dấu chấm nghìn, phẩy thập phân; en ngược lại', () => {
    expect(formatNumber(1234.5, { maxFrac: 1 }, 'vi')).toBe('1.234,5');
    expect(formatNumber(1234.5, { maxFrac: 1 }, 'en')).toBe('1,234.5');
    expect(formatNumber(0.15, {}, 'vi')).toBe('0,15');
    expect(formatNumber(0.15, {}, 'en')).toBe('0.15');
    expect(formatNumber(1000, {}, 'vi')).toBe('1.000');
  });

  it('cố định số chữ số thập phân', () => {
    expect(formatNumber(2, { minFrac: 1, maxFrac: 1 }, 'vi')).toBe('2,0');
    expect(formatPercent(99.954, 2, 'vi')).toBe('99,95%');
    expect(formatPercent(99.954, 2, 'en')).toBe('99.95%');
  });

  it('giá trị rỗng / không phải số coi là 0, không ra NaN', () => {
    expect(formatNumber(null, {}, 'vi')).toBe('0');
    expect(formatNumber('abc', {}, 'en')).toBe('0');
  });

  it('tiền VND: vi "49.000 ₫", en "₫49,000"', () => {
    expect(formatCurrency(49000, 'VND', 'vi')).toBe('49.000 ₫');
    expect(formatCurrency(49000, 'VND', 'en')).toBe('₫49,000');
  });

  it('hook useNumberFormat theo ngôn ngữ đang chọn', () => {
    const Probe = () => {
      const f = useNumberFormat();
      return <span>{`${f.number(1234.5, { maxFrac: 1 })}|${f.currency(2000)}|${f.percent(50, 0)}`}</span>;
    };
    localStorage.setItem(STORAGE_KEY, 'en');
    const { unmount } = render(<LanguageProvider><Probe /></LanguageProvider>);
    expect(screen.getByText('1,234.5|₫2,000|50%')).toBeInTheDocument();
    unmount();
    localStorage.setItem(STORAGE_KEY, 'vi');
    render(<LanguageProvider><Probe /></LanguageProvider>);
    expect(screen.getByText('1.234,5|2.000 ₫|50%')).toBeInTheDocument();
    localStorage.removeItem(STORAGE_KEY);
  });
});
