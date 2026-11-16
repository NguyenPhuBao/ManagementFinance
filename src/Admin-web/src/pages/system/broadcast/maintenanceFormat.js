export const HOUR = 3600 * 1000;
export const MIN_LEAD_HOURS = 3;
/** Backend chỉ nhận lịch trong 14 ngày tới (khớp MAX_LEAD_TIME_MS của maintenance.manager.js). */
export const MAX_LEAD_DAYS = 14;
/** Một phiên bảo trì kéo dài tối đa 7 ngày (khớp MAX_SESSION_MS của maintenance.manager.js). */
export const MAX_SESSION_DAYS = 7;

export const toLocalInput = (ms) => {
  const d = new Date(ms);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

export const scheduledListOf = (maintenance) => {
  if (Array.isArray(maintenance?.scheduledList) && maintenance.scheduledList.length > 0) return maintenance.scheduledList;
  return maintenance?.scheduled ? [maintenance.scheduled] : [];
};

const formatSeconds = (sec) => {
  if (sec < 60) return `${sec}s`;
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}m ${sec % 60}s`;
  return `${Math.floor(min / 60)}h ${min % 60}m`;
};

/**
 * Kết thúc thực tế: giờ phiên thật sự dừng; lịch hủy khi chưa chạy ghi giờ hủy (cancelled = true);
 * đang chạy thì { ongoing: true }; chưa chạy thì null.
 */
export const actualEnd = (row) => {
  const { status, started_at: startedAt, ended_at: endedAt, actual_duration_seconds: actual } = row;
  if (status === 'ONGOING') return { ongoing: true };
  if (!endedAt) return null;
  const neverRan = Number(actual) === 0 || (startedAt && new Date(endedAt) < new Date(startedAt));
  return { at: endedAt, cancelled: status === 'CANCELLED' && Boolean(neverRan) };
};

const secondsBetween = (from, to) => Math.max(0, Math.floor((to - from) / 1000));

export const durationText = (row, now, t) => {
  const { status, started_at: startedAt, ended_at: endedAt, actual_duration_seconds: actual } = row;
  const start = startedAt ? new Date(startedAt).getTime() : null;
  const end = endedAt ? new Date(endedAt).getTime() : null;

  if (actual !== null && actual !== undefined) {
    const sec = Number(actual);
    return status === 'CANCELLED' && sec === 0 ? t('broadcast.duration.cancelledBefore') : formatSeconds(sec);
  }
  if (status === 'CANCELLED') {
    if (!start || start > (end ?? now)) return t('broadcast.duration.cancelledBefore');
    return t('broadcast.duration.cancelledDuring', { time: formatSeconds(secondsBetween(start, end ?? now)) });
  }
  if (status === 'SCHEDULED') return t('broadcast.duration.notStarted');
  if (status === 'ONGOING' || !end) {
    if (!start) return t('broadcast.duration.ongoing');
    return t('broadcast.duration.live', { time: formatSeconds(secondsBetween(start, now)) });
  }
  return formatSeconds(secondsBetween(start, end));
};
