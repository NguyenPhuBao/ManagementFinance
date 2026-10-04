const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const config = require('../config');
const logger = require('./logger');
const { getAccountValidity, accountRejection } = require('../middleware/auth');
const { createCorsOriginValidator } = require('../config/cors');

let io = null;

/**
 * Initialize Socket.io server
 * @param {import('http').Server} httpServer 
 */
function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: {
      origin: createCorsOriginValidator(config.cors.origin),
      credentials: true,
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
  });

  // Middleware xác thực JWT lúc bắt tay (Handshake Authentication)
  io.use(async (socket, next) => {
    try {
      const rawToken = socket.handshake.auth?.token || socket.handshake.headers?.authorization;
      if (!rawToken) {
        return next(new Error('Authentication error: Missing token'));
      }

      const token = rawToken.startsWith('Bearer ') ? rawToken.slice(7).trim() : rawToken.trim();
      let decoded;
      try {
        decoded = jwt.verify(token, config.jwt.accessSecret);
      } catch (err) {
        return next(new Error(`Authentication error: ${err.name === 'TokenExpiredError' ? 'Token expired' : 'Invalid token'}`));
      }

      const accountInfo = await getAccountValidity(decoded.idaccount);
      if (accountInfo.errorType === 'SCHEMA_ERROR') {
        // Không kèm data.code: đây không phải lý do của tài khoản
        return next(new Error('Authentication error: Service temporarily unavailable'));
      }
      const rejection = accountRejection(accountInfo, decoded.idaccount);
      if (rejection) {
        return next(Object.assign(new Error(`Authentication error: ${rejection.message}`), {
          data: rejection.data, // { code, idaccount, reason_inactive }
        }));
      }

      socket.data.idaccount = Number(decoded.idaccount);
      socket.data.idrole = Number(decoded.idrole);
      next();
    } catch (error) {
      logger.error('[Socket] Auth middleware error', { error: error.message });
      next(new Error('Authentication error: Internal server error'));
    }
  });

  io.on('connection', (socket) => {
    const { idaccount, idrole } = socket.data;
    logger.info(`[Socket] Authenticated client connected: ${socket.id} (idaccount=${idaccount}, idrole=${idrole})`);

    // Tự động gia nhập room cá nhân theo danh tính đã xác thực
    const userRoom = `account_${idaccount}`;
    socket.join(userRoom);
    logger.info(`[Socket] Client ${socket.id} joined room ${userRoom}`);

    // Nếu là Admin (idrole === 1), tự động gia nhập admin_room
    if (idrole === 1) {
      socket.join('admin_room');
      logger.info(`[Socket] Admin client ${socket.id} joined room admin_room`);
      socket.emit('joined_admin_room', {
        status: 'joined',
        room: 'admin_room',
        time: new Date().toISOString(),
      });
    }

    // Ping-pong liveness cho Admin-web
    socket.on('admin_ping', (ack) => {
      if (typeof ack === 'function') {
        ack({ pong: true, time: Date.now() });
      }
    });

    socket.on('disconnect', (reason) => {
      logger.info(`[Socket] Client disconnected: ${socket.id} (${reason})`);
    });
  });

  logger.info('Socket.io server initialized with JWT authentication');
  return io;
}

/**
 * Get Socket.io instance
 * @returns {import('socket.io').Server | null}
 */
function getIO() {
  return io;
}

/**
 * Emit a new audit activity to Admin Dashboard only (chỉ gửi tới admin_room)
 * @param {Object} activityData 
 */
function emitAuditActivity(activityData) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit audit activity before Socket.io initialized');
    return;
  }
  try {
    io.to('admin_room').emit('audit_activity', activityData);
    logger.debug('[Socket] Emitted audit_activity to admin_room', {
      user: activityData.user,
      action: activityData.action,
    });
  } catch (error) {
    logger.error('[Socket] Failed to emit audit_activity', { error: error.message });
  }
}

/**
 * Phát thông báo giao dịch ngân hàng mới tới Client-app của user
 * @param {number} idaccount 
 * @param {Object} txData 
 */
