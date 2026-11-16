import React, { useEffect, useRef, useState } from 'react';
import { useLanguageSafe } from '../../../store/language.context';
import { Button, Tabs } from '../../../components/ui';

const pad = (n) => String(n).padStart(2, '0');
const WEEKDAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

const cellClass = (selected, today) =>
  `h-8 cursor-pointer rounded-lg text-sm transition-colors disabled:cursor-not-allowed disabled:opacity-30 ${
    selected ? 'bg-brand font-semibold text-brand-on' : today ? 'border border-brand font-semibold text-brand hover:bg-brand-soft' : 'text-ink hover:bg-muted'
  }`;

const PeriodPicker = ({ now, selected, onSelect }) => {
  const { t } = useLanguageSafe();
  const [open, setOpen] = useState(false);
  const [tab, setTab] = useState('day');
  const [viewYear, setViewYear] = useState(now.year);
  const [viewMonth, setViewMonth] = useState(now.month);
  const boxRef = useRef(null);

  useEffect(() => {
    if (!open) return undefined;
    const onDown = (e) => boxRef.current && !boxRef.current.contains(e.target) && setOpen(false);
    const onKey = (e) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [open]);

  const futureMonth = (m, y) => y > now.year || (y === now.year && m > now.month);
  const futureDay = (d, m, y) => futureMonth(m, y) || (y === now.year && m === now.month && d > now.day);

  const choose = (filter) => {
    onSelect(filter);
    setOpen(false);
  };

  const pickDay = (d) =>
    choose({ mode: 'day', date: `${viewYear}-${pad(viewMonth)}-${pad(d)}`, month: viewMonth, year: viewYear, label: `${pad(d)}/${pad(viewMonth)}/${viewYear}` });
  const pickMonth = (m) =>
    choose({ mode: 'month', date: `${viewYear}-${pad(m)}-01`, month: m, year: viewYear, label: t('dashboard.filters.monthFormat', { month: m, year: viewYear }) });
  const pickYear = (y) => choose({ mode: 'year', date: `${y}-01-01`, month: 1, year: y, label: t('dashboard.filters.yearFormat', { year: y }) });

  const shiftMonth = (delta) => {
    const total = viewYear * 12 + (viewMonth - 1) + delta;
    setViewYear(Math.floor(total / 12));
    setViewMonth((total % 12) + 1);
  };
  const nextMonthLocked = futureMonth(viewMonth === 12 ? 1 : viewMonth + 1, viewMonth === 12 ? viewYear + 1 : viewYear);
  const daysInMonth = new Date(viewYear, viewMonth, 0).getDate();
  const offset = (new Date(viewYear, viewMonth - 1, 1).getDay() + 6) % 7;
  const title = t('dashboard.filters.pick');

  return (
    <div ref={boxRef} className="relative">
      <Button
        icon="calendar_month"
        aria-haspopup="dialog"
        aria-expanded={open}
        className={selected ? 'border-brand text-brand' : ''}
        onClick={() => setOpen((v) => !v)}
      >
        {selected ? selected.label : title}
      </Button>

      {open && (
        <div role="dialog" aria-label={title} className="absolute right-0 top-full z-30 mt-2 w-80 rounded-xl border border-line bg-card p-4 shadow-lg">
          <div className="mb-3">
            <Tabs
              ariaLabel={title}
              value={tab}
              onChange={setTab}
              items={[
                { key: 'day', label: t('dashboard.filters.byDay') },
                { key: 'month', label: t('dashboard.filters.byMonth') },
                { key: 'year', label: t('dashboard.filters.byYear') },
              ]}
            />
          </div>

          {tab === 'day' && (
            <div>
              <div className="mb-2 flex items-center justify-between">
                <Button variant="ghost" size="sm" icon="chevron_left" aria-label={t('dashboard.filters.prevMonth')} onClick={() => shiftMonth(-1)} />
                <span className="text-sm font-semibold text-ink">{t('dashboard.filters.monthFormat', { month: viewMonth, year: viewYear })}</span>
                <Button variant="ghost" size="sm" icon="chevron_right" aria-label={t('dashboard.filters.nextMonth')} disabled={nextMonthLocked} onClick={() => shiftMonth(1)} />
              </div>
              <div className="mb-1 grid grid-cols-7 gap-1 text-center text-xs font-semibold text-ink-faint">
                {WEEKDAYS.map((d) => (
                  <span key={d}>{t(`dashboard.filters.${d}`)}</span>
                ))}
              </div>
              <div className="grid grid-cols-7 gap-1">
                {Array.from({ length: offset }, (_, i) => (
                  <span key={`e${i}`} />
                ))}
                {Array.from({ length: daysInMonth }, (_, i) => {
                  const d = i + 1;
                  const isSelected = selected?.mode === 'day' && selected.date === `${viewYear}-${pad(viewMonth)}-${pad(d)}`;
                  const isToday = d === now.day && viewMonth === now.month && viewYear === now.year;
                  return (
                    <button key={d} type="button" disabled={futureDay(d, viewMonth, viewYear)} onClick={() => pickDay(d)} className={cellClass(isSelected, isToday)}>
                      {d}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {tab === 'month' && (
            <div>
              <div className="mb-2 flex items-center justify-between">
                <Button variant="ghost" size="sm" icon="chevron_left" aria-label={t('dashboard.filters.prevYear')} onClick={() => setViewYear((y) => y - 1)} />
                <span className="text-sm font-semibold text-ink">{t('dashboard.filters.yearFormat', { year: viewYear })}</span>
                <Button variant="ghost" size="sm" icon="chevron_right" aria-label={t('dashboard.filters.nextYear')} disabled={viewYear >= now.year} onClick={() => setViewYear((y) => y + 1)} />
              </div>
              <div className="grid grid-cols-3 gap-2">
                {Array.from({ length: 12 }, (_, i) => {
                  const m = i + 1;
                  const isSelected = selected?.mode === 'month' && selected.month === m && selected.year === viewYear;
                  return (
                    <button key={m} type="button" disabled={futureMonth(m, viewYear)} onClick={() => pickMonth(m)} className={cellClass(isSelected, false)}>
                      {t(`dashboard.filters.month${m}`)}
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {tab === 'year' && (
            <div className="grid grid-cols-3 gap-2">
              {[4, 3, 2, 1, 0].map((back) => {
                const y = now.year - back;
                const isSelected = selected?.mode === 'year' && selected.year === y;
                return (
                  <button key={y} type="button" onClick={() => pickYear(y)} className={cellClass(isSelected, false)}>
                    {y}
                  </button>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default PeriodPicker;
