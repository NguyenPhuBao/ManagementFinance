import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bill/bill_recurrence.dart';
import '../../../../core/category/category_visuals.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/domain/khoan_lap.dart';
import '../../data/de_xuat_hoa_don_nguon.dart';
import '../../domain/dien_san_hoa_don.dart';

/// Thẻ "Có vẻ là khoản lặp" trên trang Hoá đơn (B2) — màn Stitch
/// `e8b460b4a12f4e96a4a40e2fa078cc32`, cùng khuôn thẻ "Chưa đặt ngân sách".
///
/// Người dùng ghi tay cùng một khoản chi mỗi tháng / tuần mà chưa có hoá đơn;
/// thẻ gợi ý biến nó thành hoá đơn. **Máy phát hiện, người dùng bấm xác nhận**
/// (bất biến ④): **Tạo** mở form điền sẵn, lưu hay không là việc của họ.
///
/// ⚠️ **Widget không quyết định ẩn hay hiện.** `chonDeXuatHoaDon` trả `null`
/// khi không có gì để gợi ý và thẻ dựng `SizedBox.shrink()` — không có luật ẩn
/// thứ hai ở đây. Khác thẻ ngân sách (nhận gói từ cubit), thẻ này **tự nạp**
/// qua [nguon] vì `BillBloc` cố ý không đổi; nạp lại sau Tạo / Bỏ qua.
class TheKhoanLap extends StatefulWidget {
  const TheKhoanLap({
    super.key,
    required this.idaccount,
    required this.nguon,
    this.moForm,
  });

  final int idaccount;
  final DeXuatHoaDonNguon nguon;

  /// Mở form tạo hoá đơn điền sẵn; trả `true` khi form đã gửi (`pop(true)`).
  /// Mặc định: `context.push<bool>('/bills/add?…')`.
  final Future<bool?> Function(Map<String, String> query)? moForm;

  @override
  State<TheKhoanLap> createState() => _TheKhoanLapState();
}

class _TheKhoanLapState extends State<TheKhoanLap> {
  List<KhoanLap>? _ds;
  Map<String, Category> _danhMuc = const {};

  @override
  void initState() {
    super.initState();
    _nap();
  }

  @override
  void didUpdateWidget(covariant TheKhoanLap old) {
    super.didUpdateWidget(old);
    if (old.idaccount != widget.idaccount) _nap();
  }

  Future<void> _nap() async {
    final ds = await widget.nguon.tai(widget.idaccount);
    final dm = ds == null ? _danhMuc : await widget.nguon.bangDanhMuc(widget.idaccount);
    if (!mounted) return;
    setState(() {
      _ds = ds;
      _danhMuc = dm;
    });
  }

  Future<void> _boQua(KhoanLap k) async {
    await widget.nguon.boQua(widget.idaccount, k.khoaNhom);
    await _nap();
  }

  Future<void> _tao(KhoanLap k) async {
    final q = queryTuKhoanLap(k);
    final mo = widget.moForm ??
        (q) => context.push<bool>(Uri(path: '/bills/add', queryParameters: q).toString());
    final daLuu = await mo(q);
    // Chỉ `true` mới là đã lưu — thoát form không lưu thì nhóm vẫn là gợi ý
    // người dùng chưa từ chối.
    if (daLuu == true) await widget.nguon.daTao(widget.idaccount, k.khoaNhom);
    await _nap();
  }

  @override
  Widget build(BuildContext context) {
    final ds = _ds;
    if (ds == null || ds.isEmpty) return const SizedBox.shrink();
    return Padding(
      // Cùng lề với khối Nhận xét ngay trên nó.
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        key: const ValueKey('the-khoan-lap'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_repeat, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'CÓ VẺ LÀ KHOẢN LẶP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${ds.length} khoản',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Bạn ghi tay những khoản này đều đặn — tạo hoá đơn để được nhắc hạn',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < ds.length; i++) ...[
              if (i > 0)
                const Divider(height: 16, thickness: 1, color: AppColors.surfaceContainerLow),
              _Dong(
                khoan: ds[i],
                danhMuc: _danhMuc[ds[i].categoryId],
                onTao: () => _tao(ds[i]),
                onBoQua: () => _boQua(ds[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  const _Dong({
    required this.khoan,
    required this.danhMuc,
    required this.onTao,
    required this.onBoQua,
  });

  final KhoanLap khoan;
  final Category? danhMuc;
  final VoidCallback onTao;
  final VoidCallback onBoQua;

  @override
  Widget build(BuildContext context) {
    final mau = categoryColorFrom(danhMuc?.colour, fallback: AppColors.textSecondary);
    final ky = khoan.chuKy == kBillCycleWeek ? 'mỗi tuần' : 'mỗi tháng';
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            // Nền nhạt cùng tông màu danh mục — dòng gợi ý không được nổi hơn
            // hoá đơn thật ngay dưới.
            color: mau.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(categoryIconFor(danhMuc?.icon), size: 18, color: mau),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                khoan.ten,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                // "khoảng": mức suy ra từ lần gần nhất, không phải mức người
                // dùng đặt.
                'khoảng ${CurrencyFormatter.format(khoan.soTien)} $ky · ${khoan.soLan} lần',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          key: ValueKey('khoan-lap-tao-${khoan.khoaNhom}'),
          onPressed: onTao,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            // Theme của app ép ElevatedButton rộng vô hạn — thiếu dòng này nút
            // trong Row làm trắng cả trang (bẫy 4.11).
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: const Text('Tạo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          key: ValueKey('khoan-lap-bo-qua-${khoan.khoaNhom}'),
          onPressed: onBoQua,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Bỏ qua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
