/**
 * Unit Test — Process Safety: Bẫy lỗi toàn cục uncaughtException & unhandledRejection (TDD)
 */

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { handleUncaughtException, handleUnhandledRejection, formatCrashReport } = require('../../core/resilience/process-safety');

describe('Resilience — Bẫy lỗi toàn cục (Global Process Exception Handlers)', () => {
  it('1. formatCrashReport trả về thông tin chi tiết đầy đủ khi gặp lỗi', () => {
    const error = new Error('Test unhandled crash');
    const report = formatCrashReport(error, 'uncaughtException');

    assert.strictEqual(report.type, 'uncaughtException');
    assert.strictEqual(report.message, 'Test unhandled crash');
    assert.ok(report.stack, 'Phải có stack trace');
    assert.ok(report.timestamp, 'Phải có timestamp ISO');
  });

  it('2. handleUncaughtException gọi callback onCrash và không để lỗi lọt ra ngoài làm sập im lặng', () => {
    let crashReported = null;
    let exitCode = null;

    const fakeError = new Error('Fatal database connection error');
    const mockOnCrash = (report) => {
      crashReported = report;
    };
    const mockExit = (code) => {
      exitCode = code;
    };

    handleUncaughtException(fakeError, { onCrash: mockOnCrash, exitFn: mockExit });

    assert.ok(crashReported, 'Phải ghi nhận crash report');
    assert.strictEqual(crashReported.message, 'Fatal database connection error');
    assert.strictEqual(exitCode, 1, 'Mã thoát tiến trình an toàn phải là 1');
  });

  it('3. handleUnhandledRejection ghi log cảnh báo và không làm crash tiến trình ngay lập tức nếu chưa fatal', () => {
    let warningLogged = null;
    const fakeReason = new Error('Unhandled Promise in async worker');
    const mockLogger = {
      error: (msg, meta) => {
        warningLogged = { msg, meta };
      },
    };

    handleUnhandledRejection(fakeReason, null, { logger: mockLogger });

    assert.ok(warningLogged, 'Phải ghi log lỗi');
    assert.strictEqual(warningLogged.msg, '[PROCESS SAFETY] Unhandled Promise Rejection phát hiện');
    assert.strictEqual(warningLogged.meta.message, 'Unhandled Promise in async worker');
  });
});
