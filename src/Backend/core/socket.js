const { Server } = require('socket.io');
const config = require('../config');
const logger = require('./logger');

let io = null;

/**
 * Initialize Socket.io server
 * @param {import('http').Server} httpServer 
 */
function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: {
      origin: config.cors.origin || true,
      credentials: true,
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
  });

  io.on('connection', (socket) => {
    logger.info(`[Socket] Client connected: ${socket.id}`);

    // Cho phép client join room theo idaccount để nhận thông báo riêng tư
    socket.on('join_account', (idaccount) => {
      if (idaccount) {
        const room = `account_${idaccount}`;
        socket.join(room);
        logger.info(`[Socket] Client ${socket.id} joined room ${room}`);
      }
    });

    socket.on('disconnect', (reason) => {
      logger.info(`[Socket] Client disconnected: ${socket.id} (${reason})`);
    });
  });

  logger.info('Socket.io server initialized');
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
 * Emit a new audit activity to all connected clients (Admin Dashboard)
 * @param {Object} activityData 
 */
function emitAuditActivity(activityData) {
  if (!io) {
    logger.warn('[Socket] Attempted to emit audit activity before Socket.io initialized');
    return;
  }
  try {
    io.emit('audit_activity', activityData);
    logger.debug('[Socket] Emitted audit_activity', {
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
    // Đồng thời phát chung để client đang ở chế độ broadcast cũng nhận được
    io.emit(`bank_transaction:${idaccount}`, txData);
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
    io.emit(`ocr_completed:${idaccount}`, ocrData);
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
    io.emit(`ocr_duplicate:${idaccount}`, duplicateData);
    logger.info(`[Socket] Emitted ocr.duplicate to room ${room}`);
  } catch (error) {
    logger.error('[Socket] Failed to emit ocr duplicate', { error: error.message });
  }
}

module.exports = {
  initSocket,
  getIO,
  emitAuditActivity,
  emitBankTransaction,
  emitOcrCompleted,
  emitOcrDuplicate,
};

