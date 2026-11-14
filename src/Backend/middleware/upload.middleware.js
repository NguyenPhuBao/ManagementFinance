const multer = require('multer');
const path = require('path');

const REFUND_EXTS = ['.jpg', '.jpeg', '.png', '.webp', '.pdf'];

const refundFileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (REFUND_EXTS.includes(ext) || file.mimetype?.startsWith('image/') || file.mimetype === 'application/pdf') {
    cb(null, true);
  } else {
    cb(new Error('Chỉ chấp nhận các tệp hình ảnh (.jpg, .jpeg, .png, .webp) hoặc .pdf'));
  }
};

const uploadRefundProof = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1 },
  fileFilter: refundFileFilter,
});

module.exports = {
  uploadRefundProof,
};
