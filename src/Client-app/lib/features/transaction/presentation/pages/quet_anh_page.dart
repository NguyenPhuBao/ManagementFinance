/// A5 — nút **Quét** ở Trang chủ (spec `2026-10-07-a5-quet-hoa-don-bien-lai-design.md` mục 3, 5.7): bottom sheet chọn
/// nguồn ảnh → màn *"Đang đọc ảnh…"* (Stitch `353934f2…`) → form Thêm giao dịch điền sẵn (`/add?khoa=quet:…`).
///
/// Luật trước (ML Kit qua `DocChuAnh` → `ghepDongTheoHang` → `docAnhQuet`). Hoá đơn + Premium + mô hình + công tắc →
/// Gemma NHÌN ẢNH đọc món + tổng (`DocAnhBangGemma`, spec A5 mục 13 — người dùng chốt: AI đọc món và tổng, luật đọc phần
/// còn lại). Số tiền của MỌI hoá đơn — kể cả Basic — chốt bằng `chotTongQuet`: khớp → điền, lệch / số luật đáng ngờ →
/// ô trống (+ hai chip trên form) — G101. Biên lai chỉ luật (Gemma chưa đo trên biên lai). Không ghi gì — người dùng bấm
/// Lưu trên form (bất biến ④).
///
/// ⚠️ Tệp DUY NHẤT của `lib/` import `image_picker` — test quét thứ 20
/// (`chi_mot_noi_import_image_picker_test.dart`).
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/bloc/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/ocr/doc_chu_anh.dart';
import '../../../../core/ocr/dong_ocr.dart';
import '../../data/datasources/kho_anh_quet.dart';
import '../../../../core/ocr/tep_tam_chon_anh.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../premium/presentation/bloc/goi_cubit.dart';
import '../../../category/data/repositories/category_management_repository.dart';
import '../../../category/domain/category_classify.dart' show hopLeTheoChieu;
import '../../data/doc_anh_bang_gemma.dart';
import '../../data/doc_danh_muc_bang_ai.dart';
import '../../domain/chot_tong_quet.dart';
import '../../domain/dien_san_bien_dong.dart';
import '../../domain/doc_anh_gemma.dart' show KetQuaGemmaAnh;
import '../../domain/doc_anh_quet.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../../shared/theme/app_colors.dart';

enum NguonAnh { mayAnh, thuVien }

/// Chụp / chọn ảnh → đường dẫn tệp tạm; `null` = người dùng huỷ. Tiêm cho test.
typedef ChonAnh = Future<String?> Function(NguonAnh nguon);

const String kCauChuaDocAnh = 'Chưa đọc được ảnh — nhập tay nhé';
const String kCauChuaDocTien = 'Chưa đọc được số tiền — nhập tay nhé';

Future<String?> _chonAnhThat(NguonAnh n) async {
  final x = await ImagePicker().pickImage(
    source: n == NguonAnh.mayAnh ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1280,
    imageQuality: 85,
  );
  return x?.path;
}

/// Lời nhắc chụp ở sheet chọn nguồn (G105, người dùng chọn 2026-10-22): vật có chữ lọt vào mép ảnh thì chữ của nó có thể
/// thắng tên cửa hàng trên form (Realme: thẻ tiếng Anh ở mép → ghi chú *"ral Setl Ths cad rd effect"*).
const kNhacChupSat = 'Chụp sát tờ hoá đơn, đừng để vật có chữ lọt vào khung';

/// Bottom sheet chọn nguồn ảnh (Stitch `50e001f2…` *"Trang chủ - Chọn nguồn ảnh để Quét"* — bản có dòng nhắc, thay
/// `8027b781…`; tiêu đề, dòng khoá, dòng nhắc
/// chụp [kNhacChupSat], hai lựa chọn có dòng phụ, Huỷ) → chụp / chọn → `push('/quet')`. Đóng sheet / huỷ máy ảnh = không gì.
///
/// ⚠️ `useRootNavigator`: nút Quét nằm trong nhánh của shell, sheet mở ở navigator nhánh thì thanh điều hướng + nút +
/// đè lên nó và che nút Huỷ (nghiệm thu OnePlus 2026-10-08). `isScrollControlled` + cuộn: ở 320 dp chữ ×1,3 hai dòng ghi
/// chú và dòng phụ xuống dòng, sheet cao hơn trần 9/16 màn của sheet thường.
Future<void> moQuet(BuildContext context, {ChonAnh? chonAnh}) async {
  final nguon = await showModalBottomSheet<NguonAnh>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _SheetChonNguon(),
  );
  if (nguon == null || !context.mounted) return;
  final duongDan = await (chonAnh ?? _chonAnhThat)(nguon);
  if (duongDan == null || !context.mounted) return;
  await context.push('/quet', extra: duongDan);
}

