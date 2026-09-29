import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/category/category_visuals.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../data/gan_danh_muc_nguon.dart';
import '../../data/goi_y_phan_hoi_store.dart';
import '../../data/repositories/category_management_repository.dart';
import '../../domain/gan_hang_loat.dart';
import '../widgets/chon_danh_muc_gan_sheet.dart';

typedef TaiDuLieuGan = Future<DuLieuGanDanhMuc> Function(int idaccount);
typedef ApDungDongGan = Future<void> Function(DongGanDanhMuc dong, String categoryId);
typedef GhiPhanHoiDongGan = Future<void> Function(DongGanDanhMuc dong, String ketQua, String chonCategoryId);

/// Màn *Gắn danh mục nhanh* — C1 (spec `2026-09-28-c1-gan-danh-muc-hang-loat-design.md` §4–§5, màn Stitch
/// `5023f0818909440badd2e1aecfeed6ca`).
///
/// Bất biến ④ của nhóm C: mô hình B1 chỉ **điền sẵn** (tick + chip danh mục); không có gì được ghi trước khi người
/// dùng bấm *Áp dụng*. Mọi dòng đi qua `TransactionRepository.updateTransaction` — lo đồng bộ và số dư.
///
/// Ba tham số tiêm chỉ cho widget test; đường chạy thật để `null` và dùng `gan_danh_muc_nguon.dart`.
class GanDanhMucPage extends StatefulWidget {
  const GanDanhMucPage({
    super.key,
    required this.idaccount,
    this.taiDuLieu,
    this.apDung,
    this.ghiPhanHoi,
  });

  /// `null` = chưa có phiên dùng được: không đọc, không ghi gì (quy tắc 2 — không rơi về tài khoản admin).
  final int? idaccount;
  final TaiDuLieuGan? taiDuLieu;
  final ApDungDongGan? apDung;
  final GhiPhanHoiDongGan? ghiPhanHoi;

  @override
  State<GanDanhMucPage> createState() => _GanDanhMucPageState();
}

class _GanDanhMucPageState extends State<GanDanhMucPage> {
  DuLieuGanDanhMuc? _du;
  bool _loiTai = false;

  /// id giao dịch → danh mục đang chọn cho dòng ấy (điền sẵn bằng dự đoán, người dùng đổi được).
  final Map<String, String> _chon = {};

