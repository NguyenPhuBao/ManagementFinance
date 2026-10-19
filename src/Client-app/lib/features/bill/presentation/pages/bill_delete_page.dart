import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../category/data/models/category_entity.dart';
import '../../../category/data/repositories/category_management_repository.dart';
import '../../../category/presentation/widgets/category_visuals.dart';
import '../../../wallet/data/repositories/wallet_repository.dart';
import '../../data/models/bill_entity.dart';
import '../../data/repositories/bill_repository.dart';
import '../../domain/bill_pay_status.dart';
import '../../domain/bill_recurrence.dart';

/// Câu phụ của màn xác nhận xoá, theo trạng thái của kỳ (người dùng chốt 2026-10-17).
///
/// Xoá chỉ gỡ đúng MỘT hàng — một kỳ (`BillRepository.deleteBill`). Câu của Stitch ("dừng tất cả các lời nhắc nhở và
/// lịch thanh toán tự động") chỉ đúng với kỳ **còn phải trả**: kỳ kế tiếp chỉ sinh khi trả / bỏ qua kỳ này, nên xoá
/// kỳ đang mở là chuỗi dừng. Xoá kỳ **đã trả** thì kỳ kế tiếp (một hàng khác) vẫn được nhắc và vẫn tự trả, khoản chi
/// ở lại sổ và số dư không đổi — xoá xong thì nút Hoàn tác biến mất cùng hoá đơn, nên câu phải bảo hoàn tác TRƯỚC.
/// Nhánh bỏ qua xét trước, cùng thứ tự với `billDisplayStatusOf`.
String cauXacNhanXoaHoaDon(BillEntity bill) {
  if (daBoQua(bill)) {
    return 'Kỳ này đã bỏ qua — xoá chỉ gỡ nó khỏi danh sách hoá đơn.';
  }
  if (daCoKhoanChi(bill)) {
    return 'Kỳ này đã thanh toán — xoá chỉ gỡ nó khỏi danh sách hoá đơn. '
        'Khoản chi vẫn ở sổ giao dịch và số dư ví không đổi; muốn trả tiền '
        'lại ví, hãy Hoàn tác trước khi xoá.';
  }
  return 'Thao tác này sẽ dừng tất cả các lời nhắc nhở và lịch thanh toán tự '
      'động cho dịch vụ này${bill.isRecurrence ? ', và không tạo kỳ kế tiếp' : ''}. '
      'Lịch sử các giao dịch đã thanh toán trước đó vẫn sẽ được giữ lại.';
}

/// Màn xác nhận xoá hoá đơn (`/bills/:id/delete`), theo Stitch *"Xác nhận xóa hóa đơn"* (`124611f0…`).
///
/// Trang chỉ HỎI: *Xác nhận Xóa* trả `true`, *Hủy bỏ* trả `false`, Back trả `null`. Việc xoá do chỗ gọi làm
/// (`xacNhanXoaHoaDon`, `bill_actions.dart`) trên `BillBloc` của nó, để toast và việc trang Chi tiết tự đóng đi
/// đúng đường cũ. Lệch Stitch có chủ ý: ô ảnh là biểu tượng + màu danh mục (hoá đơn không có ảnh); ngày theo dạng
/// `Hạn dd/MM/yyyy` của thẻ danh sách và trang chi tiết; dòng hạn màu trung tính (xanh của Stitch đọc như "ổn"
/// ngay cả với kỳ quá hạn).
class BillDeletePage extends StatefulWidget {
  final String id;

  /// Ảnh chụp từ chỗ gọi để vẽ ngay; trang vẫn đọc lại theo [id].
  final BillEntity? bill;

  const BillDeletePage({super.key, required this.id, this.bill});

  @override
  State<BillDeletePage> createState() => _BillDeletePageState();
}

class _BillDeletePageState extends State<BillDeletePage> {
  /// Nền `surface-bright` của Stitch: khối minh hoạ `surfaceContainer` chìm mất trên nền chung của app.
  static const _nen = Color(0xFFFAF9F5);

