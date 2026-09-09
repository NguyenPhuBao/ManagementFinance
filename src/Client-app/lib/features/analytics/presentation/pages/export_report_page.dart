import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/bao_cao_repository.dart';
import '../../domain/bao_cao_xuat.dart';
import 'report_preview_page.dart';

/// Trang **Xuất báo cáo** — chọn bộ lọc rồi mở màn Xem trước.
///
/// Bố cục theo màn Stitch "Xuất Báo cáo Tài chính - FlowMoney". Ba khối của
/// bản Stitch đã bỏ vì **không có gì đỡ phía sau**: lịch sử xuất (cần một bảng
/// cục bộ để ghi lại), ô mật khẩu PDF, và dòng "Đích đến". Ô `.xlsx` cũng bỏ:
/// nó cần thêm một thư viện nữa mà `.csv` đã phục vụ đúng nhu cầu "phù hợp
/// tính toán".
///
/// Trước 2026-09-09 trang này là **số cứng**: ví "Techcombank" bịa, lịch sử
/// xuất bịa, nút xuất chỉ hiện snackbar.
class ExportReportPage extends StatefulWidget {
  /// Tiêm đồng hồ để test không phụ thuộc ngày chạy máy.
  final DateTime Function()? clock;

  /// Phạm vi đặt sẵn, đến từ `?from=&to=` của route.
  ///
  /// Đường vào của thông báo **Tổng kết tuần**: nó mở trang này với đúng tuần
  /// vừa khép thay vì để người dùng tự chọn lại. [denNgay] là ngày **cuối cùng
  /// được tính vào** — cùng quy ước với bộ chọn khoảng ngày, và
  /// `khoangCuaPhamVi` tự cộng thêm một ngày để ra biên mở.
  ///
  /// Thiếu một trong hai, hoặc [denNgay] đứng trước [tuNgay], thì bỏ qua cả
  /// cặp và trang lùi về "tháng này": một phạm vi nửa vời còn khó hiểu hơn
  /// phạm vi mặc định.
  final DateTime? tuNgay;
  final DateTime? denNgay;

  const ExportReportPage({
    super.key,
    this.clock,
    this.tuNgay,
    this.denNgay,
  });

  @override
  State<ExportReportPage> createState() => _ExportReportPageState();
}

class _ExportReportPageState extends State<ExportReportPage> {
  late PhamViThoiGian _pv;
  ({DateTime from, DateTime to})? _tuyChon;

  @override
  void initState() {
    super.initState();
    final tu = widget.tuNgay;
    final den = widget.denNgay;
    final hopLe = tu != null && den != null && !den.isBefore(tu);
    _pv = hopLe ? PhamViThoiGian.tuyChinh : PhamViThoiGian.thangNay;
    if (hopLe) _tuyChon = (from: tu, to: den);
  }

  String? _walletId;
  String _nhanVi = 'Tất cả các ví';
  String? _categoryId;
  String _nhanDanhMuc = 'Tất cả danh mục';

  String _dinhDang = 'pdf';
  bool _dangDung = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  static const _nhanPhamVi = {
    PhamViThoiGian.thangNay: 'Tháng này',
    PhamViThoiGian.thangTruoc: 'Tháng trước',
    PhamViThoiGian.quyNay: 'Quý này',
    PhamViThoiGian.tuyChinh: 'Tùy chỉnh',
  };

