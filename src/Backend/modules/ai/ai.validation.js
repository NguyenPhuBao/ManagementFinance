/**
 * AI Module — Shared Validation
 * Validate input cho tất cả AI endpoints.
 */

const classifySchema = {
  transactionId: { required: true, type: 'string', minLength: 1, maxLength: 36 },
};

module.exports = { classifySchema };
