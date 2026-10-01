/**
 * Unit Test — Core Scheduler Service: Kiểm tra khởi tạo và chu trình lập lịch
 */

const { describe, it, after } = require('node:test');
const assert = require('node:assert');
const {
  initScheduler,
  stopScheduler,
  getMsUntilNextMidnightVietnam,
} = require('../../core/scheduler.service');

describe('Core — Scheduler Service & Bootstrap Safety', () => {
  after(() => {
    stopScheduler();
  });

  it('1. getMsUntilNextMidnightVietnam trả về khoảng cách thời gian hợp lệ (> 0 và <= 24h)', () => {
    const ms = getMsUntilNextMidnightVietnam();
    assert.ok(typeof ms === 'number', 'Kết quả phải là một số');
    assert.ok(ms >= 0, 'Khoảng cách ms phải không âm');
    assert.ok(ms <= 24 * 60 * 60 * 1000, 'Khoảng cách ms không vượt quá 24 giờ');
  });

  it('2. initScheduler khởi tạo thành công timerHandle mà không ném lỗi cú pháp', () => {
    const handle = initScheduler();
    assert.ok(handle, 'initScheduler phải trả về timerHandle hợp lệ');
  });

  it('3. stopScheduler dọn dẹp timerHandle an toàn mà không sinh lỗi', () => {
    assert.doesNotThrow(() => {
      stopScheduler();
    }, 'stopScheduler không được ném lỗi');
  });
});
