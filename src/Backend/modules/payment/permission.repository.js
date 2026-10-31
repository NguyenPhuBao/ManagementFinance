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
      household_members: 0,
      household_wallets: 0,
    },
    features: {
      biometric_auth: true,
      offline_login: true,
      account_deletion: true,
      net_worth_overview: true,
      quick_action_shortcuts: true,
      wallet_balance_adjustment: true,
      wallet_exclude_total: true,
      transaction_management: true,
      ai_quick_input: false,
      ocr_receipt: true,
      quick_category_assignment: true,
      in_app_calculator: true,
      category_keywords_matching: true,
      smart_budget_rebalancing: false,
      budget_overspend_alert: true,
      bill_auto_pay: false,
      bill_reminder_notifications: true,
      goal_auto_deposit: false,
      goal_deposit_withdraw: true,
      export_reports: false,
      financial_health_fhs: true,
      cashflow_forecast: false,
      anomaly_spending_insights: false,
      ai_assistant: false,
      ai_edge_model: false,
      ai_model_management: true,
      bank_notification_parser: true,
      daily_recording_reminder: true,
      vietqr_payment: true,
      payment_history: true,
      offline_first_sync: true,
      household: false,
      household_join: true,
    },
  },
  Premium: {
    limits: {
      wallets: null,
      budgets: null,
      goals: null,
      bills: null,
      custom_categories: null,
      household_members: 6,
      household_wallets: 10,
    },
    features: {
      biometric_auth: true,
      offline_login: true,
      account_deletion: true,
      net_worth_overview: true,
      quick_action_shortcuts: true,
      wallet_balance_adjustment: true,
      wallet_exclude_total: true,
      transaction_management: true,
      ai_quick_input: true,
      ocr_receipt: true,
      quick_category_assignment: true,
      in_app_calculator: true,
      category_keywords_matching: true,
      smart_budget_rebalancing: true,
      budget_overspend_alert: true,
      bill_auto_pay: true,
      bill_reminder_notifications: true,
      goal_auto_deposit: true,
      goal_deposit_withdraw: true,
      export_reports: true,
      financial_health_fhs: true,
      cashflow_forecast: true,
      anomaly_spending_insights: true,
      ai_assistant: true,
      ai_edge_model: true,
      ai_model_management: true,
      bank_notification_parser: true,
      daily_recording_reminder: true,
      vietqr_payment: true,
      payment_history: true,
      offline_first_sync: true,
      household: true,
      household_join: true,
    },
  },
};

const permissionRepository = {
  DEFAULT_PERMISSIONS,
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
        return {
          limits: DEFAULT_PERMISSIONS[normalizedType].limits,
          features: DEFAULT_PERMISSIONS[normalizedType].features,
          scopes: {},
          policies: {},
        };
      }

      const limits = {};
      const features = {};
      const scopes = {};
      const policies = {};

      for (const row of records) {
        const featureId = row.feature_id;
        const featureType = row.feature?.type || 'TOGGLE';

        if (featureType === 'LIMIT') {
          limits[featureId] = row.is_enabled === false ? 0 : row.limit_value; // 0 nếu bị tắt theo Trụ 1, null = không giới hạn
        } else {
          features[featureId] = Boolean(row.is_enabled);
        }

        scopes[featureId] = row.scope_config || {};
        policies[featureId] = row.downgrade_policy || 'BLOCK_CREATE';
      }

      return { limits, features, scopes, policies };
    } catch (err) {
      console.warn(`[PermissionRepository] Lỗi đọc quyền cho ${accountType}, sử dụng fallback:`, err.message);
      return {
        limits: DEFAULT_PERMISSIONS[normalizedType].limits,
        features: DEFAULT_PERMISSIONS[normalizedType].features,
        scopes: {},
        policies: {},
      };
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
   * Cập nhật quyền của một tính năng theo loại tài khoản (hỗ trợ đầy đủ 4 trụ cột)
   */
  async updatePermission(accountType, featureId, { is_enabled, limit_value, scope_config, downgrade_policy }) {
    const updateData = {
      updated_at: new Date(),
    };

    if (is_enabled !== undefined) updateData.is_enabled = Boolean(is_enabled);
    if (limit_value !== undefined) {
      updateData.limit_value = limit_value !== '' && limit_value !== null ? Number(limit_value) : null;
    }
    if (scope_config !== undefined) updateData.scope_config = scope_config;
    if (downgrade_policy !== undefined) updateData.downgrade_policy = downgrade_policy;

    return prisma.account_type_permission.upsert({
      where: {
        account_type_feature_id: {
          account_type: accountType,
          feature_id: featureId,
        },
      },
      update: updateData,
      create: {
        account_type: accountType,
        feature_id: featureId,
        is_enabled: is_enabled !== undefined ? Boolean(is_enabled) : true,
        limit_value: limit_value !== undefined && limit_value !== '' && limit_value !== null ? Number(limit_value) : null,
        scope_config: scope_config !== undefined ? scope_config : {},
        downgrade_policy: downgrade_policy !== undefined ? downgrade_policy : 'BLOCK_CREATE',
      },
    });
  },
};

module.exports = permissionRepository;
