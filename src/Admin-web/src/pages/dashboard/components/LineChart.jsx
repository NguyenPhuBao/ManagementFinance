import React, { useEffect, useId, useRef, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Spinner } from '../../../components/ui';

const TONES = { brand: 'text-brand', info: 'text-info' };
const HEIGHT = 224;
const PAD = { left: 40, right: 44, top: 16, bottom: 30 };

const buildTicks = (points, data, format, t) => {
  const isMonth = format === 'month' || (data.length === 12 && data[0]?.label?.startsWith('Thg'));
  const isHour = format === 'hour' || (data.length === 24 && data[0]?.label?.includes(':'));
  if (isMonth) {
    return { unit: t('dashboard.charts.xMonth'), ticks: points.map((p, i) => ({ x: p.x, text: String(i + 1).padStart(2, '0') })) };
  }
  if (isHour) {
    return {
      unit: t('dashboard.charts.xHour'),
      ticks: points.filter((_, i) => i % 3 === 0 || i === points.length - 1).map((p) => ({ x: p.x, text: p.label.split(':')[0] || '' })),
    };
  }
  if (data.length <= 8) {
    return { unit: t('dashboard.charts.xDay'), ticks: points.map((p) => ({ x: p.x, text: p.label })) };
  }
  return {
    unit: t('dashboard.charts.xDay'),
    ticks: points.filter((_, i) => i % 5 === 0 || i === points.length - 1).map((p) => ({ x: p.x, text: p.label.split('/')[0] || '' })),
  };
};

const useWidth = (ref, fallback) => {
  const [width, setWidth] = useState(fallback);
  useEffect(() => {
    const el = ref.current;
    if (!el || typeof ResizeObserver === 'undefined') return undefined;
    const observer = new ResizeObserver(([entry]) => {
      const w = Math.round(entry.contentRect.width);
      if (w > 0) setWidth(w);
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, [ref]);
  return width;
};

const Chart = ({ data, unit, format, width, label, t }) => {
  const gradientId = useId();
  const [hoverIndex, setHoverIndex] = useState(null);

  const maxVal = Math.max(...data.map((d) => d.count), 5);
  const drawWidth = width - PAD.left - PAD.right;
  const drawHeight = HEIGHT - PAD.top - PAD.bottom;
  const baseY = PAD.top + drawHeight;

  const points = data.map((item, i) => ({
    x: data.length === 1 ? PAD.left + drawWidth / 2 : PAD.left + (i / (data.length - 1)) * drawWidth,
    y: baseY - (item.count / maxVal) * drawHeight,
    label: item.label,
    count: item.count,
  }));

  let lineD = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i += 1) {
    const a = points[i];
    const b = points[i + 1];
    const mid = a.x + (b.x - a.x) / 2;
    lineD += ` C ${mid} ${a.y}, ${mid} ${b.y}, ${b.x} ${b.y}`;
  }
  const areaD = `${lineD} L ${points[points.length - 1].x} ${baseY} L ${points[0].x} ${baseY} Z`;

  const { unit: xUnit, ticks } = buildTicks(points, data, format, t);
  const hovered = hoverIndex !== null ? points[hoverIndex] : null;
  const tipW = 112;

  return (
    <svg role="img" aria-label={label} width={width} height={HEIGHT} viewBox={`0 0 ${width} ${HEIGHT}`} className="block overflow-visible" onMouseLeave={() => setHoverIndex(null)}>
      <defs>
        <linearGradient id={gradientId} x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="currentColor" stopOpacity="0.18" />
          <stop offset="100%" stopColor="currentColor" stopOpacity="0" />
        </linearGradient>
      </defs>

      {[PAD.top, PAD.top + drawHeight / 2].map((y) => (
        <line key={y} x1={PAD.left} y1={y} x2={width - PAD.right} y2={y} className="stroke-line" strokeDasharray="4 4" />
      ))}
      <line x1={PAD.left} y1={baseY} x2={width - PAD.right} y2={baseY} className="stroke-line" />

      {[
        [PAD.top, maxVal],
        [PAD.top + drawHeight / 2, Math.round(maxVal / 2)],
        [baseY, 0],
      ].map(([y, v]) => (
        <text key={y} x={PAD.left - 8} y={y + 4} textAnchor="end" fontSize="12" className="fill-ink-faint tabular-nums">
          {v.toLocaleString('vi-VN')}
        </text>
      ))}

      <path d={areaD} fill={`url(#${gradientId})`} />
      <path d={lineD} fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />

      {points.map((p, i) => (
        <g key={`${p.label}-${i}`}>
          <circle data-testid="chart-point" cx={p.x} cy={p.y} r="12" fill="transparent" className="cursor-pointer" onMouseEnter={() => setHoverIndex(i)} />
          <circle
            cx={p.x}
            cy={p.y}
            r={hoverIndex === i ? 5 : data.length <= 12 ? 3.5 : 2.5}
            className="pointer-events-none fill-card"
            stroke="currentColor"
            strokeWidth={hoverIndex === i ? 2.5 : 1.5}
          />
        </g>
      ))}

      {ticks.map((tick, i) => (
        <text key={i} x={tick.x} y={baseY + 20} textAnchor="middle" fontSize="12" className="fill-ink-faint tabular-nums">
          {tick.text}
        </text>
      ))}
      <text x={width} y={baseY + 20} textAnchor="end" fontSize="12" className="fill-ink-faint">
        ({xUnit})
      </text>

      {hovered && (
        <g transform={`translate(${Math.min(Math.max(hovered.x, tipW / 2), width - tipW / 2)}, ${Math.max(hovered.y - 52, 0)})`} className="pointer-events-none">
          <rect x={-tipW / 2} y="0" width={tipW} height="40" rx="6" className="fill-ink" />
          <text x="0" y="16" fontSize="12" textAnchor="middle" className="fill-line">
            {hovered.label}
          </text>
          <text x="0" y="32" fontSize="12" fontWeight="700" textAnchor="middle" className="fill-card tabular-nums">
            {`${hovered.count.toLocaleString('vi-VN')} ${unit}`}
          </text>
        </g>
      )}
    </svg>
  );
};

const LineChart = ({ data = [], unit, format = 'day', loading = false, tone = 'brand', label }) => {
  const { t } = useLanguageSafe();
  const boxRef = useRef(null);
  const width = useWidth(boxRef, 560);

  let body;
  if (data.length === 0) {
    body = (
      <div className="flex h-full items-center justify-center text-sm text-ink-muted">
        {loading ? <Spinner label={t('common.loading', 'Đang tải')} className="text-brand" /> : t('dashboard.charts.noData')}
      </div>
    );
  } else {
    body = <Chart data={data} unit={unit} format={format} width={width} label={label} t={t} />;
  }

  return (
    <div ref={boxRef} className={`h-56 w-full select-none ${TONES[tone] || TONES.brand}`}>
      {body}
    </div>
  );
};

export default LineChart;
