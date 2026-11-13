import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import useSocket from '../../hooks/useSocket';
import adminApi from '../../api/admin.api';
import ServerHealthPanel from '../../components/common/ServerHealthPanel';
import TruncateCell from '../../components/common/TruncateCell';
import RequestCell from '../../components/common/RequestCell';
import { useLanguageSafe } from '../../store/language.context';
import { AUDIT_STATUS_TONE, classifyAuditAction } from '../../utils/audit-tags.util';
import { Badge, Card, DataTable, PageHeader, Pagination, StatCard, Tabs } from '../../components/ui';
import LineChart from './components/LineChart';
import PeriodPicker from './components/PeriodPicker';
import { formatActivityTime, periodParams, vnToday } from './dashboardFormat';

const POLL_MS = 10_000;
const PERIODS = [
  { key: 'today', label: 'dashboard.filters.today' },
  { key: '7days', label: 'dashboard.filters.sevenDays' },
  { key: '1month', label: 'dashboard.filters.oneMonth' },
  { key: '1year', label: 'dashboard.filters.oneYear' },
];
const EMPTY_STATS = { summary: { total: 0, max: 0, avg: 0 }, timeline: [], format: 'hour' };

const num = (v) => Number(v || 0).toLocaleString('vi-VN');

const toActivity = (item, t) => ({
  key: item.id ? String(item.id) : `${item.time_req}-${item.action}`,
  id: item.id,
  user: item.user || t('dashboard.recentActivities.defaultUser'),
  action: item.action || t('dashboard.recentActivities.defaultAction'),
  request: item.request || null,
  reason: item.reason || null,
  status: item.status || 'Pass',
  time: formatActivityTime(item, t),
  timeReq: item.time_req,
});

