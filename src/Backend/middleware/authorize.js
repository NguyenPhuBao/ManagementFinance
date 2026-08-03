const ResponseHandler = require('../core/response-handler');

function authorize(...roles) {
  return (req, res, next) => {
    if (!req.user) {
      return ResponseHandler.unauthorized(res);
    }
    if (roles.length > 0 && !roles.includes(req.user.rolename)) {
      return ResponseHandler.forbidden(res, 'Insufficient permissions');
    }
    next();
  };
}

module.exports = authorize;
