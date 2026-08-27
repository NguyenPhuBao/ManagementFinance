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

module.exports = {
  initSocket,
  getIO,
  emitAuditActivity,
};
