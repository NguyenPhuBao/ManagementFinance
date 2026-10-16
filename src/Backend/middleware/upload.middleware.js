const multer = require('multer');
const path = require('path');
const fs = require('fs');

const refundsDir = path.join(__dirname, '../Assets/Refunds');
if (!fs.existsSync(refundsDir)) {
  fs.mkdirSync(refundsDir, { recursive: true });
}

const refundStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, refundsDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase() || '.png';
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const orderId = req.params?.id ? req.params.id.slice(0, 8) : 'proof';
    cb(null, `refund-${orderId}-${uniqueSuffix}${ext}`);
  },
});

const refundFileFilter = (req, file, cb) => {
  const allowedExts = ['.jpg', '.jpeg', '.png', '.webp', '.pdf'];
  const ext = path.extname(file.originalname || '').toLowerCase();
  if (allowedExts.includes(ext) || file.mimetype?.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('Chỉ chấp nhận các tệp hình ảnh (.jpg, .jpeg, .png, .webp) hoặc .pdf'));
  }
};

const uploadRefundProof = multer({
  storage: refundStorage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: refundFileFilter,
});

module.exports = {
  uploadRefundProof,
};
