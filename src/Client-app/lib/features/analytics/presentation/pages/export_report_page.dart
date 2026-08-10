import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExportReportPage extends StatefulWidget {
  const ExportReportPage({super.key});

  @override
  State<ExportReportPage> createState() => _ExportReportPageState();
}

class _ExportReportPageState extends State<ExportReportPage> {
  final String _selectedReportType = 'Báo cáo Tổng quan Thu Chi';
  int _selectedTimeIndex = 0; // 0: Tháng này, 1: Tháng trước, 2: Quý này, 3: Tùy chỉnh
  int _selectedWalletIndex = 0; // 0: Tất cả các ví, 1: Techcombank, 2: Tiền mặt
  String _selectedFormat = 'pdf'; // 'pdf', 'xlsx', 'csv'
  bool _isPasswordProtected = false;

  final List<String> _timeOptions = ['Tháng này', 'Tháng trước', 'Quý này', 'Tùy chỉnh'];
  final List<String> _walletOptions = ['Tất cả các ví', 'Techcombank', 'Tiền mặt'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Xuất Báo cáo Tài chính',
          style: TextStyle(
            color: Color(0xFF1A1C1A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF1A1C1A)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Parameters Form
            _buildCardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('LOẠI BÁO CÁO'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8E4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedReportType,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A1C1A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: Color(0xFF77767D)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionLabel('THỜI GIAN'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: List.generate(_timeOptions.length, (index) {
                        final isSelected = _selectedTimeIndex == index;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTimeIndex = index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                _timeOptions[index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF00020D) : const Color(0xFF46464C),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionLabel('LỌC THEO VÍ'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_walletOptions.length, (index) {
                      final isSelected = _selectedWalletIndex == index;
                      return ChoiceChip(
                        label: Text(_walletOptions[index]),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedWalletIndex = index),
                        selectedColor: const Color(0xFF00020D),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF46464C),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00020D) : const Color(0xFFE8E8E4),
                          ),
                        ),
                        showCheckmark: false,
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionLabel('DANH MỤC'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8E4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tất cả danh mục',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A1C1A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(Icons.category_outlined, color: Color(0xFF77767D), size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 2: Format selection
            _buildCardContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('ĐỊNH DẠNG TỆP'),
                  const SizedBox(height: 12),
                  _buildFormatOption(
                    id: 'pdf',
                    icon: Icons.picture_as_pdf_outlined,
                    title: 'Tệp PDF (.pdf)',
                    subtitle: 'Đầy đủ biểu đồ & bảng kê',
                    iconBgColor: const Color(0xFF181C2C),
                    iconColor: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  _buildFormatOption(
                    id: 'xlsx',
                    icon: Icons.table_chart_outlined,
                    title: 'Tệp Excel (.xlsx)',
                    subtitle: 'Phù hợp tính toán',
                    iconBgColor: const Color(0xFFE8E8E4),
                    iconColor: const Color(0xFF46464C),
                  ),
                  const SizedBox(height: 10),
                  _buildFormatOption(
                    id: 'csv',
                    icon: Icons.insert_drive_file_outlined,
                    title: 'Tệp CSV (.csv)',
                    subtitle: 'Dữ liệu thô',
                    iconBgColor: const Color(0xFFE8E8E4),
                    iconColor: const Color(0xFF46464C),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Security & Destination
            _buildCardContainer(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Color(0xFF46464C), size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Đặt mật khẩu bảo vệ file PDF',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1C1A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isPasswordProtected,
                        onChanged: (val) => setState(() => _isPasswordProtected = val),
                        activeThumbColor: const Color(0xFF00020D),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE8E8E4)),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.folder_open_outlined, color: Color(0xFF46464C), size: 22),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đích đến',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A1C1A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Lưu vào Tải về (Downloads)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF808498),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: Color(0xFF77767D)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đang xuất báo cáo tài chính...')),
                  );
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text(
                  'Xuất & Tải Báo Cáo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00020D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Section 4: History
            _buildSectionLabel('LỊCH SỬ XUẤT GẦN ĐÂY'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E8E4)),
              ),
              child: Column(
                children: [
                  _buildHistoryItem(
                    icon: Icons.description_outlined,
                    fileName: 'BaoCao_Thang6.pdf',
                    dateSize: 'Đã tải: 15/06/2026 • 1.8MB',
                  ),
                  const Divider(height: 1, color: Color(0xFFE8E8E4)),
                  _buildHistoryItem(
                    icon: Icons.table_view_outlined,
                    fileName: 'ThuChi_TongHop_Q2.xlsx',
                    dateSize: 'Đã tải: 01/04/2026 • 2.4MB',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF46464C),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFormatOption({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    final isSelected = _selectedFormat == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDEE1F8).withValues(alpha: 0.2) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF00020D) : const Color(0xFFE8E8E4),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1C1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF46464C),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF00020D) : const Color(0xFF77767D),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required IconData icon,
    required String fileName,
    required String dateSize,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE8E8E4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF00020D), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1C1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateSize,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF46464C),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF808498)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
