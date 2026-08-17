const VALID_ENTITIES = ['wallet', 'transaction', 'budget', 'bill', 'goal', 'category'];
const VALID_OPERATIONS = ['create', 'update', 'delete'];

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isValidUUID(str) {
  return typeof str === 'string' && UUID_REGEX.test(str);
}

function isValidISO(str) {
  if (typeof str !== 'string') return false;
  const d = new Date(str);
  return d instanceof Date && !isNaN(d) && str === d.toISOString();
}

/**
 * Validate POST /api/sync/push body
 */
function validatePush(body) {
  const errors = [];

  if (!body || typeof body !== 'object') {
    return { valid: false, errors: ['Request body is required'] };
  }

  // clientId
  if (!body.clientId || typeof body.clientId !== 'string' || body.clientId.length < 1) {
    errors.push('clientId is required (string)');
  }

  // pushedAt
  if (!body.pushedAt) {
    errors.push('pushedAt is required (ISO datetime)');
  } else if (!isValidISO(body.pushedAt)) {
    errors.push('pushedAt must be a valid ISO 8601 datetime string');
  }

  // operations
  if (!Array.isArray(body.operations)) {
    errors.push('operations is required (array)');
  } else if (body.operations.length === 0) {
    errors.push('operations must not be empty');
  } else if (body.operations.length > 1000) {
    errors.push('operations limit exceeded (max 1000 per batch)');
  } else {
    body.operations.forEach((op, i) => {
      const prefix = `operations[${i}]`;

      if (!op.localId || typeof op.localId !== 'string') {
        errors.push(`${prefix}.localId is required (string)`);
      }

      if (!op.entity || !VALID_ENTITIES.includes(op.entity)) {
        errors.push(`${prefix}.entity must be one of: ${VALID_ENTITIES.join(', ')}`);
      }

      if (!op.operation || !VALID_OPERATIONS.includes(op.operation)) {
        errors.push(`${prefix}.operation must be one of: ${VALID_OPERATIONS.join(', ')}`);
      }

      if (!op.payload || typeof op.payload !== 'object') {
        errors.push(`${prefix}.payload is required (object)`);
      } else {
        // Validate UUID for entity id
        if (!isValidUUID(op.payload.id)) {
          errors.push(`${prefix}.payload.id must be a valid UUID`);
        }

        // Validate idaccount exists
        if (op.payload.idaccount === undefined || op.payload.idaccount === null) {
          errors.push(`${prefix}.payload.idaccount is required`);
        }

        // Validate updated_at for LWW
        if (!op.payload.updated_at) {
          errors.push(`${prefix}.payload.updated_at is required`);
        } else if (!isValidISO(op.payload.updated_at)) {
          errors.push(`${prefix}.payload.updated_at must be a valid ISO 8601 datetime`);
        }

        // For category: validate classify if provided
        if (op.entity === 'category' && op.payload.classify) {
          if (!['thu', 'chi', 'vay/no'].includes(op.payload.classify)) {
            errors.push(`${prefix}.payload.classify must be thu/chi/vay-no`);
          }
        }

        // For transaction: validate type if provided
        if (op.entity === 'transaction') {
          if (op.payload.type && !['thu', 'chi', 'transfer', 'adjustment'].includes(op.payload.type)) {
            errors.push(`${prefix}.payload.type must be thu/chi/transfer/adjustment`);
          }
          if (op.payload.provider && !['manual', 'casso'].includes(op.payload.provider)) {
            errors.push(`${prefix}.payload.provider must be manual/casso`);
          }
        }
      }
    });
  }

  return { valid: errors.length === 0, errors };
}

/**
 * Validate GET /api/sync/pull query params
 */
function validatePull(query) {
  const errors = [];

  if (!query.since) {
    errors.push('since is required (ISO datetime)');
  } else if (!isValidISO(query.since)) {
    errors.push('since must be a valid ISO 8601 datetime string');
  }

  if (query.entities) {
    const list = query.entities.split(',').map(e => e.trim()).filter(Boolean);
    const invalid = list.filter(e => !VALID_ENTITIES.includes(e));
    if (invalid.length > 0) {
      errors.push(`Invalid entities: ${invalid.join(', ')}. Valid: ${VALID_ENTITIES.join(', ')}`);
    }
  }

  return { valid: errors.length === 0, errors };
}

module.exports = { validatePush, validatePull, isValidUUID, VALID_ENTITIES };
