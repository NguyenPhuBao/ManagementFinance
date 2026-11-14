const VN_PARTS = new Intl.DateTimeFormat('en-US', {
  timeZone: 'Asia/Ho_Chi_Minh',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
});

export const vnDateParts = (input) => {
  if (!input) return null;
  const d = new Date(input);
  if (Number.isNaN(d.getTime())) return null;
  const p = Object.fromEntries(VN_PARTS.formatToParts(d).map((part) => [part.type, part.value]));
  if (p.hour === '24') p.hour = '00';
  return p;
};

export const vnToday = () => {
  const p = vnDateParts(new Date());
  return { year: Number(p.year), month: Number(p.month), day: Number(p.day) };
};

export const formatActivityTime = (item, t) => {
  const justNow = t('dashboard.recentActivities.justNow');
  const p = vnDateParts(item?.time_req || item?.timeReq);
  if (!p) return item?.time || justNow;
  const now = vnDateParts(new Date());
  const sameDay = p.year === now.year && p.month === now.month && p.day === now.day;
  return sameDay ? `${p.hour}:${p.minute}` : `${p.hour}:${p.minute} ${p.day}/${p.month}`;
};

export const periodParams = (timeFilter, custom) => {
  if (timeFilter !== 'custom' || !custom) return { period: timeFilter };
  if (custom.mode === 'day') return { customType: 'date', date: custom.date };
  if (custom.mode === 'month') return { customType: 'month', month: custom.month, year: custom.year };
  return { customType: 'year', year: custom.year };
};
