// GHI CHÚ QUAN TRỌNG: Đổi CHECK nào trên CSDL thì đổi tập giá trị tương ứng ở đây trong cùng commit.

const VALID_ENTITIES = [
  'wallet',
  'transaction',
  'budget',
  'bill',
  'goal',
  'category',
];
const VALID_OPERATIONS = ['create', 'update', 'delete'];

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isValidUUID(str) {
  return typeof str === 'string' && UUID_REGEX.test(str);
}

function isValidISO(str) {
  if (typeof str !== 'string') return false;
  // Match ISO 8601 datetime formats: YYYY-MM-DDTHH:mm:ss(.sss)?(Z|[+-]HH:mm)?
  const isoRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:?\d{2})$/i;
  if (!isoRegex.test(str)) return false;
  const d = new Date(str);
  return d instanceof Date && !isNaN(d.getTime());
}

const ENTITY_PK_MAP = {
  wallet: 'idwallet',
  transaction: 'idtran',
  budget: 'idbudget',
  bill: 'idbill',
  goal: 'idgoal',
  category: 'idcategory',
};

/**
 * Validate POST /api/sync/push body ở mức CẢ LÔ (Batch-level)
 * Giữ 400 cho lỗi cấu trúc toàn lô khiến server không thể xử lý từng thao tác
 */
function validateBatch(body) {
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
    for (let i = 0; i < body.operations.length; i++) {
      const op = body.operations[i];
      if (!op || typeof op !== 'object' || !op.localId || typeof op.localId !== 'string') {
        errors.push(`operations[${i}].localId is required (string)`);
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

/**
 * Validate một thao tác riêng lẻ (Operation-level)
 * Lỗi ở mức thao tác được ghi nhận vào results[i] với CONSTRAINT_VIOLATION thay vì trả 400 cả lô
 */
function validateOperation(op) {
  const errors = [];

  if (!op || typeof op !== 'object') {
    return { valid: false, errors: ['Operation must be an object'] };
  }

  if (!op.entity || !VALID_ENTITIES.includes(op.entity)) {
    errors.push(`entity must be one of: ${VALID_ENTITIES.join(', ')}`);
  }

  if (!op.operation || !VALID_OPERATIONS.includes(op.operation)) {
    errors.push(`operation must be one of: ${VALID_OPERATIONS.join(', ')}`);
  }

  if (!op.payload || typeof op.payload !== 'object') {
    errors.push('payload is required (object)');
    return { valid: false, errors };
  }

  // Resolve entity ID from payload.id or exact entity PK field
  const pkField = ENTITY_PK_MAP[op.entity];
  const entityId = op.payload.id || (pkField && op.payload[pkField]);

  if (!entityId || !isValidUUID(entityId)) {
    errors.push(`payload.id (or ${pkField || 'PK'}) must be a valid UUID`);
  } else {
    op.payload.id = entityId; // Normalize to payload.id
  }

  // Đối với thao tác xoá (delete), chỉ cần entity và id hợp lệ
  if (op.operation === 'delete') {
    return { valid: errors.length === 0, errors };
  }

  // Validate idaccount nếu có gửi; nếu thiếu sync.service sẽ tự gán idaccount từ JWT
  if (op.payload.idaccount !== undefined && op.payload.idaccount !== null && isNaN(Number(op.payload.idaccount))) {
    errors.push('payload.idaccount must be a valid number');
  }

  // Validate update_at for LWW nếu có; nếu thiếu repository sẽ tự gán new Date()
  const updateAtVal = op.payload.update_at || op.payload.updatedAt;
  if (updateAtVal && !isValidISO(updateAtVal)) {
    errors.push('payload.update_at must be a valid ISO 8601 datetime');
  }

  // For category: validate classify if provided (Thu, Chi, Vay/no)
  if (op.entity === 'category' && op.payload.classify) {
    const c = String(op.payload.classify).trim();
    if (['Vay/nợ', 'Vay', 'no', 'vay_no', 'vay_nợ', 'Vay/ng'].includes(c)) {
      op.payload.classify = 'Vay/no';
    }
    const validClassify = ['Thu', 'Chi', 'Vay/no'];
    if (!validClassify.includes(op.payload.classify)) {
      errors.push('payload.classify must be Thu, Chi, or Vay/no');
    }
  }

  // For transaction: validate type + provider if provided
  if (op.entity === 'transaction') {
    if (op.payload.type) {
      if (['Expense', 'Income', 'Debt', 'Loan'].includes(op.payload.type)) {
        op.payload.type = 'Transaction';
      }
      const validTypes = ['Transaction', 'Transfer'];
      if (!validTypes.includes(op.payload.type)) {
        errors.push('payload.type must be Transaction or Transfer');
      }
    }
    if (op.payload.provider) {
      if (op.payload.provider === 'ORC') op.payload.provider = 'OCR';
      const validProviders = ['Manual', 'BankSync', 'Casso', 'SMS', 'OCR', 'Bill'];
      if (!validProviders.includes(op.payload.provider)) {
        errors.push('payload.provider must be Manual/BankSync/Casso/SMS/OCR/Bill');
      }
    }
    if (op.payload.status) {
      const validTxStatuses = ['Pending', 'Confirmed', 'Rejected', 'Fail'];
      if (!validTxStatuses.includes(op.payload.status)) {
        errors.push('payload.status must be Pending/Confirmed/Rejected/Fail');
      }
    }
  }

  // For bill: validate pay_status if provided (Hỗ trợ Skipped theo Migration 12)
  if (op.entity === 'bill' && op.payload.pay_status !== undefined && typeof op.payload.pay_status === 'string') {
    const validStatuses = ['Pending', 'Payed', 'Overdue', 'Skipped'];
    if (!validStatuses.includes(op.payload.pay_status)) {
      errors.push('payload.pay_status must be Pending, Payed, Overdue, or Skipped');
    }
  }

  // For budget: validate over_spending if provided
  if (op.entity === 'budget' && op.payload.over_spending) {
    const validOver = ['Stop', 'Over'];
    if (!validOver.includes(op.payload.over_spending)) {
      errors.push('payload.over_spending must be Stop or Over');
    }
  }

  return { valid: errors.length === 0, errors };
}

/**
 * Validate POST /api/sync/push body (Batch check)
 */
function validatePush(body) {
  return validateBatch(body);
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

module.exports = {
  validatePush,
  validateBatch,
  validateOperation,
  validatePull,
  isValidUUID,
  VALID_ENTITIES,
};

