const logger = require('../../core/logger');
const adminService = require('./admin.service');
const service = require('./data-incident.service');

const ACTION_NAMES = {
  contain: 'Ghi nhận đã ngăn chặn sự cố dữ liệu',
  report: 'Ghi nhận đã báo cơ quan chuyên trách sự cố dữ liệu',
  'notify-users': 'Ghi nhận đã báo người dùng về sự cố dữ liệu',
  close: 'Đóng sự cố dữ liệu',
};

const fail = (res, error) => {
  const status = error.statusCode || 500;
  if (status >= 500) logger.error('[DataIncident] Lỗi', { error: error.message });
  return res.status(status).json({ success: false, code: error.code || 'DATA_INCIDENT_ERROR', message: error.message });
};

const dataIncidentController = {
  async list(req, res) {
    try {
      const data = await service.listIncidents({ status: req.query?.status });
      return res.status(200).json({ success: true, data });
    } catch (error) {
      return fail(res, error);
    }
  },

  async create(req, res) {
    try {
      req.auditActionName = 'Mở sự cố dữ liệu';
      const row = await service.createIncident(req.body || {}, req.user?.idaccount);
      req.auditActionName = `Mở sự cố dữ liệu ${row.code}`;
      return res.status(201).json({ success: true, data: service.toView(row) });
    } catch (error) {
      return fail(res, error);
    }
  },

  async update(req, res) {
    try {
      const row = await service.updateIncident(req.params.id, req.body || {}, req.user?.idaccount);
      req.auditActionName = `Cập nhật sự cố dữ liệu ${row.code}`;
      return res.status(200).json({ success: true, data: service.toView(row) });
    } catch (error) {
      return fail(res, error);
    }
  },

  async action(req, res) {
    const { id, action } = req.params;
    req.auditActionName = `${ACTION_NAMES[action] || 'Thao tác sự cố dữ liệu'} #${id}`;
    try {
      const body = req.body || {};
      if (action === 'close') {
        await adminService.verifySecurityAction({ pin: body.pin, password: body.password, action: 'CLOSE_DATA_INCIDENT', targetId: `data-incident#${id}` }, req.user);
      }
      const row = await service.runAction(id, action, body, req.user?.idaccount);
      req.auditActionName = `${ACTION_NAMES[action]} ${row.code}`;
      return res.status(200).json({ success: true, data: service.toView(row) });
    } catch (error) {
      return fail(res, error);
    }
  },
};

module.exports = dataIncidentController;
