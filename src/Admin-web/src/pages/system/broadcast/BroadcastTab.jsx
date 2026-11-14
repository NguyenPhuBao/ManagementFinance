import React, { useCallback, useEffect, useId, useState } from 'react';
import notificationApi from '../../../api/notification.api';
import TruncateCell from '../../../components/common/TruncateCell';
import { useAlertSafe } from '../../../store/alert.context';
import { useLanguageSafe } from '../../../store/language.context';
import { formatDateTime } from '../../../utils/format';
import { Badge, Button, Card, DataTable, Icon, Pagination } from '../../../components/ui';

const LEVELS = [
  { value: 'info', tone: 'info', icon: 'info' },
  { value: 'warning', tone: 'warning', icon: 'warning' },
  { value: 'critical', tone: 'danger', icon: 'error' },
];
const PREVIEW_TONE = {
  info: 'border-info bg-info-soft',
  warning: 'border-warning bg-warning-soft',
  critical: 'border-danger bg-danger-soft',
};
const TITLE_MAX = 120;
const MESSAGE_MAX = 500;

const fieldClass =
  'w-full rounded-lg border border-line bg-card px-3 text-sm text-ink focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20';

const BroadcastTab = () => {
  const { t } = useLanguageSafe();
  const notify = useAlertSafe();
  const ids = useId();
  const [level, setLevel] = useState('info');
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState(null);

  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [limit, setLimit] = useState(5);
  const [loading, setLoading] = useState(true);
  const [version, setVersion] = useState(0);

  const loadHistory = useCallback(async () => {
    setLoading(true);
    try {
      const res = await notificationApi.getBroadcastHistory({ page, limit });
      const payload = res?.data?.data || res?.data || res;
      if (payload && Array.isArray(payload.data)) {
        setRows(payload.data);
        setTotal(Number(payload.pagination?.total ?? payload.data.length) || 0);
      } else if (Array.isArray(payload)) {
        setRows(payload);
        setTotal(payload.length);
      }
    } catch (err) {
      console.error('[BROADCAST] Lỗi tải lịch sử thông báo:', err);
    } finally {
      setLoading(false);
    }
  }, [page, limit]);

  useEffect(() => {
    loadHistory();
  }, [loadHistory, version]);

  const send = async (e) => {
    e.preventDefault();
    if (!title.trim() || !message.trim()) return;
    setSending(true);
    setResult(null);
    try {
      await notificationApi.broadcastToAll({ title: title.trim(), message: message.trim(), level });
      setResult({ ok: true, text: t('broadcast.send.success') });
      if (notify) notify.success(t('broadcast.send.success'));
      setTitle('');
      setMessage('');
      setLevel('info');
      if (page === 1) setVersion((v) => v + 1);
      else setPage(1);
    } catch (err) {
      const text = err?.response?.data?.message || t('broadcast.send.failed');
      setResult({ ok: false, text });
      if (notify) notify.error(text, t('broadcast.feedback.errorTitle'));
    } finally {
      setSending(false);
    }
  };

  const columns = [
    { key: 'id', title: '#', width: '3.5rem', render: (r) => <span className="font-mono text-ink-faint">{r.id}</span> },
    {
      key: 'level',
      title: t('broadcast.send.colLevel'),
      render: (r) => {
        const lv = LEVELS.find((l) => l.value === String(r.level || 'info').toLowerCase()) || LEVELS[0];
        return <Badge tone={lv.tone}>{t(`broadcast.levels.${lv.value}`)}</Badge>;
      },
    },
    { key: 'title', title: t('broadcast.send.colTitle'), width: '22%', render: (r) => <div className="max-w-xs"><TruncateCell text={r.title} className="font-medium text-ink" /></div> },
    { key: 'message', title: t('broadcast.send.colMessage'), width: '34%', render: (r) => <div className="max-w-md"><TruncateCell text={r.message} className="text-ink-muted" /></div> },
    { key: 'sender', title: t('broadcast.send.colSender'), render: (r) => <span className="text-ink">{r.sender_username || 'admin'}</span> },
    { key: 'time', title: t('broadcast.send.colTime'), align: 'right', render: (r) => <span className="whitespace-nowrap text-ink-muted">{r.created_at ? formatDateTime(r.created_at) : '—'}</span> },
  ];

  const current = LEVELS.find((l) => l.value === level);

  return (
    <div className="flex flex-col gap-5">
      <Card title={t('broadcast.send.title')} padded>
        <form onSubmit={send} className="flex flex-col gap-4">
          <fieldset className="m-0 border-0 p-0">
            <legend className="mb-2 text-sm font-medium text-ink">{t('broadcast.send.level')}</legend>
            <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
              {LEVELS.map((l) => (
                <label
                  key={l.value}
                  className={`flex cursor-pointer items-center gap-2 rounded-lg border px-3 py-2.5 text-sm ${
                    level === l.value ? 'border-brand bg-brand-soft font-semibold text-ink' : 'border-line text-ink-muted hover:bg-muted'
                  }`}
                >
                  <input
                    type="radio"
                    name={`${ids}-level`}
                    value={l.value}
                    checked={level === l.value}
                    onChange={() => setLevel(l.value)}
                    className="h-4 w-4 cursor-pointer accent-brand"
                  />
                  {t(`broadcast.levels.${l.value}`)}
                </label>
              ))}
            </div>
            <p className="m-0 mt-1.5 text-sm text-ink-muted">{t(`broadcast.levelHints.${level}`)}</p>
          </fieldset>

          <div>
            <div className="mb-1 flex items-baseline justify-between gap-2">
              <label htmlFor={`${ids}-title`} className="text-sm font-medium text-ink">
                {t('broadcast.send.titleLabel')}
              </label>
              <span className="text-xs tabular-nums text-ink-faint">{`${title.length}/${TITLE_MAX}`}</span>
            </div>
            <input
              id={`${ids}-title`}
              type="text"
              maxLength={TITLE_MAX}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder={t('broadcast.send.titlePlaceholder')}
              className={`${fieldClass} h-10`}
            />
          </div>

          <div>
            <div className="mb-1 flex items-baseline justify-between gap-2">
              <label htmlFor={`${ids}-message`} className="text-sm font-medium text-ink">
                {t('broadcast.send.messageLabel')}
              </label>
              <span className="text-xs tabular-nums text-ink-faint">{`${message.length}/${MESSAGE_MAX}`}</span>
            </div>
            <textarea
              id={`${ids}-message`}
              rows={4}
              maxLength={MESSAGE_MAX}
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder={t('broadcast.send.messagePlaceholder')}
              className={`${fieldClass} resize-none py-2`}
            />
          </div>

          {(title || message) && (
            <section aria-label={t('broadcast.send.preview')} className={`rounded-lg border px-4 py-3 ${PREVIEW_TONE[level]}`}>
              <div className="mb-1 flex items-center gap-1.5 text-xs font-semibold text-ink-muted">
                <Icon name={current.icon} size="sm" />
                {t('broadcast.send.preview')}
              </div>
              <p className="m-0 font-semibold text-ink">{title || t('broadcast.send.previewTitle')}</p>
              <p className="m-0 mt-1 whitespace-pre-wrap text-sm text-ink">{message || t('broadcast.send.previewMessage')}</p>
            </section>
          )}

          {result && (
            <p role="status" className={`m-0 text-sm ${result.ok ? 'text-success' : 'text-danger'}`}>
              {result.text}
            </p>
          )}

          <div>
            <Button type="submit" variant="primary" icon="send" loading={sending} disabled={!title.trim() || !message.trim()}>
              {t('broadcast.send.submit')}
            </Button>
          </div>
        </form>
      </Card>

      <Card title={t('broadcast.send.historyTitle')}>
        <DataTable label={t('broadcast.send.historyTitle')} columns={columns} rows={rows} rowKey="id" loading={loading && rows.length === 0} emptyTitle={t('broadcast.send.empty')} minWidth={760} />
        <Pagination
          currentPage={page}
          pageSize={limit}
          total={total}
          pageSizeOptions={[5, 10, 20]}
          onPageChange={setPage}
          onPageSizeChange={(size) => {
            setLimit(size);
            setPage(1);
          }}
          itemLabel={t('broadcast.send.itemLabel')}
        />
      </Card>
    </div>
  );
};

export default BroadcastTab;