  @override
  Widget build(BuildContext context) {
    // ĐĂNG KÝ với AuthBloc chứ không chỉ đọc một phát — cùng lý do với trang
    // Phân tích: phiên tới muộn thì trang phải dựng lại.
    context.watch<AuthBloc>();
    final idaccount = currentAccountIdOrNull(context);
    final repo = sl<BaoCaoRepository>();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Xuất Báo cáo Tài chính',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _the(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _nhanMuc('LOẠI BÁO CÁO'),
                  const SizedBox(height: 8),
                  _oTinh('Báo cáo Tổng quan Thu Chi'),
                  const SizedBox(height: 20),
                  _nhanMuc('THỜI GIAN'),
                  const SizedBox(height: 8),
                  _chonThoiGian(),
                  const SizedBox(height: 20),
                  _nhanMuc('LỌC THEO VÍ'),
                  const SizedBox(height: 8),
                  _chipVi(repo, idaccount),
                  const SizedBox(height: 20),
                  _nhanMuc('DANH MỤC'),
                  const SizedBox(height: 8),
                  _oChonDanhMuc(repo, idaccount),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _the(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _nhanMuc('ĐỊNH DẠNG TỆP'),
                  const SizedBox(height: 12),
                  _oDinhDang(
                    id: 'pdf',
                    icon: Icons.picture_as_pdf_outlined,
                    tieuDe: 'Tệp PDF (.pdf)',
                    phu: 'Đầy đủ bảng kê',
                  ),
                  const SizedBox(height: 10),
                  _oDinhDang(
                    id: 'csv',
                    icon: Icons.insert_drive_file_outlined,
                    tieuDe: 'Tệp CSV (.csv)',
                    phu: 'Dữ liệu thô, mở được bằng Excel',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (idaccount == null || _dangDung)
                    ? null
                    : () => _moXemTruoc(repo, idaccount),
                icon: _dangDung
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.visibility_outlined,
                        color: Colors.white),
                label: const Text(
                  'Xem trước báo cáo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _moXemTruoc(BaoCaoRepository repo, int idaccount) async {
    final k = khoangCuaPhamVi(_pv, now: _now, tuyChon: _tuyChon);
    setState(() => _dangDung = true);
    try {
      final bc = await repo.layBaoCao(
        idaccount,
        loc: LocBaoCao(
          from: k.from,
          to: k.to,
          walletId: _walletId,
          categoryId: _categoryId,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportPreviewPage(
            baoCao: bc,
            nhanVi: _nhanVi,
            nhanDanhMuc: _nhanDanhMuc,
            dinhDang: _dinhDang.toUpperCase(),
            lapNgay: _now,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _dangDung = false);
    }
  }

  Future<void> _chonKhoangTuyChinh() async {
    final chon = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(_now.year + 1, 12, 31),
      currentDate: _now,
    );
    if (!mounted) return;
    setState(() {
      _pv = PhamViThoiGian.tuyChinh;
      // `null` khi người dùng thoát bộ chọn — giữ nguyên khoảng cũ thay vì
      // xoá, và `khoangCuaPhamVi` tự lùi về tháng này nếu chưa từng chọn.
      if (chon != null) _tuyChon = (from: chon.start, to: chon.end);
    });
  }

  Widget _chonThoiGian() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final pv in PhamViThoiGian.values)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (pv == PhamViThoiGian.tuyChinh) {
                      _chonKhoangTuyChinh();
                    } else {
                      setState(() => _pv = pv);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _pv == pv ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _pv == pv
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _nhanPhamVi[pv]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              _pv == pv ? FontWeight.w600 : FontWeight.w500,
                          color: _pv == pv
                              ? AppColors.primary
                              : const Color(0xFF46464C),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _chipVi(BaoCaoRepository repo, int? idaccount) {
    if (idaccount == null) return _oTinh('Chưa đăng nhập');
    return StreamBuilder<List<LuaChonLoc>>(
      stream: repo.watchVi(idaccount),
      builder: (context, snap) {
        final ds = snap.data ?? const <LuaChonLoc>[];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('Tất cả các ví', _walletId == null, () {
              setState(() {
                _walletId = null;
                _nhanVi = 'Tất cả các ví';
              });
            }),
            for (final v in ds)
              _chip(v.ten, _walletId == v.id, () {
                setState(() {
                  _walletId = v.id;
                  _nhanVi = v.ten;
                });
              }),
          ],
        );
      },
    );
  }

  Widget _chip(String ten, bool chon, VoidCallback onTap) => ChoiceChip(
        label: Text(ten),
        selected: chon,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: chon ? Colors.white : const Color(0xFF46464C),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: chon ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
        showCheckmark: false,
      );

  Widget _oChonDanhMuc(BaoCaoRepository repo, int? idaccount) => InkWell(
        onTap: idaccount == null ? null : () => _moSheetDanhMuc(repo, idaccount),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _nhanDanhMuc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.category_outlined,
                  color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      );

  Future<void> _moSheetDanhMuc(BaoCaoRepository repo, int idaccount) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StreamBuilder<List<LuaChonLoc>>(
          stream: repo.watchDanhMuc(idaccount),
          builder: (context, snap) {
            final ds = snap.data ?? const <LuaChonLoc>[];
            return ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Tất cả danh mục'),
                  trailing: _categoryId == null
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() {
                      _categoryId = null;
                      _nhanDanhMuc = 'Tất cả danh mục';
                    });
                    Navigator.of(sheetContext).pop();
                  },
                ),
                for (final c in ds)
                  ListTile(
                    title: Text(c.ten),
                    trailing: _categoryId == c.id
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _categoryId = c.id;
                        _nhanDanhMuc = c.ten;
                      });
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _oDinhDang({
    required String id,
    required IconData icon,
    required String tieuDe,
    required String phu,
  }) {
    final chon = _dinhDang == id;
    return GestureDetector(
      onTap: () => setState(() => _dinhDang = id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: chon
              ? const Color(0xFFDEE1F8).withValues(alpha: 0.2)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: chon ? AppColors.primary : AppColors.outlineVariant,
            width: chon ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: chon ? AppColors.primary : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: chon ? Colors.white : const Color(0xFF46464C),
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tieuDe,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phu,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF46464C),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              chon ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: chon ? AppColors.primary : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _nhanMuc(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF46464C),
          letterSpacing: 0.8,
        ),
      );

  Widget _oTinh(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _the({required Widget child}) => Container(
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