const DashboardPage = () => {
  const socket = useSocket();
  const { t } = useLanguageSafe();
  const today = useMemo(() => vnToday(), []);

  const [timeFilter, setTimeFilter] = useState('today');
  const [customFilter, setCustomFilter] = useState(null);

  const [totalUsers, setTotalUsers] = useState(null);
  const [totalCategories, setTotalCategories] = useState(null);
  const [newUsers, setNewUsers] = useState({ current: 0, previous: 0, growth: 0 });
  const [uptime, setUptime] = useState(null);
  const [uptimeError, setUptimeError] = useState(false);
  const [loginStats, setLoginStats] = useState(EMPTY_STATS);
  const [requestStats, setRequestStats] = useState(EMPTY_STATS);
  const [statsLoading, setStatsLoading] = useState(true);

  const [activities, setActivities] = useState([]);
  const [activityPage, setActivityPage] = useState(1);
  const [activityLimit, setActivityLimit] = useState(10);
  const [activityTotal, setActivityTotal] = useState(0);
  const [activitiesLoading, setActivitiesLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    const load = async () => {
      try {
        const [users, categories] = await Promise.all([adminApi.getTotalUsers(), adminApi.getTotalCategories()]);
        if (!alive) return;
        setTotalUsers(users.data.total);
        setTotalCategories(categories.data.total);
      } catch (err) {
        console.error('[DASHBOARD] Lỗi tải thống kê tổng:', err);
      }
    };
    load();
    const timer = setInterval(load, POLL_MS);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, []);

  useEffect(() => {
    let alive = true;
    const load = async () => {
      try {
        const res = await adminApi.getSystemHealth();
        if (!alive) return;
        const data = res?.data?.data || res?.data;
        if (!data) {
          setUptimeError(true);
          return;
        }
        setUptime(data.uptime || (typeof data.uptimePercent === 'number' ? data : { uptimePercent: 100 }));
        setUptimeError(false);
      } catch (err) {
        if (alive) setUptimeError(true);
      }
    };
    load();
    const timer = setInterval(load, POLL_MS);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, []);

  useEffect(() => {
    let alive = true;
    const params = periodParams(timeFilter, customFilter);
    const load = async (background) => {
      if (!background) setStatsLoading(true);
      try {
        const [usersRes, loginRes, requestRes] = await Promise.all([
          adminApi.getUserToTime(params),
          adminApi.getLoginStats(params),
          adminApi.getRequestStats(params),
        ]);
        if (!alive) return;
        if (usersRes.data) setNewUsers(usersRes.data);
        if (loginRes.data) setLoginStats(loginRes.data);
        if (requestRes.data) setRequestStats(requestRes.data);
      } catch (err) {
        console.error('[DASHBOARD] Lỗi tải thống kê theo thời gian:', err);
      } finally {
        if (alive && !background) setStatsLoading(false);
      }
    };
    load(false);
    const timer = setInterval(() => load(true), POLL_MS);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, [timeFilter, customFilter]);

  useEffect(() => {
    let alive = true;
    setActivitiesLoading(true);
    adminApi
      .getRecentActivities({ page: activityPage, limit: activityLimit, sort: 'desc' })
      .then((res) => {
        if (!alive || !res.data) return;
        setActivities(res.data.items || []);
        setActivityTotal(res.data.pagination?.total || 0);
      })
      .catch((err) => console.error('[DASHBOARD] Lỗi tải hoạt động gần đây:', err))
      .finally(() => alive && setActivitiesLoading(false));
    return () => {
      alive = false;
    };
  }, [activityPage, activityLimit]);

  useEffect(() => {
    if (!socket) return undefined;
    const onActivity = (data) => {
      if (!data) return;
      setActivityTotal((n) => n + 1);
      if (activityPage !== 1) return;
      setActivities((list) => [data, ...list.filter((a) => !data.id || a.id !== data.id)].slice(0, activityLimit));
    };
    const onMetrics = (data) => {
      if (!data || (!data.uptimeFormatted && typeof data.uptimePercent !== 'number')) return;
      setUptime((prev) => ({
        ...prev,
        uptimeFormatted: data.uptimeFormatted,
        uptimePercent: typeof data.uptimePercent === 'number' ? data.uptimePercent : prev?.uptimePercent ?? 100,
        uptimeSeconds: data.uptimeSeconds,
        downtimeSeconds: data.downtimeSeconds ?? prev?.downtimeSeconds ?? 0,
      }));
      setUptimeError(false);
    };
    socket.on('audit_activity', onActivity);
    socket.on('admin.metrics_stream', onMetrics);
    return () => {
      socket.off('audit_activity', onActivity);
      socket.off('admin.metrics_stream', onMetrics);
    };
  }, [socket, activityPage, activityLimit]);

  const uptimeCard = (() => {
    const pct = typeof uptime?.uptimePercent === 'number' && !Number.isNaN(uptime.uptimePercent) ? uptime.uptimePercent : null;
    if (pct === null) {
      return uptimeError
        ? { value: '—', hint: t('dashboard.kpi.error'), tone: 'danger' }
        : { value: '—', hint: t('dashboard.kpi.loading'), tone: 'neutral' };
    }
    const downSec = Number(uptime?.downtimeSeconds) || 0;
    const downtime =
      downSec <= 0
        ? null
        : downSec >= 3600
          ? t('dashboard.kpi.downtimeHours', { n: (downSec / 3600).toFixed(1) })
          : t('dashboard.kpi.downtimeMinutes', { n: Math.round(downSec / 60) });
    return {
      value: `${pct.toFixed(2)}%`,
      hint:
        [uptime?.uptimeFormatted && t('dashboard.kpi.runningFor', { time: uptime.uptimeFormatted }), downtime].filter(Boolean).join(' · ') ||
        t('dashboard.kpi.stable'),
      tone: pct >= 99 ? 'success' : pct >= 95 ? 'warning' : 'danger',
    };
  })();

  const growth = Number(newUsers.growth) || 0;

  const chartActions = (stats, withTotal) => (
    <span className="text-xs text-ink-muted">
      {t('dashboard.charts.summary', { avg: num(stats.summary?.avg), peak: num(stats.summary?.max) })}
      {withTotal && ` · ${t('dashboard.charts.total', { n: num(stats.summary?.total) })}`}
    </span>
  );

  const columns = [
    { key: 'time', title: t('dashboard.recentActivities.columns.time'), width: '7rem', render: (a) => <span className="whitespace-nowrap tabular-nums text-ink-muted" title={a.timeReq}>{a.time}</span> },
    { key: 'user', title: t('dashboard.recentActivities.columns.user'), width: '12rem', render: (a) => <TruncateCell text={a.user} className="font-medium text-ink" /> },
    {
      key: 'action',
      title: t('dashboard.recentActivities.columns.action'),
      render: (a) => {
        const { tagInfo, cleanAction } = classifyAuditAction(a.action, a.request);
        return (
          <div className="flex min-w-0 flex-col items-start gap-1">
            <Badge tone={tagInfo.tone}>{tagInfo.label}</Badge>
            <TruncateCell text={cleanAction} className="text-ink" />
          </div>
        );
      },
    },
    { key: 'request', title: t('dashboard.recentActivities.columns.request'), render: (a) => <div className="max-w-xs"><RequestCell value={a.request} /></div> },
    { key: 'reason', title: t('dashboard.recentActivities.columns.reason'), width: '10rem', render: (a) => <TruncateCell text={a.reason || '—'} className="text-ink-muted" /> },
    {
      key: 'status',
      title: t('dashboard.recentActivities.columns.status'),
      render: (a) => <Badge tone={AUDIT_STATUS_TONE[a.status] || 'neutral'}>{t(`commonStatus.${a.status}`, a.status)}</Badge>,
    },
  ];

  return (
    <div className="flex flex-col gap-5">
      <PageHeader
        title={t('dashboard.title')}
        description={t('dashboard.subtitle')}
        actions={
          <>
            <Tabs
              ariaLabel={t('dashboard.filters.label')}
              value={timeFilter}
              onChange={(key) => setTimeFilter(key)}
              items={PERIODS.map((p) => ({ key: p.key, label: t(p.label) }))}
            />
            <PeriodPicker
              now={today}
              selected={timeFilter === 'custom' ? customFilter : null}
              onSelect={(filter) => {
                setCustomFilter(filter);
                setTimeFilter('custom');
              }}
            />
          </>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard label={t('dashboard.kpi.totalUsers')} value={totalUsers === null ? '—' : num(totalUsers)} />
        <StatCard
          label={t('dashboard.kpi.newUsers')}
          value={num(newUsers.current)}
          hint={t('dashboard.kpi.growth', { value: `${growth >= 0 ? '+' : ''}${growth}%` })}
          hintTone={growth >= 0 ? 'success' : 'danger'}
        />
        <StatCard label={t('dashboard.kpi.totalCategories')} value={totalCategories === null ? '—' : num(totalCategories)} />
        <StatCard label={t('dashboard.kpi.systemUptime')} value={uptimeCard.value} hint={uptimeCard.hint} hintTone={uptimeCard.tone} />
      </div>

      <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-3">
        <div className="flex min-w-0 flex-col gap-4 xl:col-span-2">
          <Card title={t('dashboard.charts.login')} actions={chartActions(loginStats, false)} padded>
            <LineChart
              label={t('dashboard.charts.login')}
              data={loginStats.timeline || []}
              unit={t('dashboard.charts.unitHits')}
              format={loginStats.format || 'day'}
              loading={statsLoading}
              tone="brand"
            />
          </Card>
          <Card title={t('dashboard.charts.request')} actions={chartActions(requestStats, true)} padded>
            <LineChart
              label={t('dashboard.charts.request')}
              data={requestStats.timeline || []}
              unit={t('dashboard.charts.unitReq')}
              format={requestStats.format || 'day'}
              loading={statsLoading}
              tone="info"
            />
          </Card>
        </div>
        <ServerHealthPanel uptimeData={uptime} />
      </div>

      <Card
        title={t('dashboard.recentActivities.title')}
        actions={
          <Link to="/audit-logs" className="text-sm font-medium text-brand hover:text-brand-hover">
            {t('dashboard.recentActivities.viewAll')}
          </Link>
        }
      >
        <DataTable
          columns={columns}
          rows={activities.map((item) => toActivity(item, t))}
          rowKey="key"
          loading={activitiesLoading && activities.length === 0}
          emptyTitle={t('dashboard.recentActivities.noActivities')}
          minWidth={860}
        />
        <Pagination
          currentPage={activityPage}
          pageSize={activityLimit}
          total={activityTotal}
          pageSizeOptions={[5, 10, 20, 50]}
          onPageChange={setActivityPage}
          onPageSizeChange={(size) => {
            setActivityLimit(size);
            setActivityPage(1);
          }}
          itemLabel={t('dashboard.recentActivities.itemLabel')}
        />
      </Card>
    </div>
  );
};

export default DashboardPage;
