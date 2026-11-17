/**
 * Cài đặt riêng từng tài khoản quản trị, lưu trên máy chủ (2026-11-16).
 * Máy chủ là bản chính (GET / PUT /admin/me/settings); trình duyệt giữ bản sao theo khoá riêng từng tài khoản
 * (`admin_system_settings:<idaccount>`) để áp ngay khi tải trang và quyết tự khoá trước khi máy chủ trả lời.
 */
import React from 'react';
import { render, screen, waitFor, act } from '@testing-library/react';
import { SettingsProvider, useSettings } from '../store/settings.context';
import { STORAGE_KEYS } from '../utils/constants';
import adminApi from '../api/admin.api';

vi.mock('../api/admin.api', () => ({ default: { getMySettings: vi.fn(), updateMySettings: vi.fn() } }));

const DEFAULTS = { theme: 'light', tableDensity: 'comfortable', soundEnabled: true, toastDuration: 4500, showUnreadBadge: true, metricsInterval: 3, autoLockMinutes: 30 };
const cacheOf = (id) => JSON.parse(localStorage.getItem(`admin_system_settings:${id}`) || 'null');
const server = (settings, saved = true) => ({ data: { data: { settings: { ...DEFAULTS, ...settings }, saved } } });

let ctx;
const Probe = () => {
  ctx = useSettings();
  return <div data-testid="probe">{`${ctx.settings.theme}|${ctx.settings.autoLockMinutes}|${ctx.isLocked}`}</div>;
};
const probe = () => screen.getByTestId('probe').textContent;
const renderAs = (idaccount) => {
  if (idaccount) localStorage.setItem(STORAGE_KEYS.USER, JSON.stringify({ idaccount, username: `admin${idaccount}` }));
  if (!localStorage.getItem(STORAGE_KEYS.ACCESS_TOKEN)) localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'tok');
  return render(<SettingsProvider><Probe /></SettingsProvider>);
};

beforeEach(() => {
  localStorage.clear();
  adminApi.getMySettings.mockReset().mockResolvedValue(server({}));
  adminApi.updateMySettings.mockReset().mockImplementation((body) => Promise.resolve(server(body)));
});

describe('Cài đặt riêng từng tài khoản', () => {
  it('tải trang: áp ngay bản sao của đúng tài khoản, rồi lấy bản chính từ máy chủ', async () => {
    localStorage.setItem('admin_system_settings:5', JSON.stringify({ ...DEFAULTS, theme: 'dark' }));
    adminApi.getMySettings.mockResolvedValue(server({ theme: 'dark', autoLockMinutes: 60 }));
    renderAs(5);
    expect(probe()).toBe('dark|30|false');
    await waitFor(() => expect(probe()).toBe('dark|60|false'));
    expect(cacheOf(5).autoLockMinutes).toBe(60);
  });

  it('đổi sang tài khoản khác: dùng cài đặt của tài khoản mới, không mang cài đặt người trước', async () => {
    adminApi.getMySettings.mockResolvedValue(server({ theme: 'dark', autoLockMinutes: 0 }));
    renderAs(5);
    await waitFor(() => expect(probe()).toBe('dark|0|false'));
    adminApi.getMySettings.mockResolvedValue(server({ autoLockMinutes: 15 }));
    await act(async () => { ctx.setActiveAccount(7); });
    await waitFor(() => expect(probe()).toBe('light|15|false'));
    expect(cacheOf(5).theme).toBe('dark');
    expect(cacheOf(7).autoLockMinutes).toBe(15);
  });

  it('đổi cài đặt: gửi đúng khoá lên máy chủ và cập nhật bản sao của tài khoản đó', async () => {
    renderAs(5);
    await waitFor(() => expect(adminApi.getMySettings).toHaveBeenCalled());
    await act(async () => { ctx.updateSetting('autoLockMinutes', 15); });
    expect(adminApi.updateMySettings).toHaveBeenCalledWith({ autoLockMinutes: 15 });
    expect(cacheOf(5).autoLockMinutes).toBe(15);
    expect(localStorage.getItem('admin_system_settings')).toBeNull();
  });

  it('lần đầu tài khoản chưa có cài đặt trên máy chủ: chuyển cài đặt cũ (khoá chung) lên một lần rồi xoá khoá chung', async () => {
    localStorage.setItem('admin_system_settings', JSON.stringify({ theme: 'dark', autoLockMinutes: 0, khoaLa: 1 }));
    adminApi.getMySettings.mockResolvedValue(server({}, false));
    renderAs(5);
    await waitFor(() => expect(adminApi.updateMySettings).toHaveBeenCalledWith({ theme: 'dark', autoLockMinutes: 0 }));
    await waitFor(() => expect(probe()).toBe('dark|0|false'));
    expect(localStorage.getItem('admin_system_settings')).toBeNull();
  });

  it('máy chủ đã có cài đặt: không chuyển khoá chung, không ghi đè máy chủ', async () => {
    localStorage.setItem('admin_system_settings', JSON.stringify({ theme: 'dark' }));
    adminApi.getMySettings.mockResolvedValue(server({ autoLockMinutes: 60 }, true));
    renderAs(5);
    await waitFor(() => expect(probe()).toBe('light|60|false'));
    expect(adminApi.updateMySettings).not.toHaveBeenCalled();
  });

  it('tự khoá khi tải lại trang theo đúng cài đặt của tài khoản: 15 phút thì khoá, "Không tự khóa" thì không', () => {
    const away = String(Date.now() - 20 * 60 * 1000);
    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'tok');
    localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, away);
    localStorage.setItem('admin_system_settings:5', JSON.stringify({ ...DEFAULTS, autoLockMinutes: 15 }));
    localStorage.setItem('admin_system_settings:7', JSON.stringify({ ...DEFAULTS, autoLockMinutes: 0 }));
    const a = renderAs(5);
    expect(probe()).toBe('light|15|true');
    a.unmount();
    localStorage.clear();
    localStorage.setItem(STORAGE_KEYS.ACCESS_TOKEN, 'tok');
    localStorage.setItem(STORAGE_KEYS.LAST_ACTIVE_AT, away);
    localStorage.setItem('admin_system_settings:7', JSON.stringify({ ...DEFAULTS, autoLockMinutes: 0 }));
    renderAs(7);
    expect(probe()).toBe('light|0|false');
  });

  it('đăng xuất (không còn tài khoản): về mặc định; khôi phục mặc định gửi đủ 7 khoá lên máy chủ', async () => {
    adminApi.getMySettings.mockResolvedValue(server({ theme: 'dark' }));
    renderAs(5);
    await waitFor(() => expect(probe()).toBe('dark|30|false'));
    await act(async () => { ctx.resetSettings(); });
    expect(adminApi.updateMySettings).toHaveBeenCalledWith(DEFAULTS);
    await act(async () => { ctx.setActiveAccount(null); });
    expect(probe()).toBe('light|30|false');
  });

  it('lưu lên máy chủ lỗi: cài đặt vẫn có hiệu lực trên máy và báo chưa lưu được', async () => {
    adminApi.updateMySettings.mockRejectedValue(new Error('Network Error'));
    renderAs(5);
    await waitFor(() => expect(adminApi.getMySettings).toHaveBeenCalled());
    await act(async () => { ctx.updateSetting('theme', 'dark'); });
    expect(probe()).toBe('dark|30|false');
    await waitFor(() => expect(ctx.settingsSyncFailed).toBe(true));
  });
});
