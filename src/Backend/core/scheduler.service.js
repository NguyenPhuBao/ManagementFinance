const { prisma } = require('../config/db');
const logger = require('./logger');

/**
 * Tính số milliseconds từ thời điểm hiện tại tới 00:00:00 múi giờ Việt Nam (UTC+7) tiếp theo.
 */
function getMsUntilNextMidnightVietnam() {
  const now = new Date();
  // Chuyển sang thời gian UTC
  const utc = now.getTime() + (now.getTimezoneOffset() * 60000);
  // Chuyển sang giờ Việt Nam (UTC+7)
  const vnTime = new Date(utc + (3600000 * 7));

  // Tính 00:00:00 tiếp theo của ngày mai tại VN
  const nextMidnightVn = new Date(vnTime);
  nextMidnightVn.setHours(24, 0, 0, 0);

  const diffMs = nextMidnightVn.getTime() - vnTime.getTime();
  return diffMs;
}

let timerHandle = null;

/**
 * Thực thi quy trình xóa mềm toàn diện cho một tài khoản (tương tự adminService.deleteUser)
 * @param {number} idaccount 
 */
async function processFullSoftDelete(idaccount) {
  const now = new Date();
  const account = await prisma.account.findUnique({
    where: { idaccount },
    include: { User: true },
  });

  if (!account) return;

  await prisma.$transaction(async (tx) => {
    // 1. Cập nhật bảng account -> Status = 'Deleted', Countdown = 0, Delete_at = now()
    await tx.account.update({
      where: { idaccount },
      data: {
        status: 'Deleted',
        countdown: 0,
        delete_at: now,
        update_at: now,
      },
    });

    // 2. Cập nhật bảng user -> Delete_at = now()
    if (account.User) {
      await tx.user.update({
        where: { idaccount },
        data: {
          delete_at: now,
          update_at: now,
        },
      });
    }

    // 3. Toàn bộ ví liên quan ngừng hoạt động -> status = 'Inactive'
    await tx.wallet.updateMany({
      where: { idaccount },
      data: {
        status: 'Inactive',
        update_at: now,
      },
    });

    // 4. Ngắt kết nối ngân hàng -> connect_status = 'Disconnected'
    await tx.bank_account.updateMany({
      where: { idaccount },
      data: {
        connect_status: 'Disconnected',
      },
    });

    // 5. Thu hồi toàn bộ Refresh Token -> Status = true
    await tx.refreshtoken.updateMany({
      where: { idaccount, status: false },
      data: {
        status: true,
        update_at: now,
      },
    });
  });

  // Thu hồi cache xác thực bộ nhớ
  const { invalidateAccountCache } = require('../middleware/auth');
  invalidateAccountCache(idaccount);

  // Phát sự kiện cưỡng chế đăng xuất real-time qua Socket.IO
  try {
    const { emitForceLogout } = require('./socket');
    emitForceLogout(
      idaccount,
      'ACCOUNT_DELETED',
      'Tài khoản của bạn đã hết thời hạn 30 ngày chờ xóa và đã được xóa khỏi hệ thống.'
    );
  } catch (socketErr) {
    logger.warn('Socket force logout error during scheduled deletion', { idaccount, error: socketErr.message });
  }

  logger.info('Scheduled account deletion completed successfully', { idaccount });
}

/**
 * Tác vụ chạy hàng ngày lúc 00:00:00 UTC+7:
 * - Giảm countdown đi 1 cho các tài khoản PendingDelete
 * - Xóa mềm các tài khoản countdown về 0
 */
async function runDailyCountdownTask() {
  logger.info('=== BẮT ĐẦU CHẠY DAILY COUNTDOWN TASK (0h00 UTC+7) ===');
  try {
    const pendingAccounts = await prisma.account.findMany({
      where: {
        status: 'PendingDelete',
        countdown: { gt: 0 },
      },
      select: {
        idaccount: true,
        username: true,
        countdown: true,
      },
    });

    logger.info(`Tìm thấy ${pendingAccounts.length} tài khoản PendingDelete cần cập nhật`);

    for (const acc of pendingAccounts) {
      const nextCountdown = acc.countdown - 1;

      if (nextCountdown <= 0) {
        // Hết 30 ngày -> Thực thi xóa mềm
        logger.info(`Tài khoản ${acc.username} (id: ${acc.idaccount}) countdown về 0 -> Kích hoạt xóa mềm`, { idaccount: acc.idaccount });
        await processFullSoftDelete(acc.idaccount);
      } else {
        // Giảm countdown
        await prisma.account.update({
          where: { idaccount: acc.idaccount },
          data: {
            countdown: nextCountdown,
            update_at: new Date(),
          },
        });
        const { invalidateAccountCache } = require('../middleware/auth');
        invalidateAccountCache(acc.idaccount);
        logger.info(`Tài khoản ${acc.username} giảm countdown còn ${nextCountdown} ngày`, { idaccount: acc.idaccount, countdown: nextCountdown });
      }
    }

    logger.info('=== HOÀN TẤT DAILY COUNTDOWN TASK ===');
  } catch (error) {
    logger.error('Lỗi khi thực thi runDailyCountdownTask', { error: error.message, stack: error.stack });
  }
}

/**
 * Khởi động scheduler lập lịch chạy tự động lúc 00:00:00 UTC+7 mỗi ngày
 */
function initScheduler() {
  const msUntilMidnight = getMsUntilNextMidnightVietnam();
  const hours = (msUntilMidnight / 3600000).toFixed(2);
  logger.info(`Scheduler: Task đếm ngược 0h00 (Asia/Ho_Chi_Minh) sẽ chạy sau ${hours} giờ (${msUntilMidnight} ms)`);

  timerHandle = setTimeout(async () => {
    try {
      await runDailyCountdownTask();
    } catch (err) {
      logger.error('Lỗi trong runDailyCountdownTask callback', { error: err.message });
    }
    // Lên lịch đệ quy cho ngày tiếp theo
    initScheduler();
  }, msUntilMidnight);

  return timerHandle;
}

function stopScheduler() {
  if (timerHandle) {
    clearTimeout(timerHandle);
    timerHandle = null;
    logger.info('Scheduler: Đã dừng scheduler');
  }
}

module.exports = {
  getMsUntilNextMidnightVietnam,
  runDailyCountdownTask,
  processFullSoftDelete,
  initScheduler,
  stopScheduler,
};