class _SheetChonNguon extends StatelessWidget {
  const _SheetChonNguon();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quét hoá đơn / biên lai',
                    style: TextStyle(
                      fontSize: 20,
                      height: 28 / 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  _DongGhiChu(Icons.lock_outline, 'Ảnh được đọc ngay trên máy, không gửi đi đâu'),
                  SizedBox(height: 4),
                  _DongGhiChu(Icons.crop_free, kNhacChupSat),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LuaChonNguon(
              key: const Key('quet-chup-anh'),
              icon: Icons.photo_camera_outlined,
              ten: 'Chụp ảnh',
              phu: 'Hoá đơn giấy, màn hình máy khác',
              onTap: () => Navigator.pop(context, NguonAnh.mayAnh),
            ),
            const SizedBox(height: 8),
            _LuaChonNguon(
              key: const Key('quet-chon-anh'),
              icon: Icons.photo_library_outlined,
              ten: 'Chọn ảnh có sẵn',
              phu: 'Ảnh chụp màn hình biên lai chuyển khoản',
              onTap: () => Navigator.pop(context, NguonAnh.thuVien),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLow,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Huỷ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dòng chữ nhỏ có biểu tượng dưới tiêu đề sheet (dòng khoá, dòng nhắc chụp) — xuống dòng, không cắt.
class _DongGhiChu extends StatelessWidget {
  const _DongGhiChu(this.icon, this.chu);
  final IconData icon;
  final String chu;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(chu, style: const TextStyle(fontSize: 13, height: 1.375, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

/// Một lựa chọn nguồn ảnh: vòng biểu tượng, tên, dòng phụ (xuống dòng ở khổ hẹp), mũi tên.
class _LuaChonNguon extends StatelessWidget {
  const _LuaChonNguon({super.key, required this.icon, required this.ten, required this.phu, required this.onTap});
  final IconData icon;
  final String ten;
  final String phu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: AppColors.surfaceContainerLow, shape: BoxShape.circle),
                  child: Icon(icon, size: 24, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ten,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(phu, style: const TextStyle(fontSize: 12, height: 1.25, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Pha { luat, ai }

class QuetAnhPage extends StatefulWidget {
  const QuetAnhPage({
    super.key,
    required this.duongDanAnh,
    this.docChu,
    this.kho,
    this.docGemma,
    this.docDanhMuc,
    this.tenDanhMucChi,
    this.laPremium,
    this.now,
  });

  /// Ảnh vừa chụp / chọn (tệp tạm của `image_picker`) — được CHÉP vào kho; bản tạm trong `cache/` bị xoá khi màn đóng
  /// ([xoaTepTamChonAnh]).
  final String duongDanAnh;

  /// `null` → `sl<…>()` nếu đã đăng ký.
  final DocChuAnh? docChu;
  final KhoAnhQuet? kho;
  final DocAnhBangGemma? docGemma;

  /// A5 mục 13 — Gemma lần hai chọn danh mục (người dùng chốt "AI chọn danh mục").
  final DocDanhMucBangAi? docDanhMuc;

  /// Tên các danh mục CHI chọn được của tài khoản. `null` → đọc qua `CategoryManagementRepository`.
  final Future<List<String>> Function()? tenDanhMucChi;

  /// `null` → `GoiCubit` qua `context`; không có provider thì coi như Premium (chỉ test cũ gặp).
  final bool? laPremium;
  final DateTime Function()? now;

  @override
  State<QuetAnhPage> createState() => _QuetAnhPageState();
}

class _QuetAnhPageState extends State<QuetAnhPage> {
  var _pha = _Pha.luat;

  /// Bấm Huỷ ở pha luật: chờ OCR về rồi thoát, xoá ảnh. `_chay` xét cờ HAI lần — sau OCR và sau khi lưu món (lúc ấy nút
  /// đã khoá ở "Đang huỷ…", nên lần xét thứ hai là chỗ duy nhất Huỷ ấy còn có tác dụng).
  var _huyLuat = false;

  DocChuAnh? get _docChu => widget.docChu ?? (sl.isRegistered<DocChuAnh>() ? sl<DocChuAnh>() : null);
  KhoAnhQuet? get _kho => widget.kho ?? (sl.isRegistered<KhoAnhQuet>() ? sl<KhoAnhQuet>() : null);
  DocAnhBangGemma? get _docGemma =>
      widget.docGemma ?? (sl.isRegistered<DocAnhBangGemma>() ? sl<DocAnhBangGemma>() : null);
  DocDanhMucBangAi? get _docDanhMuc =>
      widget.docDanhMuc ?? (sl.isRegistered<DocDanhMucBangAi>() ? sl<DocDanhMucBangAi>() : null);

  /// Tín hiệu Huỷ cho lượt đọc ảnh: `_chay` thôi CHỜ nó mà mở form ngay với kết quả luật (người dùng duyệt 2026-10-22).
  /// Lời gọi native không ngắt được tức thì (Realme CPU 2026-10-21: màn đứng ~5 s sau Huỷ) nên lượt ấy chạy nốt ở nền —
  /// `DocAnhBangGemma` bỏ kết quả của nó (bộ đếm lượt), và lời gọi mô hình kế tiếp chờ nó xong (`LuotKhongNgatDuoc`
  /// trong `SlmRuntimeThat`).
  final _tinHuyAi = Completer<void>();

  /// Đã bấm Huỷ ở pha AI: `_chay` không hỏi danh mục bằng mô hình nữa, và bỏ danh mục AI nếu lượt hỏi ấy về sau Huỷ.
  bool get _huyAi => _tinHuyAi.isCompleted;

  Future<List<String>> _tenDanhMucChi() async {
    final f = widget.tenDanhMucChi;
    if (f != null) return f();
    final id = currentAccountIdOrNull(context);
    if (id == null || !sl.isRegistered<CategoryManagementRepository>()) return const [];
    try {
      final ds = await sl<CategoryManagementRepository>().selectableChildrenAll(accountId: id);
      final hopLe = hopLeTheoChieu('chi', ds);
      return [for (final c in ds) if (hopLe.contains(c.id)) c.name];
    } catch (e) {
      debugPrint('[Quet][danhMuc] đọc danh mục lỗi: $e');
      return const [];
    }
  }

  bool get _laPremium {
    final t = widget.laPremium;
    if (t != null) return t;
    try {
      return context.read<GoiCubit>().coQuyen(MaQuyen.aiEdgeModel);
    } on ProviderNotFoundException {
      return true;
    }
  }

  /// `_chay` đã kết thúc nhưng lúc ấy có màn khác đè lên (form trống của nút +, deeplink thông báo) — màn này chờ tới
  /// khi người dùng quay về tới nó rồi tự đóng. Nghiệm thu OnePlus 2026-10-08: thiếu cờ này `/quet` nằm lại dưới form,
  /// Huỷ / Back không làm gì nữa, người dùng kẹt ở "Đang đọc bằng AI…".
  var _xong = false;

  @override
  void initState() {
    super.initState();
    unawaited(_chay());
  }

  @override
  void dispose() {
    // Bản sao image_picker để lại trong cache (ảnh nền mờ của màn này dùng nó tới lúc đóng). Kho đã chép ảnh riêng.
    xoaTepTamChonAnh(widget.duongDanAnh);
    super.dispose();
  }

  /// `true` khi chưa gắn vào route nào (test dựng trần) — coi như đang ở trên cùng.
  bool get _oTrenCung => ModalRoute.isCurrentOf(context) ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `isCurrentOf` đăng ký phụ thuộc: route thành trên cùng trở lại thì hàm này chạy lại. Gọi TRƯỚC `_xong` — đặt sau
    // thì lần đầu (`_xong` còn false) không đăng ký gì và màn không bao giờ biết mình được quay về.
    final trenCung = _oTrenCung;
    if (_xong && trenCung) WidgetsBinding.instance.addPostFrameCallback((_) => _ve());
  }

  /// Rời màn này. `context.pop()` đóng màn TRÊN CÙNG, nên chỉ gọi khi chính nó ở trên cùng; không thì chờ quay về.
  void _ve() {
    if (!mounted) return;
    if (_oTrenCung) {
      _xong = false;
      context.pop();
    } else {
      _xong = true;
    }
  }

  Future<void> _chay() async {
    final kho = _kho;
    final docChu = _docChu;
    final ten = kho == null ? null : await kho.luu(widget.duongDanAnh);
    if (kho == null || docChu == null || ten == null) {
      baoNhanh(kCauChuaDocAnh);
      _ve();
      return;
    }
    final duong = await kho.duongDan(ten);
    final dong = duong == null ? const <DongOcr>[] : await docChu.doc(duong);
    if (!mounted) return;
    if (_huyLuat) {
      await kho.xoa(ten);
      _ve();
      return;
    }
    final van = ghepDongTheoHang(dong);
    final luc = (widget.now ?? DateTime.now)();
    var kq = docAnhQuet(vanBan: van, luc: luc);
    // Bản debug: chữ OCR + kết quả luật — để nghiệm thu máy thật đối chiếu (ảnh khác máy thì OCR khác). Bản release
    // không in chữ ảnh của người dùng.
    if (kDebugMode) {
      for (final h in van.split('\n')) {
        // ignore: avoid_print
        print('[Quet][OCR] $h');
      }
      // ignore: avoid_print
      print('[Quet][luat] tong=${kq.soTien} | ghi="${kq.ghiChu}" | luc=${kq.thoiGian} | thieu=${kq.oThieu}');
    }
    if (kq.mon.isNotEmpty) await kho.luuMon(ten, kq.mon);
    // Huỷ bấm trong lúc lưu món (sau phép xét ở trên, trước pha AI): nút đã thành "Đang huỷ…" và bị khoá — không xét lại
    // thì Premium chạy trọn pha AI mà không Huỷ được, Basic mở form như chưa từng Huỷ (2026-10-22).
    if (!mounted) return;
    if (_huyLuat) {
      await kho.xoa(ten);
      _ve();
      return;
    }
    var chon = const <double>[];
    String? danhMuc;
    int? tongAi;
    final g = _docGemma;
    if (van.trim().isNotEmpty && kq.loai == LoaiAnhQuet.hoaDon && g != null && duong != null && _laPremium) {
      setState(() => _pha = _Pha.ai);
      // Đọc ĐỒNG BỘ: ảnh đã thu về rộng ≤ 1280 (vài trăm KB); I/O bất đồng bộ không chạy dưới FakeAsync của widget
      // test (cùng lý do `KhoBienLai.xoa`).
      final a = await Future.any([
        g.doc(File(duong).readAsBytesSync()),
        _tinHuyAi.future.then<KetQuaGemmaAnh?>((_) => null),
      ]);
      tongAi = a?.tong;
      final hoiDm = _docDanhMuc;
      if (hoiDm != null && !_huyAi && mounted) {
        final mon = [for (final m in a?.mon ?? const <({String ten, double soTien})>[]) m.ten];
        danhMuc = await hoiDm.chon(
          cuaHang: kq.ghiChu,
          mon: mon.isNotEmpty ? mon : [for (final m in kq.mon) if (m.soTien > 0) m.ten],
          tenDanhMuc: await _tenDanhMucChi(),
        );
        if (danhMuc != null) kq = kq.copyWith(aiLap: true);
      }
    }
    // Mọi hoá đơn đi qua phép chốt, kể cả Basic và Huỷ pha AI (`tongAi` null) — số luật đứng một mình cũng phải qua lưới
    // A / B (G101: Basic từng được điền sẵn 2.127 cho tờ 72.127). Biên lai giữ số của `docBienLai`.
    if (kq.loai == LoaiAnhQuet.hoaDon) {
      final c = chotTongQuet(luat: kq.soTien, ai: tongAi, vanBan: van);
      final soAi = tongAi?.toDouble();
      // Phần số tiền chỉ bật "Đọc bằng AI" khi số mô hình nằm trên form — hai chip của hai số OCR (lưới B) không phải
      // của AI. Danh mục do Gemma chọn đã bật cờ ở trên (`voiSoTien` giữ nó).
      kq = kq.voiSoTien(c.soTien, aiLap: soAi != null && (c.soTien == soAi || c.luaChon.contains(soAi)));
      chon = c.luaChon;
    }
    if (!mounted) return;
    if (van.trim().isEmpty) {
      baoNhanh(kCauChuaDocAnh);
    } else if (kq.soTien == null && chon.isEmpty) {
      baoNhanh(kCauChuaDocTien);
    }
    final link = deeplinkQuet(kq, anh: ten, luaChonTien: chon, danhMucAi: _huyAi ? null : danhMuc);
    if (_oTrenCung) {
      // Thay CHÍNH màn này bằng form: Back từ form về Trang chủ, không về màn "Đang đọc ảnh…".
      context.pushReplacement(link);
    } else {
      // `pushReplacement` thay màn TRÊN CÙNG — màn người dùng vừa mở. Mở form lên trên, màn này tự đóng khi quay về.
      _xong = true;
      unawaited(context.push(link));
    }
  }

  void _bamHuy() {
    if (_xong) {
      _ve();
      return;
    }
    if (_pha == _Pha.ai) {
      // `_chay` thôi chờ lượt đọc ảnh → mở form với kết quả luật NGAY, không đợi native trả về.
      if (!_tinHuyAi.isCompleted) _tinHuyAi.complete();
      unawaited(_docGemma?.huy());
      unawaited(_docDanhMuc?.huy());
      return;
    }
    setState(() => _huyLuat = true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (daPop, _) {
        if (!daPop) _bamHuy();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(widget.duongDanAnh),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 20),
                    Text(
                      _pha == _Pha.ai ? 'Đang đọc bằng AI…' : 'Đang đọc ảnh…',
                      key: const Key('quet-trang-thai'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      key: const Key('quet-huy'),
                      onPressed: _huyLuat ? null : _bamHuy,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size(160, 48),
                      ),
                      child: Text(_huyLuat ? 'Đang huỷ…' : 'Huỷ'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
