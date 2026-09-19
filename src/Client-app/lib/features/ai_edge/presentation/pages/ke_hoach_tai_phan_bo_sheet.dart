import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/gioi_han_do_dai.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../budget/data/repositories/budget_repository.dart';
import '../../domain/ap_dung_ke_hoach.dart';
import '../../domain/tai_phan_bo.dart';

/// Kiểu của hàm ghi một hàng phản hồi — `AiFeedbackDao.ghi` ngoài đời, một
/// closure gom hàng trong test.
typedef GhiPhanHoi = Future<void> Function(AiRebalancingFeedbacksCompanion);

/// Mở sheet kế hoạch tái phân bổ (màn Stitch `f02861d9…`, khối 2).
///
/// Ba lối ra, ba nghĩa khác nhau: **Áp dụng** = sửa hạn mức qua
/// `updateBudget` (đi đường đồng bộ như mọi lần sửa) + ghi phản hồi từng
/// dòng; **Bỏ qua** = chỉ ghi phản hồi `rejected`; **vuốt / chạm nền** = không
/// ghi gì — chưa quyết không phải từ chối, và ghi `rejected` ở đây là dạy luật
/// C3 một điều người dùng không nói.
Future<void> moKeHoachTaiPhanBoSheet(
  BuildContext context, {
  required KeHoachTaiPhanBo keHoach,
  required int idaccount,
  required BudgetRepository budgets,
  required GhiPhanHoi ghiPhanHoi,
  DateTime Function()? clock,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => KeHoachTaiPhanBoSheet(
        keHoach: keHoach,
        idaccount: idaccount,
        budgets: budgets,
        ghiPhanHoi: ghiPhanHoi,
        clock: clock ?? DateTime.now,
        onXong: () => Navigator.of(ctx).pop(),
      ),
    );

class KeHoachTaiPhanBoSheet extends StatefulWidget {
  final KeHoachTaiPhanBo keHoach;
  final int idaccount;
  final BudgetRepository budgets;
  final GhiPhanHoi ghiPhanHoi;
  final DateTime Function() clock;
  final VoidCallback onXong;

  const KeHoachTaiPhanBoSheet({
    super.key,
    required this.keHoach,
    required this.idaccount,
    required this.budgets,
    required this.ghiPhanHoi,
    required this.clock,
    required this.onXong,
  });

  @override
  State<KeHoachTaiPhanBoSheet> createState() => _KeHoachTaiPhanBoSheetState();
}

class _KeHoachTaiPhanBoSheetState extends State<KeHoachTaiPhanBoSheet> {
  /// id ngân sách nguồn bù → được tick.
  late final Map<String, bool> _chon;

  /// id ngân sách nguồn bù → số tiền đang nhập (`null` khi ô trống / không
  /// đọc được).
  late final Map<String, double?> _soTien;

  bool _dangGhi = false;
  String? _loi;

  KeHoachTaiPhanBo get _kh => widget.keHoach;

  @override
  void initState() {
    super.initState();
    _chon = {for (final d in _kh.dong) d.nguon.budget.id: true};
    _soTien = {for (final d in _kh.dong) d.nguon.budget.id: d.soTien};
  }

  /// Lỗi của một dòng đang tick; `null` khi hợp lệ hoặc không tick.
  String? _loiDong(DongTaiPhanBo d) {
    final id = d.nguon.budget.id;
    if (!(_chon[id] ?? false)) return null;
    final x = _soTien[id];
    if (x == null || x <= 0) return 'Nhập số tiền';
    if (x > d.duDia) return 'Vượt dư địa ${CurrencyFormatter.format(d.duDia)}';
    return null;
  }

  /// Số đã chọn: chỉ dòng tick và có số dương (kể cả số vượt dư địa — nút Áp
  /// dụng tắt riêng bằng [_hopLe]).
  Map<String, double> get _daChon => {
        for (final d in _kh.dong)
          if ((_chon[d.nguon.budget.id] ?? false) &&
              (_soTien[d.nguon.budget.id] ?? 0) > 0)
            d.nguon.budget.id: _soTien[d.nguon.budget.id]!,
      };

  double get _tongCat => _daChon.values.fold(0.0, (s, x) => s + x);

  bool get _hopLe => _kh.dong.every((d) => _loiDong(d) == null);

  Future<void> _apDung() async {
    if (_dangGhi) return;
    setState(() {
      _dangGhi = true;
      _loi = null;
    });
    try {
      final chon = _daChon;
      final now = widget.clock();
      for (final (b, moi) in hanMucMoi(_kh, chon)) {
        await widget.budgets.updateBudget(b.copyWith(amount: moi));
      }
      for (final c in phanHoiTu(_kh, chon,
          idaccount: widget.idaccount, now: now, boQua: false)) {
        await widget.ghiPhanHoi(c);
      }
      if (mounted) widget.onXong();
    } catch (e) {
      debugPrint('[KeHoachTaiPhanBoSheet] áp dụng lỗi: $e');
      if (mounted) {
        setState(() {
          _dangGhi = false;
          _loi = 'Không áp dụng được: $e';
        });
      }
    }
  }

  Future<void> _boQua() async {
    if (_dangGhi) return;
    setState(() => _dangGhi = true);
    try {
      final now = widget.clock();
      for (final c in phanHoiTu(_kh, const {},
          idaccount: widget.idaccount, now: now, boQua: true)) {
        await widget.ghiPhanHoi(c);
      }
    } catch (e) {
      debugPrint('[KeHoachTaiPhanBoSheet] ghi phản hồi lỗi: $e');
    }
    if (mounted) widget.onXong();
  }

  @override
  Widget build(BuildContext context) {
    final kh = _kh;
    final man = MediaQuery.sizeOf(context);
    final banPhim = MediaQuery.viewInsetsOf(context).bottom;
    final tong = _tongCat;
    final pt = kh.thamHut <= 0
        ? 0
        : (tong / kh.thamHut * 100).round().clamp(0, 100);
    final duCanDoi = tong >= kh.thamHut;
    final mauTong = duCanDoi ? const Color(0xFF006E1C) : AppColors.textPrimary;

    // ⚠️ Chiều cao CỐ ĐỊNH theo màn (trừ bàn phím), không co theo số dòng —
    // bài học sheet chọn phạm vi 2026-09-15: sheet neo đáy mà co theo nội
    // dung thì hàng nút trượt dưới ngón tay.
    return Padding(
      padding: EdgeInsets.only(bottom: banPhim),
      child: SizedBox(
        key: const ValueKey('ke-hoach-sheet'),
        height: (man.height - banPhim) * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D6CE),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kế hoạch cân đối ngân sách',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onXong,
                    icon: const Icon(Icons.close,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Text.rich(
                TextSpan(
                  text: '${kh.thieu.displayName} · thâm hụt dự kiến ',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: CurrencyFormatter.format(kh.thamHut),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: kh.dong.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = kh.dong[i];
                    final id = d.nguon.budget.id;
                    return _DongNguonBu(
                      key: ValueKey('ke-hoach-dong-$id'),
                      dong: d,
                      chon: _chon[id] ?? false,
                      loi: _loiDong(d),
                      onChon: (v) => setState(() => _chon[id] = v),
                      onSoTien: (v) => setState(() => _soTien[id] = v),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: duCanDoi
                      ? const Color(0xFFF0FDF4)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: duCanDoi
                        ? const Color(0xFFDCFCE7)
                        : AppColors.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      duCanDoi ? Icons.check_circle : Icons.info_outline,
                      size: 16,
                      color: mauTong,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tổng bù: ${CurrencyFormatter.format(tong)} / '
                        '${CurrencyFormatter.format(kh.thamHut)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: mauTong,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$pt% CÂN ĐỐI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: mauTong,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_loi != null) ...[
                const SizedBox(height: 8),
                Text(_loi!,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.error)),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const ValueKey('ke-hoach-ap-dung'),
                onPressed: (!_dangGhi && tong > 0 && _hopLe) ? _apDung : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text(
                  'Áp dụng kế hoạch',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                key: const ValueKey('ke-hoach-bo-qua'),
                onPressed: _dangGhi ? null : _boQua,
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Bỏ qua'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một dòng nguồn bù: tick · tên + dư địa · ô số tiền cắt.
///
/// Tách thành widget riêng để mỗi dòng giữ `_amountController` của mình —
/// và để test quét ô tiền (`o_nhap_tien_co_tran_test`) nhận ra ô này theo
/// đúng tên controller mà dự án dùng.
class _DongNguonBu extends StatefulWidget {
  final DongTaiPhanBo dong;
  final bool chon;
  final String? loi;
  final ValueChanged<bool> onChon;
  final ValueChanged<double?> onSoTien;

  const _DongNguonBu({
    super.key,
    required this.dong,
    required this.chon,
    required this.loi,
    required this.onChon,
    required this.onSoTien,
  });

  @override
  State<_DongNguonBu> createState() => _DongNguonBuState();
}

class _DongNguonBuState extends State<_DongNguonBu> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: CurrencyFormatter.formatSoThoi(widget.dong.soTien),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dong;
    final id = d.nguon.budget.id;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Checkbox(
            key: ValueKey('ke-hoach-tick-$id'),
            value: widget.chon,
            activeColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => widget.onChon(v ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.nguon.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'dư địa ${CurrencyFormatter.format(d.duDia)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Text('−',
              style: TextStyle(fontSize: 13, color: AppColors.error)),
          const SizedBox(width: 4),
          SizedBox(
            width: 112,
            child: TextField(
              key: ValueKey('ke-hoach-so-tien-$id'),
              controller: _amountController,
              enabled: widget.chon,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              // budget."TotalAmount" là numeric(15,2) — xem kSoChuSoToiDaSoTien.
              inputFormatters: const [
                _ChiChuSo(),
                GioiHanSoChuSo(kSoChuSoToiDaSoTien),
              ],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                errorText: widget.loi,
                errorStyle: const TextStyle(fontSize: 10),
                errorMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
              ),
              onChanged: (s) {
                final chu = s.replaceAll(RegExp(r'[^0-9]'), '');
                widget.onSoTien(chu.isEmpty ? null : double.parse(chu));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Giữ chữ số và vẽ lại dấu chấm ngăn nghìn sau mỗi lần gõ (`formatSoThoi`),
/// để "150000" người dùng gõ hiện thành "150.000" như giá trị điền sẵn — máy
/// ảo lộ ra hai kiểu hiển thị sống chung trong cùng một ô. `onChanged` của ô
/// tự bỏ dấu chấm trước khi `double.parse`.
class _ChiChuSo extends TextInputFormatter {
  const _ChiChuSo();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final chu = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final moi =
        chu.isEmpty ? '' : CurrencyFormatter.formatSoThoi(int.parse(chu));
    if (moi == newValue.text) return newValue;
    return TextEditingValue(
      text: moi,
      selection: TextSelection.collapsed(offset: moi.length),
    );
  }
}