function emitBankTransaction(idaccount, txData) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit bank transaction before Socket.io initialized');
    return;
  }
  try {
    const room = `account_${idaccount}`;
    io.to(room).emit('bank_transaction.incoming', txData);
    logger.info(`[Socket] Emitted bank_transaction.incoming to room ${room}`, { idtran: txData.idtran });
  } catch (error) {
    logger.error('[Socket] Failed to emit bank transaction', { error: error.message });
  }
}

/**
 * Phát thông báo kết quả OCR tới Client-app của user
 * @param {number} idaccount 
 * @param {Object} ocrData 
 */
function emitOcrCompleted(idaccount, ocrData) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit ocr completed before Socket.io initialized');
    return;
  }
  try {
    const room = `account_${idaccount}`;
    io.to(room).emit('ocr.completed', ocrData);
    logger.info(`[Socket] Emitted ocr.completed to room ${room}`);
  } catch (error) {
    logger.error('[Socket] Failed to emit ocr completed', { error: error.message });
  }
}

/**
 * Phát thông báo giao dịch OCR bị trùng lặp tới Client-app của user
 * @param {number} idaccount 
 * @param {Object} duplicateData 
 */
function emitOcrDuplicate(idaccount, duplicateData) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit ocr duplicate before Socket.io initialized');
    return;
  }
  try {
    const room = `account_${idaccount}`;
    io.to(room).emit('ocr.duplicate', duplicateData);
    logger.info(`[Socket] Emitted ocr.duplicate to room ${room}`);
  } catch (error) {
    logger.error('[Socket] Failed to emit ocr duplicate', { error: error.message });
  }
}

/**
 * Phát thông báo cưỡng chế đăng xuất tới Client-app của user
 * @param {number} idaccount 
 * @param {string} reason 
 * @param {string} message 
 */
function emitForceLogout(idaccount, reason = 'ACCOUNT_DELETED', message = 'Tài khoản của bạn đã bị ngừng hoạt động hoặc xóa bởi quản trị viên.') {
  if (!io) {
    logger.warn('[Socket] Attempted to emit force logout before Socket.io initialized');
    return;
  }
  try {
    const room = `account_${idaccount}`;
    io.to(room).emit('account.force_logout', {
      idaccount: Number(idaccount),
      reason,
      message,
    });
    logger.info(`[Socket] Emitted account.force_logout to room ${room}`);

    // Disconnect all sockets in that room immediately
    if (typeof io.in(room).disconnectSockets === 'function') {
      io.in(room).disconnectSockets(true);
    }
  } catch (error) {
    logger.error('[Socket] Failed to emit force logout', { error: error.message });
  }
}

/**
 * Phát thông báo hoàn tất đồng bộ tới Client-app của user
 * @param {number} idaccount 
 * @param {Object} data 
 */
function emitSyncCompleted(idaccount, data) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit sync completed before Socket.io initialized');
    return;
  }
  try {
    const room = `account_${idaccount}`;
    io.to(room).emit('sync.completed', data);
    logger.info(`[Socket] Emitted sync.completed to room ${room}`);
  } catch (error) {
    logger.error('[Socket] Failed to emit sync completed', { error: error.message });
  }
}

/**
 * Phát cảnh báo hệ thống tới các Admin đang trực tuyến (admin_room)
 * @param {Object} notificationData 
 */
function emitAdminNotification(notificationData) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit admin notification before Socket.io initialized');
    return;
  }
  try {
    io.to('admin_room').emit('admin.notification', notificationData);
    logger.info('[Socket] Emitted admin.notification to admin_room', { title: notificationData.title });
  } catch (error) {
    logger.error('[Socket] Failed to emit admin notification', { error: error.message });
  }
}

/**
 * Phát thông báo Broadcast toàn hệ thống tới tất cả các client đang kết nối
 * @param {Object} broadcastData 
 */