  /// `on-surface-variant` của Stitch — câu cảnh báo cần đậm hơn `textSecondary`.
  static const _chuPhu = Color(0xFF46464C);

  /// Viền và chữ nút *Hủy bỏ* (`on-tertiary-container` của Stitch, cùng màu thùng rác trên thẻ hoá đơn).
  static const _do = Color(0xFFF1453B);


  BillEntity? _bill;
  CategoryEntity? _danhMuc;
  String? _tenVi;
  bool _dangTai = true;

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
    _nap();
  }

  Future<void> _nap() async {
    final bill = await sl<BillRepository>().getById(widget.id);
    // Ví / danh mục đọc theo id: lấy được cả hàng đã lưu trữ hay đã xoá mềm — đây là tên để đọc, không phải để chọn.
    final danhMuc =
        bill?.categoryId == null ? null : await sl<CategoryManagementRepository>().getById(bill!.categoryId!);
    final vi = bill?.walletId == null ? null : await sl<WalletRepository>().getById(bill!.walletId!);
    if (!mounted) return;
    setState(() {
      _bill = bill;
      _danhMuc = danhMuc;
      _tenVi = vi?.name;
      _dangTai = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _bill;
    return Scaffold(
      backgroundColor: _nen,
      appBar: AppBar(
        backgroundColor: _nen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Xóa Hóa đơn',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: b == null
          ? Center(
              child: _dangTai
                  ? const CircularProgressIndicator()
                  : const Text('Không tìm thấy hoá đơn', style: TextStyle(color: AppColors.textSecondary)),
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _KhoiMinhHoa(),
                    const SizedBox(height: 24),
                    const Text(
                      'Bạn có chắc chắn muốn xóa hóa đơn này?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      cauXacNhanXoaHoaDon(b),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: _chuPhu, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    _theHoaDon(b),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.delete, size: 20),
                        label: const Text('Xác nhận Xóa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _do,
                          side: const BorderSide(color: _do, width: 2),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Hủy bỏ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _theHoaDon(BillEntity b) {
    final mau = categoryColorFrom(_danhMuc?.colour, fallback: AppColors.primary);
    final chuKy = b.isRecurrence
        ? 'Thanh toán ${tenChuKyHoaDon(b.timeRecurrence).toLowerCase()}'
        : 'Thanh toán một lần';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, rang) {
            return Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: mau.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIconFor(_danhMuc?.icon), color: mau),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(chuKy, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Số tiền 13 chữ số ở 320 dp không vừa cỡ chữ gốc: co lại bằng FittedBox (Text ngắt dòng thì không báo
                // tràn), và cột tiền có trần để tên luôn còn chỗ.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: rang.maxWidth * 0.45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.format(b.amount),
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Hạn ${DateFormatter.formatDate(b.dueDate)}',
                          maxLines: 1,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: AppColors.outlineVariant),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _oThongTin('DANH MỤC', _danhMuc?.name)),
              const SizedBox(width: 16),
              Expanded(child: _oThongTin('NGUỒN TIỀN', _tenVi)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _oThongTin(String nhan, String? giaTri) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nhan,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            giaTri ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      );
}

/// Khối minh hoạ đầu trang: nền `surfaceContainer` loang đỏ nhạt, lưới chấm mờ, vòng trắng giữa có thùng rác.
class _KhoiMinhHoa extends StatelessWidget {
  const _KhoiMinhHoa();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 192,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(AppColors.errorContainer.withValues(alpha: 0.2), AppColors.surfaceContainer),
                    AppColors.surfaceContainer,
                  ],
                ),
              ),
            ),
            const CustomPaint(painter: _LuoiCham()),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lưới chấm 24 px, độ mờ 5 % — hoạ tiết nền của khối minh hoạ trên Stitch.
class _LuoiCham extends CustomPainter {
  const _LuoiCham();

  @override
  void paint(Canvas canvas, Size size) {
    final but = Paint()..color = Colors.black.withValues(alpha: 0.05);
    for (var y = 2.0; y < size.height; y += 24) {
      for (var x = 2.0; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1, but);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LuoiCham oldDelegate) => false;
}
