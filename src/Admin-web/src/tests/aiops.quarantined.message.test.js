/**
 * Mục 2.5: IP bị AIOps khoá thì chặn cả admin. Admin-web nhận 403 AIOPS_QUARANTINED phải báo rõ
 * "IP đang bị khoá đến …" theo ngôn ngữ đang chọn, ở mọi trang kể cả Đăng nhập (axios-client thay message).
 */
import axiosClient from '../api/axios-client';
import { STORAGE_KEY } from '../locales';
import { formatDateTime } from '../utils/format';

const rejectThrough = (data) => {
  const handler = axiosClient.interceptors.response.handlers.find((h) => h && h.rejected).rejected;
  const error = { config: { url: '/auth/login' }, response: { status: 403, data } };
  return handler(error).then(
    () => null,
    (err) => err
  );
};

describe('Thông báo khi IP bị AIOps khoá (2.5)', () => {
  afterEach(() => localStorage.removeItem(STORAGE_KEY));

  it('tiếng Việt: nêu IP đang bị khóa và thời điểm hết khóa', async () => {
    const until = '2026-11-16T10:30:00.000Z';
    const err = await rejectThrough({ code: 'AIOPS_QUARANTINED', message: 'raw', quarantineExpiresAt: until });
    expect(err.response.data.message).toBe(`IP bạn đang dùng bị khóa tạm thời đến ${formatDateTime(until)} do hệ thống phát hiện hành vi bất thường.`);
  });

  it('tiếng Anh', async () => {
    localStorage.setItem(STORAGE_KEY, 'en');
    const until = '2026-11-16T10:30:00.000Z';
    const err = await rejectThrough({ code: 'AIOPS_QUARANTINED', quarantineExpiresAt: until });
    expect(err.response.data.message).toBe(`Your IP is temporarily locked until ${formatDateTime(until)} due to unusual activity.`);
  });

  it('không có thời điểm hết khóa: vẫn báo rõ', async () => {
    const err = await rejectThrough({ code: 'AIOPS_QUARANTINED' });
    expect(err.response.data.message).toBe('IP bạn đang dùng bị khóa tạm thời do hệ thống phát hiện hành vi bất thường.');
  });

  it('lỗi khác giữ nguyên thông báo của máy chủ', async () => {
    const err = await rejectThrough({ code: 'OTHER', message: 'Sai mật khẩu' });
    expect(err.response.data.message).toBe('Sai mật khẩu');
  });
});
