/**
 * Financial Tools Declarations for Gemini Function Calling
 * Tương thích Google Generative AI SDK
 */

const financialToolsDeclarations = [
  {
    name: 'get_category_transactions',
    description: 'Truy vấn danh sách các giao dịch cụ thể của một danh mục chi tiêu (ví dụ: các khoản ăn uống, mua sắm lớn nhất hoặc gần nhất). Dùng khi người dùng muốn biết chi tiết tiền đã đi đâu.',
    parameters: {
      type: 'OBJECT',
      properties: {
        categoryName: {
          type: 'STRING',
          description: 'Tên danh mục chi tiêu cần tìm (ví dụ: Ăn uống, Mua sắm, Di chuyển, Tiện ích)',
        },
        limit: {
          type: 'INTEGER',
          description: 'Số lượng giao dịch tối đa cần lấy (mặc định 5, tối đa 10)',
        },
        sortBy: {
          type: 'STRING',
          description: 'Cách sắp xếp: "amount_desc" (lớn nhất) hoặc "date_desc" (gần đây nhất)',
        },
      },
      required: ['categoryName'],
    },
  },
  {
    name: 'compare_spending_periods',
    description: 'So sánh mức chi tiêu giữa hai khoảng thời gian (ví dụ: 30 ngày gần đây so với 30 ngày trước đó) để nhận diện xu hướng tăng/giảm.',
    parameters: {
      type: 'OBJECT',
      properties: {
        categoryName: {
          type: 'STRING',
          description: 'Tên danh mục cụ thể cần so sánh (bỏ trống nếu muốn so sánh toàn bộ chi tiêu)',
        },
        daysAgo1: {
          type: 'INTEGER',
          description: 'Số ngày của kỳ 1 gần nhất (mặc định 30 ngày)',
        },
        daysAgo2: {
          type: 'INTEGER',
          description: 'Số ngày của kỳ 2 trước đó (mặc định 30 ngày)',
        },
      },
    },
  },
  {
    name: 'get_bill_details',
    description: 'Xem chi tiết các hóa đơn sắp đến hạn thanh toán trong khoảng thời gian tới để lên kế hoạch tiền mặt.',
    parameters: {
      type: 'OBJECT',
      properties: {
        status: {
          type: 'STRING',
          description: 'Trạng thái hóa đơn: "Pending" (chưa trả) hoặc "All" (tất cả)',
        },
        daysAhead: {
          type: 'INTEGER',
          description: 'Khoảng thời gian sắp tới tính theo ngày (mặc định 14 ngày tới)',
        },
      },
    },
  },
  {
    name: 'get_goal_simulation',
    description: 'Giả lập tiến độ hoàn thành mục tiêu tiết kiệm tích lũy dựa trên số tiền người dùng dự định đóng góp hàng tháng.',
    parameters: {
      type: 'OBJECT',
      properties: {
        goalName: {
          type: 'STRING',
          description: 'Tên mục tiêu cần giả lập (ví dụ: Mua nhà, Mua xe, Quỹ du lịch)',
        },
        monthlyContribution: {
          type: 'NUMBER',
          description: 'Số tiền dự định tiết kiệm thêm mỗi tháng (VND)',
        },
      },
      required: ['goalName', 'monthlyContribution'],
    },
  },
];

module.exports = {
  financialToolsDeclarations,
};
