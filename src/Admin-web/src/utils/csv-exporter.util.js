/**
 * Tiện ích xuất dữ liệu ra file CSV chuẩn UTF-8 có Byte Order Mark (BOM \uFEFF)
 * Giúp Microsoft Excel mở các ký tự tiếng Việt có dấu không bị lỗi font.
 * Tuân thủ chuẩn RFC 4180 cho escape chuỗi, dấu phẩy và xuống dòng.
 */

/**
 * Escape an toàn một ô dữ liệu trong CSV
 * @param {*} val 
 * @returns {string}
 */
export function escapeCsvCell(val) {
  if (val === null || val === undefined) return '""';
  const str = String(val);
  // Nếu chứa dấu phẩy, dấu nháy kép, hoặc xuống dòng thì bọc trong nháy kép và nhân đôi dấu nháy
  if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return `"${str}"`;
}

/**
 * Xuất dữ liệu mảng ra file CSV và kích hoạt tải về trình duyệt
 * @param {Object} options
 * @param {string} options.filename - Tên file (ví dụ 'audit_logs_2026.csv')
 * @param {Array<string>} options.headers - Danh sách tiêu đề cột ['Thời gian', 'Hành động', ...]
 * @param {Array<Array<*>>} options.rows - Mảng các dòng dữ liệu
 * @returns {Blob} Blob CSV đã tạo
 */
export function exportToCsv({ filename = 'export.csv', headers = [], rows = [] }) {
  const headerLine = headers.map(escapeCsvCell).join(',');
  const rowLines = rows.map((row) => row.map(escapeCsvCell).join(','));
  
  // Nối BOM \uFEFF ở đầu file để Excel nhận diện UTF-8 chuẩn xác
  const csvContent = '\uFEFF' + [headerLine, ...rowLines].join('\r\n');
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });

  // Tự động kích hoạt tải file về máy khách nếu đang ở môi trường trình duyệt hỗ trợ createObjectURL
  if (typeof window !== 'undefined' && typeof document !== 'undefined' && typeof URL !== 'undefined' && typeof URL.createObjectURL === 'function') {
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename.endsWith('.csv') ? filename : `${filename}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  return blob;
}

export default {
  escapeCsvCell,
  exportToCsv,
};
