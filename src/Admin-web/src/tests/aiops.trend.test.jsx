import React from 'react';
import { render, screen } from '@testing-library/react';
import TrendSection from '../pages/system/aiops/TrendSection';

// Kích thước vẽ của TrendSection: W = 800, PAD_X = 40 → trục ngang 40..760.
const X0 = 40;
const XW = 720;
const MIN = 60e3;
const HOUR = 3600e3;
const DAY = 24 * HOUR;

const ago = (ms) => new Date(Date.now() - ms).toISOString();
const point = (ms, auth = 10) => ({ timestamp: ago(ms), vectorScores: { auth, traffic: 20, exploit: 0, resource: 30 } });

const renderTrend = (over = {}) => {
  const ops = {
    historyData: [point(5 * MIN), point(1 * MIN)],
    vectorScores: { auth: 10, traffic: 20, exploit: 0, resource: 30 },
    timePreset: '10m',
    customRange: { from: '', to: '', applied: false },
    setCustomRange: vi.fn(),
    handleSelectTimePreset: vi.fn(),
    handleApplyCustomRange: vi.fn(),
    handleClearCustomRange: vi.fn(),
    fetchingHistory: false,
    activeVectorTab: 'all',
    setActiveVectorTab: vi.fn(),
    ...over,
  };
  return render(<TrendSection ops={ops} />);
};

const xTicks = () => screen.getAllByTestId('trend-x-tick').map((el) => ({ label: el.textContent, x: Number(el.getAttribute('x')) }));
const legendValue = (key) => screen.getByTestId(`trend-legend-${key}`).textContent;

describe('Biểu đồ xu hướng — 1.3', () => {
  it('1. khung 7 ngày: nhãn -7…0, vị trí theo thời gian thật', () => {
    renderTrend({ timePreset: '7d', historyData: [point(6 * DAY), point(1 * DAY)] });
    const ticks = xTicks();
    expect(ticks.map((t) => t.label)).toEqual(['-7', '-6', '-5', '-4', '-3', '-2', '-1', '0']);
    expect(ticks[0].x).toBeCloseTo(X0, 0);
    expect(ticks.find((t) => t.label === '-3').x).toBeCloseTo(X0 + XW * (4 / 7), 0);
    expect(ticks.at(-1).x).toBeCloseTo(X0 + XW, 0);
  });

  it('1. các khung khác: nhãn đặt đúng tỉ lệ thời gian (1 giờ: -30 ở giữa)', () => {
    renderTrend({ timePreset: '1h', historyData: [point(40 * MIN), point(5 * MIN)] });
    expect(xTicks().find((t) => t.label === '-30').x).toBeCloseTo(X0 + XW / 2, 0);
  });

  it('2. khoảng tự chọn 48 giờ: nhãn có ngày và giờ, không trùng nhau liền kề', () => {
    renderTrend({
      customRange: { from: '2026-11-10T00:00', to: '2026-11-12T00:00', applied: true },
      historyData: [{ timestamp: new Date('2026-11-10T06:00').toISOString(), vectorScores: { auth: 5 } }],
    });
    const labels = xTicks().map((t) => t.label);
    expect(labels[0]).toBe('10/11 00:00');
    expect(labels.at(-1)).toBe('12/11 00:00');
    labels.forEach((l, i) => i > 0 && expect(l).not.toBe(labels[i - 1]));
  });

  it('2. khoảng tự chọn ≤ 24 giờ: nhãn giờ HH:mm; > 3 ngày: nhãn dd/MM không trùng', () => {
    const { unmount } = renderTrend({
      customRange: { from: '2026-11-10T08:00', to: '2026-11-10T18:00', applied: true },
      historyData: [{ timestamp: new Date('2026-11-10T09:00').toISOString(), vectorScores: { auth: 5 } }],
    });
    expect(xTicks()[0].label).toBe('08:00');
    unmount();
    renderTrend({
      customRange: { from: '2026-11-01T00:00', to: '2026-11-05T00:00', applied: true },
      historyData: [{ timestamp: new Date('2026-11-02T09:00').toISOString(), vectorScores: { auth: 5 } }],
    });
    const labels = xTicks().map((t) => t.label);
    expect(labels[0]).toBe('01/11');
    labels.forEach((l, i) => i > 0 && expect(l).not.toBe(labels[i - 1]));
  });

  it('3. mất số liệu một quãng dài: đường bị ngắt, không nối thẳng qua khoảng trống', () => {
    renderTrend({
      timePreset: '1h',
      activeVectorTab: 'auth',
      historyData: [point(50 * MIN), point(49 * MIN), point(48 * MIN), point(10 * MIN), point(9 * MIN)],
    });
    const d = screen.getByTestId('trend-path-auth').getAttribute('d');
    expect(d.match(/M/g)).toHaveLength(2);
  });

  it('4. điểm nằm ngoài khung thời gian bị bỏ, không dồn vào mép', () => {
    renderTrend({ timePreset: '10m', historyData: [point(30 * MIN), point(5 * MIN), point(1 * MIN)] });
    expect(screen.getAllByTestId('trend-hit')).toHaveLength(2);
  });

  it('4. mọi điểm đều ngoài khung: báo chưa có dữ liệu', () => {
    renderTrend({ timePreset: '10m', historyData: [point(2 * HOUR)] });
    expect(screen.getByText('Chưa có dữ liệu trong khoảng này')).toBeInTheDocument();
  });

  it('5. trục dọc có vạch 0, 50, 100', () => {
    renderTrend();
    expect(screen.getAllByTestId('trend-y-tick').map((el) => el.textContent)).toEqual(['0', '50', '100']);
  });

  it('6. xem khoảng tự chọn: số cạnh chú thích là điểm của mẫu cuối trong khoảng, không phải điểm hiện tại', () => {
    renderTrend({
      vectorScores: { auth: 10, traffic: 20, exploit: 0, resource: 30 },
      customRange: { from: '2026-11-10T08:00', to: '2026-11-10T18:00', applied: true },
      historyData: [
        { timestamp: new Date('2026-11-10T09:00').toISOString(), vectorScores: { auth: 40, traffic: 1, exploit: 2, resource: 3 } },
        { timestamp: new Date('2026-11-10T17:00').toISOString(), vectorScores: { auth: 75, traffic: 4, exploit: 5, resource: 6 } },
      ],
    });
    expect(legendValue('auth')).toBe('75');
  });

  it('6. thời gian thực: số cạnh chú thích là điểm hiện tại', () => {
    renderTrend({ vectorScores: { auth: 12, traffic: 20, exploit: 0, resource: 30 }, historyData: [point(1 * MIN, 99)] });
    expect(legendValue('auth')).toBe('12');
  });
});
