const syncService = require('./sync.service');
const { validatePush, validatePull } = require('./sync.validation');
const ResponseHandler = require('../../core/response-handler');
const logger = require('../../core/logger');

const syncController = {
  /**
   * POST /api/sync/push
   * Nhận batch operations từ client, xử lý LWW conflict resolution
   */
  async push(req, res) {
    try {
      const { valid, errors } = validatePush(req.body);
      if (!valid) {
        return ResponseHandler.badRequest(res, 'Validation failed', errors);
      }

      const { clientId, operations } = req.body;
      const idaccount = req.user.idaccount;

      logger.info('Sync push received', { idaccount, clientId, count: operations.length });

      const { results, summary } = await syncService.processPush(idaccount, operations);

      return ResponseHandler.success(res, {
        clientId,
        results,
        summary,
        serverTime: new Date().toISOString(),
      }, `Sync push completed: ${summary.synced} synced, ${summary.conflicts} conflicts, ${summary.errors} errors`);
    } catch (error) {
      logger.error('Sync push failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  /**
   * GET /api/sync/pull?since=ISO&entities=wallet,transaction
   * Trả về records mới/cập nhật cho client
   */
  async pull(req, res) {
    try {
      const { valid, errors } = validatePull(req.query);
      if (!valid) {
        return ResponseHandler.badRequest(res, 'Validation failed', errors);
      }

      const idaccount = req.user.idaccount;
      const { since, entities: entitiesParam } = req.query;
      const entities = entitiesParam ? entitiesParam.split(',').map(e => e.trim()).filter(Boolean) : null;

      logger.info('Sync pull requested', { idaccount, since: since?.substring(0, 19), entities });

      const result = await syncService.processPull(idaccount, since, entities);

      return ResponseHandler.success(res, result, `Sync pull: ${Object.values(result.data).reduce((sum, arr) => sum + arr.length, 0)} records`);
    } catch (error) {
      logger.error('Sync pull failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },

  /**
   * GET /api/sync/status
   * Trạng thái đồng bộ của user
   */
  async status(req, res) {
    try {
      const idaccount = req.user.idaccount;
      const result = await syncService.getStatus(idaccount);
      return ResponseHandler.success(res, result, 'Sync status');
    } catch (error) {
      logger.error('Sync status failed', { error: error.message });
      return ResponseHandler.error(res, error.message);
    }
  },
};

module.exports = syncController;
