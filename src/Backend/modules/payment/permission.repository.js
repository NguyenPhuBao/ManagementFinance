const { prisma } = require('../../config/db');

/**
 * Fallback mặc định an toàn nếu CSDL chưa có dữ liệu hoặc gặp sự cố
 */
const DEFAULT_PERMISSIONS = {
  Basic: {
    limits: {
      wallets: 3,
      budgets: 3,
      goals: 3,
      bills: 3,
      custom_categories: 5,
    },
    features: {
      ai_assistant: false,
      ai_quick_input: false,
      ocr_receipt: true,
      ai_edge_model: false,
      smart_budget_rebalancing: false,
      financial_health_fhs: true,
      export_reports: false,
      cashflow_forecast: false,
      anomaly_spending_insights: false,
      bill_auto_pay: false,
      goal_auto_deposit: false,
      bank_notification_parser: true,
    },
  },
  Premium: {
    limits: {
      wallets: null,
      budgets: null,
      goals: null,
      bills: null,
      custom_categories: null,
    },
    features: {
      ai_assistant: true,
      ai_quick_input: true,
      ocr_receipt: true,
      ai_edge_model: true,
      smart_budget_rebalancing: true,
      financial_health_fhs: true,
      export_reports: true,
      cashflow_forecast: true,
      anomaly_spending_insights: true,
      bill_auto_pay: true,
      goal_auto_deposit: true,
      bank_notification_parser: true,
    },
  },
};

const permissionRepository = {
  /**
   * Lấy cấu hình phân quyền theo loại tài khoản (Basic / Premium)
   * Trả về định dạng chuẩn { limits, features }
   * @param {string} accountType - 'Basic' | 'Premium'
   * @returns {Promise<{ limits: Record<string, number|null>, features: Record<string, boolean> }>}
   */
  async getPermissionsByAccountType(accountType) {
    const normalizedType = accountType === 'Premium' ? 'Premium' : 'Basic';

    try {
      const records = await prisma.account_type_permission.findMany({
        where: { account_type: normalizedType },
        include: { feature: true },
      });

      if (!records || records.length === 0) {
        return DEFAULT_PERMISSIONS[normalizedType];
      }

      const limits = {};
      const features = {};

      for (const row of records) {
        const featureId = row.feature_id;
        const featureType = row.feature?.type || 'TOGGLE';

        if (featureType === 'LIMIT') {
          limits[featureId] = row.limit_value; // null = không giới hạn
        } else {
          features[featureId] = Boolean(row.is_enabled);
        }
      }

      return { limits, features };
    } catch (err) {
      console.warn(`[PermissionRepository] Lỗi đọc quyền cho ${accountType}, sử dụng fallback:`, err.message);
      return DEFAULT_PERMISSIONS[normalizedType];
    }
  },

  /**
   * Lấy toàn bộ danh mục tính năng hệ thống (phục vụ Admin-web)
   */
  async getAllFeatures() {
    return prisma.feature.findMany({
      orderBy: [{ category_group: 'asc' }, { id: 'asc' }],
    });
  },

  /**
   * Lấy ma trận phân quyền của tất cả loại tài khoản (phục vụ Admin-web)
   */
  async getAllAccountPermissions() {
    return prisma.account_type_permission.findMany({
      include: { feature: true },
      orderBy: [{ account_type: 'asc' }, { feature_id: 'asc' }],
    });
  },

  /**
   * Cập nhật quyền của một tính năng theo loại tài khoản (phục vụ Admin-web)
   */
  async updatePermission(accountType, featureId, { is_enabled, limit_value }) {
    return prisma.account_type_permission.upsert({
      where: {
        account_type_feature_id: {
          account_type: accountType,
          feature_id: featureId,
        },
      },
      update: {
        is_enabled: is_enabled !== undefined ? is_enabled : true,
        limit_value: limit_value !== undefined ? limit_value : null,
        updated_at: new Date(),
      },
      create: {
        account_type: accountType,
        feature_id: featureId,
        is_enabled: is_enabled !== undefined ? is_enabled : true,
        limit_value: limit_value !== undefined ? limit_value : null,
      },
    });
  },
};

module.exports = permissionRepository;
