/**
 * F012 — Transaction Classifier — Type Detector (Cấp 1)
 * Phân loại Loại giao dịch: 'Transfer' (Chuyển tiền nội bộ) vs 'Transaction' (Thu/Chi mua bán)
 * Áp dụng nghiêm ngặt 3 Cơ sở đối soát CSDL:
 * 1. items (có danh sách món hàng -> 100% Transaction)
 * 2. destination_name trùng User.fullname HOẶC destination_account trùng Wallet.account_number -> 100% Transfer
 * 3. Từ khóa nội bộ trong note/content -> Transfer
 */

const { removeVietnameseTones } = require('../classify.preprocess');

const INTERNAL_TRANSFER_KEYWORDS = [
  'chuyen tien sang vi',
  'chuyen sang vi',
  'chuyen vi',
  'nap vi',
  'nap tien vi',
  'nap tien tai khoan',
  'nap tien vao tai khoan',
  'tiet kiem',
  'chuyen khoan noi bo',
  'chuyen tien noi bo',
  'rut vi',
  'cashin',
  'chuyen sang tech',
  'chuyen sang vcb',
  'chuyen sang mbbank',
  'chuyen sang momo',
  'chuyen tien tiet kiem'
];

const typeDetector = {
  /**
   * Phân loại Loại giao dịch (Transaction vs Transfer)
   * @param {object} params
   * @param {Array} params.items - Danh sách mặt hàng (từ OCR hóa đơn)
   * @param {string} params.destination_name - Tên người nhận
   * @param {string} params.destination_account - STK người nhận
   * @param {string} params.source_account - STK người gửi
   * @param {string} params.note - Nội dung giao dịch / chuyển khoản
   * @param {string} params.text - Chuỗi diễn giải thô
   * @param {object} params.userProfile - Thông tin user { idaccount, fullname, email }
   * @param {Array} params.userWallets - Danh sách ví của user kèm bank_account
   * @returns {{ type: 'Transaction' | 'Transfer', confidence: number, reason: string, destination_wallet_id?: string, source_wallet_id?: string }}
   */
  detectType({
    items = [],
    destination_name = '',
    destination_account = '',
    source_account = '',
    note = '',
    text = '',
    userProfile = null,
    userWallets = [],
    bankAccounts = []
  }) {
    // =========================================================================
    // CƠ SỞ 1: Sự xuất hiện của danh sách mặt hàng (items)
    // Nếu có mảng items từ hóa đơn -> 100% là Transaction (Chi tiêu)
    // =========================================================================
    if (Array.isArray(items) && items.length > 0) {
      return {
        type: 'Transaction',
        confidence: 1.0,
        reason: 'has_invoice_items'
      };
    }

    const normalizedDestName = removeVietnameseTones(destination_name || '').toLowerCase().trim();
    const normalizedDestAccount = String(destination_account || '').replace(/[\s-]/g, '').trim();
    const normalizedSourceAccount = String(source_account || '').replace(/[\s-]/g, '').trim();

    // Xác định ví nguồn (nếu có source_account)
    let sourceWallet = null;
    if (normalizedSourceAccount && Array.isArray(userWallets)) {
      sourceWallet = userWallets.find((w) => {
        const accNo = String(w.bank_account?.account_number || '').replace(/[\s-]/g, '').trim();
        return accNo && accNo === normalizedSourceAccount;
      });
    }

    // =========================================================================
    // CƠ SỞ 2a: Đối soát STK nhận với danh sách ví và tài khoản ngân hàng của user
    // Nếu STK nhận nằm trong ví hoặc bank_account của user -> 100% là Transfer nội bộ
    // =========================================================================
    if (normalizedDestAccount) {
      if (Array.isArray(userWallets) && userWallets.length > 0) {
        const matchedDestWallet = userWallets.find((w) => {
          const accNo = String(w.bank_account?.account_number || '').replace(/[\s-]/g, '').trim();
          return accNo && accNo === normalizedDestAccount;
        });

        if (matchedDestWallet) {
          return {
            type: 'Transfer',
            confidence: 1.0,
            reason: 'destination_account_in_wallets',
            destination_wallet_id: matchedDestWallet.idwallet,
            source_wallet_id: sourceWallet?.idwallet || null
          };
        }
      }

      if (Array.isArray(bankAccounts) && bankAccounts.length > 0) {
        const matchedBankAcc = bankAccounts.find((b) => {
          const accNo = String(b.account_number || '').replace(/[\s-]/g, '').trim();
          return accNo && accNo === normalizedDestAccount;
        });

        if (matchedBankAcc) {
          return {
            type: 'Transfer',
            confidence: 1.0,
            reason: 'destination_account_in_bank_accounts',
            source_wallet_id: sourceWallet?.idwallet || null
          };
        }
      }
    }

    // =========================================================================
    // CƠ SỞ 2b: Đối soát Tên người nhận với Tên của chính User & Tên chủ thẻ trong CSDL
    // Khi user chuyển tiền cho chính họ, tên người nhận luôn trùng họ tên user / tên trên thẻ
    // =========================================================================
    if (normalizedDestName) {
      const candidates = [];
      if (userProfile?.fullname) {
        candidates.push(removeVietnameseTones(userProfile.fullname).toLowerCase().trim());
      }
      if (Array.isArray(bankAccounts)) {
        bankAccounts.forEach((b) => {
          if (b.account_name) {
            candidates.push(removeVietnameseTones(b.account_name).toLowerCase().trim());
          }
        });
      }
      if (Array.isArray(userWallets)) {
        userWallets.forEach((w) => {
          if (w.bank_account?.account_name) {
            candidates.push(removeVietnameseTones(w.bank_account.account_name).toLowerCase().trim());
          }
        });
      }

      const isMatch = candidates.some((cand) => {
        return cand && (normalizedDestName === cand || normalizedDestName.includes(cand) || cand.includes(normalizedDestName));
      });

      if (isMatch) {
        return {
          type: 'Transfer',
          confidence: 0.98,
          reason: 'destination_name_matches_user',
          matched_user: true,
          source_wallet_id: sourceWallet?.idwallet || null
        };
      }
    }

    // =========================================================================
    // CƠ SỞ 3: Phân tích ngữ nghĩa từ khóa nội dung chuyển khoản
    // =========================================================================
    const combinedText = `${note || ''} ${text || ''}`.toLowerCase();
    const normalizedNote = removeVietnameseTones(combinedText);

    const hasTransferKw = INTERNAL_TRANSFER_KEYWORDS.some((kw) => {
      const kwNoTone = removeVietnameseTones(kw);
      return normalizedNote.includes(kwNoTone);
    });

    if (hasTransferKw) {
      return {
        type: 'Transfer',
        confidence: 0.85,
        reason: 'internal_transfer_keywords',
        source_wallet_id: sourceWallet?.idwallet || null
      };
    }

    // =========================================================================
    // MẶC ĐỊNH: Chuyển tiền cho bên thứ 3 (người khác, công ty, mua hàng) -> Transaction
    // =========================================================================
    return {
      type: 'Transaction',
      confidence: 0.90,
      reason: 'third_party_payment'
    };
  }
};

module.exports = {
  typeDetector,
  INTERNAL_TRANSFER_KEYWORDS
};
