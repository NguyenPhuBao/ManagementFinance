const express = require('express');
const router = express.Router();
const policyController = require('../modules/policy/policy.controller');
const { authenticate } = require('../middleware/auth');

router.use(authenticate);

router.get('/current', policyController.current);
router.post('/accept', policyController.accept);

module.exports = router;
