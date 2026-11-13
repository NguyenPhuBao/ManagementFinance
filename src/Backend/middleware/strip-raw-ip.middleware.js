const { stripRawIp } = require('../utils/ip-protection.util');

function stripRawIpResponse(req, res, next) {
  const json = res.json.bind(res);
  res.json = (body) => json(stripRawIp(body));
  next();
}

module.exports = { stripRawIpResponse };