function emitSystemBroadcast(broadcastData) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit system broadcast before Socket.io initialized');
    return;
  }
  try {
    io.emit('system.broadcast', broadcastData);
    logger.info('[Socket] Emitted system.broadcast to all connected clients', { title: broadcastData.title });
  } catch (error) {
    logger.error('[Socket] Failed to emit system broadcast', { error: error.message });
  }
}

/**
 * Phát sự kiện người dùng đăng ký mới tới admin_room
 * @param {Object} userData 
 */
function emitUserRegistered(userData) {
  if (!io) return;
  try {
    io.to('admin_room').emit('admin.user_registered', userData);
    logger.info('[Socket] Emitted admin.user_registered to admin_room', { username: userData.username });
  } catch (error) {
    logger.error('[Socket] Failed to emit admin.user_registered', { error: error.message });
  }
}

/**
 * Phát sự kiện người dùng đăng nhập thành công tới admin_room (cập nhật biểu đồ login)
 * @param {Object} loginData 
 */
function emitUserLoggedIn(loginData) {
  if (!io) return;
  try {
    io.to('admin_room').emit('admin.user_logged_in', loginData);
    logger.debug('[Socket] Emitted admin.user_logged_in to admin_room', { idaccount: loginData.idaccount });
  } catch (error) {
    logger.error('[Socket] Failed to emit admin.user_logged_in', { error: error.message });
  }
}

/**
 * Phát sự kiện thay đổi trạng thái người dùng (Active, Inactive, PendingDelete)
 * @param {Object} statusData 
 */
function emitUserStatusChanged(statusData) {
  if (!io) return;
  try {
    io.to('admin_room').emit('admin.user_status_changed', statusData);
    logger.info('[Socket] Emitted admin.user_status_changed to admin_room', { idaccount: statusData.idaccount, status: statusData.status });
  } catch (error) {
    logger.error('[Socket] Failed to emit admin.user_status_changed', { error: error.message });
  }
}

/**
 * Phát sự kiện thay đổi danh mục (thêm, sửa, xóa) tới admin_room
 * @param {Object} categoryData 
 */
function emitCategoryUpdated(categoryData) {
  if (!io) return;
  try {
    io.to('admin_room').emit('admin.category_updated', categoryData);
    logger.info('[Socket] Emitted admin.category_updated to admin_room', { action: categoryData.action });
  } catch (error) {
    logger.error('[Socket] Failed to emit admin.category_updated', { error: error.message });
  }
}

/**
 * Phát sự kiện thay đổi trạng thái bảo trì hệ thống tới admin_room và toàn bộ client
 * @param {Object} maintenanceStatus 
 */
function emitMaintenanceChanged(maintenanceStatus) {
  if (!io) return;
  try {
    io.to('admin_room').emit('admin.maintenance_changed', maintenanceStatus);
    io.emit('system.maintenance_changed', maintenanceStatus);
    logger.info('[Socket] Emitted maintenance_changed', { active: maintenanceStatus.active, isEmergency: maintenanceStatus.isEmergency });
  } catch (error) {
    logger.error('[Socket] Failed to emit maintenance_changed', { error: error.message });
  }
}

/**
 * Phát luồng nhịp tim thông số phần cứng & sức tải (3s/lần) tới admin_room
 * @param {Object} metrics 
 */
function emitSystemMetricsStream(metrics) {
  if (!io) return;
  try {
    io.to('admin_room').emit('admin.metrics_stream', metrics);
  } catch (error) {
    logger.error('[Socket] Failed to emit admin.metrics_stream', { error: error.message });
  }
}

/**
 * Helper hỗ trợ mock IO trong unit test
 */
function _setMockIO(mockInstance) {
  io = mockInstance;
}

module.exports = {
  initSocket,
  getIO,
  _setMockIO,
  emitAuditActivity,
  emitBankTransaction,
  emitOcrCompleted,
  emitOcrDuplicate,
  emitForceLogout,
  emitSyncCompleted,
  emitAdminNotification,
  emitSystemBroadcast,
  emitUserRegistered,
  emitUserLoggedIn,
  emitUserStatusChanged,
  emitCategoryUpdated,
  emitMaintenanceChanged,
  emitSystemMetricsStream,
};



