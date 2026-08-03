const ResponseHandler = require('../core/response-handler');

function validate(schema, source = 'body') {
  return (req, res, next) => {
    const data = req[source];
    const errors = [];

    for (const [field, rules] of Object.entries(schema)) {
      const value = data[field];

      if (rules.required && (value === undefined || value === null || value === '')) {
        errors.push({ field, message: `${field} is required` });
        continue;
      }

      if (value !== undefined && value !== null) {
        if (rules.type && typeof value !== rules.type) {
          errors.push({ field, message: `${field} must be of type ${rules.type}` });
        }
        if (rules.minLength && String(value).length < rules.minLength) {
          errors.push({ field, message: `${field} must be at least ${rules.minLength} characters` });
        }
        if (rules.maxLength && String(value).length > rules.maxLength) {
          errors.push({ field, message: `${field} must be at most ${rules.maxLength} characters` });
        }
        if (rules.pattern && !rules.pattern.test(String(value))) {
          errors.push({ field, message: rules.patternMessage || `${field} format is invalid` });
        }
      }
    }

    if (errors.length > 0) {
      return ResponseHandler.badRequest(res, 'Validation failed', errors);
    }
    next();
  };
}

module.exports = validate;