  /// id giao dịch đang tick. Dòng chưa có danh mục thì không tick được.
  final Set<String> _tick = {};
  bool _dangApDung = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final id = widget.idaccount;
    if (id == null) return;
    try {
      final du = await (widget.taiDuLieu ?? _taiMacDinh)(id);
      if (!mounted) return;
      setState(() {
        _du = du;
        for (final d in du.dong) {
          final doan = d.doan;
          if (doan == null) continue;
          _chon[d.giaoDich.id] = doan.categoryId;
          _tick.add(d.giaoDich.id);
        }
      });
    } catch (e) {
      debugPrint('[GanDanhMuc] nạp màn lỗi: $e');
      if (mounted) setState(() => _loiTai = true);
    }
  }

  GoiYPhanHoiStore? get _store => sl.isRegistered<GoiYPhanHoiStore>() ? sl<GoiYPhanHoiStore>() : null;

  Future<DuLieuGanDanhMuc> _taiMacDinh(int id) => taiDuLieuGan(
        db: sl<AppDatabase>(),
        danhMuc: sl<CategoryManagementRepository>(),
        phanHoi: _store,
        idaccount: id,
      );

  Future<void> _apDungMacDinh(DongGanDanhMuc d, String categoryId) =>
      apDungGan(db: sl<AppDatabase>(), repo: sl<TransactionRepository>(), dong: d, categoryId: categoryId);

  Future<void> _ghiMacDinh(DongGanDanhMuc d, String ketQua, String chon) async {
    final store = _store;
    final id = widget.idaccount;
    final du = _du;
    if (store == null || id == null || du == null) return;
    final duDoan = du.chonDuoc.where((c) => c.id == d.doan!.categoryId).firstOrNull;
    if (duDoan == null) return;
    await ghiPhanHoiGan(
      store: store,
      idaccount: id,
      dong: d,
      duDoan: duDoan,
      ketQua: ketQua,
      chonCategoryId: chon,
    );
  }

  int get _soDangTick => _tick.where(_chon.containsKey).length;

  Future<void> _chonDanhMuc(DongGanDanhMuc d) async {
    final du = _du;
    if (du == null) return;
    final hopLe = hopLeTheoChieu(d.giaoDich.type, du.chonDuoc);
    final t = d.giaoDich;
    final ghiChu = t.note.trim();
    final chon = await moChonDanhMucGan(
      context,
      loai: t.type,
      moTa: [
        t.type == 'thu' ? 'Khoản thu' : 'Khoản chi',
        CurrencyFormatter.formatCoDau(t.amount, thu: t.type == 'thu'),
        if (ghiChu.isNotEmpty) ghiChu,
      ].join(' · '),
      ungVien: [for (final c in du.chonDuoc) if (hopLe.contains(c.id)) c],
      dangChon: _chon[t.id],
    );
    if (chon == null || !mounted) return;
    setState(() {
      _chon[t.id] = chon.id;
      // Chọn danh mục là ý định gắn dòng ấy.
      _tick.add(t.id);
    });
  }

  Future<void> _apDung() async {
    final du = _du;
    if (du == null || _dangApDung || _soDangTick == 0) return;
    setState(() => _dangApDung = true);
    final apDung = widget.apDung ?? _apDungMacDinh;
    final ghi = widget.ghiPhanHoi ?? _ghiMacDinh;
    var thanhCong = 0;
    var loi = 0;
    for (final d in du.dong) {
      final id = d.giaoDich.id;
      final categoryId = _chon[id];
      if (!_tick.contains(id) || categoryId == null) continue;
      try {
        await apDung(d, categoryId);
        thanhCong++;
      } catch (e) {
        // Một dòng hỏng không chặn các dòng sau (spec §5).
        loi++;
        debugPrint('[GanDanhMuc] gắn $id lỗi: $e');
        continue;
      }
      final ph = phanHoiGan(d, categoryId);
      if (ph == null) continue;
      try {
        await ghi(d, ph.ketQua, ph.chonCategoryId);
      } catch (e) {
        // Phản hồi hỏng không được biến một lần gắn thành công thành lỗi.
        debugPrint('[GanDanhMuc] ghi phản hồi $id lỗi: $e');
      }
    }
    final cau = cauKetQuaGan(thanhCong: thanhCong, loi: loi);
    if (cau != null && sl.isRegistered<ThongBaoNhanh>()) sl<ThongBaoNhanh>().hien(cau);
    if (!mounted) return;
    setState(() => _dangApDung = false);
    if (context.canPop()) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Gắn danh mục nhanh',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: _than(),
      bottomNavigationBar: _du == null || _du!.dong.isEmpty ? null : _thanhDay(),
    );
  }

  Widget _than() {
    if (widget.idaccount == null) {
      return const Center(child: Text('Chưa xác định được tài khoản đăng nhập'));
    }
    if (_loiTai) {
      return const Center(
        child: Text('Không đọc được sổ giao dịch', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final du = _du;
    if (du == null) return const Center(child: CircularProgressIndicator());
    if (du.dong.isEmpty) {
      return const Center(
        child: Text('Mọi giao dịch đều đã có danh mục', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final coDoan = [for (final d in du.dong) if (d.doan != null) d];
    final khong = [for (final d in du.dong) if (d.doan == null) d];
    final ten = {for (final c in du.chonDuoc) c.id: c};
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                coDoan.isEmpty
                    ? 'Chưa đoán được danh mục nào từ ghi chú của bạn. Chọn danh mục cho từng khoản rồi bấm Áp dụng.'
                    : 'Danh mục được đoán từ những ghi chú bạn từng gắn. Kiểm tra rồi bấm Áp dụng, trước đó chưa có gì '
                        'được lưu.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final d in coDoan) _dong(d, ten),
        // Tiêu đề nhóm chỉ có nghĩa khi có cả hai nhóm — màn toàn dòng chưa đoán thì câu trên đã nói rồi.
        if (coDoan.isNotEmpty && khong.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 10),
            child: Text(
              'CHƯA ĐOÁN ĐƯỢC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        for (final d in khong) _dong(d, ten),
      ],
    );
  }

  Widget _dong(DongGanDanhMuc d, Map<String, Category> ten) {
    final t = d.giaoDich;
    final ghiChu = t.note.trim();
    final thu = t.type == 'thu';
    final danhMuc = ten[_chon[t.id]];
    final coDanhMuc = danhMuc != null;
    final tenVi = _du?.tenVi[t.walletId];
    return Container(
      key: Key('gan-dong-${t.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: Key('gan-tick-${t.id}'),
            value: coDanhMuc && _tick.contains(t.id),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            // Chưa có danh mục thì không có gì để gắn — tick sẽ được bật khi người dùng chọn danh mục.
            onChanged: !coDanhMuc || _dangApDung
                ? null
                : (v) => setState(() => v == true ? _tick.add(t.id) : _tick.remove(t.id)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ghiChu.isEmpty ? '(Không có ghi chú)' : ghiChu,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: ghiChu.isEmpty ? FontWeight.w400 : FontWeight.w600,
                            fontStyle: ghiChu.isEmpty ? FontStyle.italic : FontStyle.normal,
                            color: ghiChu.isEmpty ? AppColors.textSecondary : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.formatCoDau(t.amount, thu: thu),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: thu ? AppColors.income : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [DateFormat('dd/MM').format(t.date), if (tenVi != null) tenVi].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  _chip(d, danhMuc),
                  if (d.lyDo != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            d.lyDo!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(DongGanDanhMuc d, Category? danhMuc) {
    final onTap = _dangApDung ? null : () => _chonDanhMuc(d);
    if (danhMuc == null) {
      return InkWell(
        key: Key('gan-chip-${d.giaoDich.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: const CustomPaint(
          painter: _VienNetDut(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 4),
                Text('Chọn danh mục', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }
    final mau = categoryColorFrom(danhMuc.colour);
    return InkWell(
      key: Key('gan-chip-${d.giaoDich.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: mau.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIconFor(danhMuc.icon), size: 16, color: mau),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                danhMuc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mau),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 16, color: mau),
          ],
        ),
      ),
    );
  }

  Widget _thanhDay() {
    final n = _soDangTick;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          key: const Key('gan-ap-dung'),
          onPressed: n == 0 || _dangApDung ? null : _apDung,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            _dangApDung ? 'Đang lưu…' : 'Áp dụng $n',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Viền nét đứt bo tròn cho chip *"+ Chọn danh mục"* — Flutter không có sẵn, và màn Stitch vẽ nét đứt để chip trống
/// trông khác hẳn một chip đã có danh mục.
class _VienNetDut extends CustomPainter {
  const _VienNetDut();

  @override
  void paint(Canvas canvas, Size size) {
    final but = Paint()
      ..color = AppColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final duong = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2)));
    for (final m in duong.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), but);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VienNetDut oldDelegate) => false;
}
