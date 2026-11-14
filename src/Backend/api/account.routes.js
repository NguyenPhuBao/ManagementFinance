const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const dataExportController = require('../modules/account/data-export.controller');

router.use(authenticate);
router.post('/data-export', dataExportController.request);
router.get('/data-export/latest', dataExportController.latest);
router.get('/data-export/:id/download', dataExportController.download);

module.exports = router;
