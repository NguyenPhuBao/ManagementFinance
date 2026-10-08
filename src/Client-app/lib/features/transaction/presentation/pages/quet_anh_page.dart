/// A5 — nút **Quét** ở Trang chủ (spec `2026-10-07-a5-quet-hoa-don-bien-lai-design.md` mục 3, 5.7): bottom sheet chọn
/// nguồn ảnh → màn *"Đang đọc ảnh…"* (Stitch `353934f2…`) → form Thêm giao dịch điền sẵn (`/add?khoa=quet:…`).
///
/// Luật trước (ML Kit qua `DocChuAnh` → `ghepDongTheoHang` → `docAnhQuet`). Hoá đơn + Premium + mô hình + công tắc →
/// Gemma NHÌN ẢNH đọc món + tổng (`DocAnhBangGemma`, spec A5 mục 13 — người dùng chốt: AI đọc món và tổng, luật đọc phần
/// còn lại); số tiền chốt bằng `chotTongQuet`: khớp → điền, lệch → ô trống + hai chip trên form. Biên lai chỉ luật
/// (Gemma chưa đo trên biên lai). Không ghi gì — người dùng bấm Lưu trên form (bất biến ④).
///
/// ⚠️ Tệp DUY NHẤT của `lib/` (ngoài màn spike C4) import `image_picker` — test quét thứ 20
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

import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/ocr/doc_chu_anh.dart';
import '../../../../core/ocr/dong_ocr.dart';
import '../../../../core/ocr/kho_anh_quet.dart';
import '../../../../core/ocr/tep_tam_chon_anh.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../../features/premium/presentation/cubit/goi_cubit.dart';
import '../../../category/data/repositories/category_management_repository.dart';
import '../../../category/domain/gan_hang_loat.dart';
import '../../data/doc_anh_bang_gemma.dart';
import '../../data/doc_danh_muc_bang_ai.dart';
import '../../domain/chot_tong_quet.dart';
import '../../domain/dien_san_bien_dong.dart';
import '../../domain/doc_anh_quet.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';

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

/// Bottom sheet hai dòng (Stitch `8027b781…`) → chụp / chọn → `push('/quet')`. Đóng sheet / huỷ máy ảnh = không gì.
///
/// ⚠️ `useRootNavigator`: nút Quét nằm trong nhánh của shell, sheet mở ở navigator nhánh thì thanh điều hướng + nút +
/// đè lên nó và che nút Huỷ (nghiệm thu OnePlus 2026-10-08).
Future<void> moQuet(BuildContext context, {ChonAnh? chonAnh}) async {
  final nguon = await showModalBottomSheet<NguonAnh>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('quet-chup-anh'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(ctx, NguonAnh.mayAnh),
          ),
          ListTile(
            key: const Key('quet-chon-anh'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn ảnh có sẵn'),
            onTap: () => Navigator.pop(ctx, NguonAnh.thuVien),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (nguon == null || !context.mounted) return;
  final duongDan = await (chonAnh ?? _chonAnhThat)(nguon);
  if (duongDan == null || !context.mounted) return;
  await context.push('/quet', extra: duongDan);
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

  /// Bấm Huỷ ở pha luật: chờ OCR về rồi thoát, xoá ảnh.
  var _huyLuat = false;

  DocChuAnh? get _docChu => widget.docChu ?? (sl.isRegistered<DocChuAnh>() ? sl<DocChuAnh>() : null);
  KhoAnhQuet? get _kho => widget.kho ?? (sl.isRegistered<KhoAnhQuet>() ? sl<KhoAnhQuet>() : null);
  DocAnhBangGemma? get _docGemma =>
      widget.docGemma ?? (sl.isRegistered<DocAnhBangGemma>() ? sl<DocAnhBangGemma>() : null);
  DocDanhMucBangAi? get _docDanhMuc =>
      widget.docDanhMuc ?? (sl.isRegistered<DocDanhMucBangAi>() ? sl<DocDanhMucBangAi>() : null);

  /// Bấm Huỷ ở pha AI: lượt đang chạy trả `null`, và KHÔNG gọi mô hình lần hai.
  var _huyAi = false;

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
    var chon = const <double>[];
    String? danhMuc;
    final g = _docGemma;
    if (van.trim().isNotEmpty && kq.loai == LoaiAnhQuet.hoaDon && g != null && duong != null && _laPremium) {
      setState(() => _pha = _Pha.ai);
      // Đọc ĐỒNG BỘ: ảnh đã thu về rộng ≤ 1280 (vài trăm KB); I/O bất đồng bộ không chạy dưới FakeAsync của widget
      // test (cùng lý do `KhoBienLai.xoa`).
      final a = await g.doc(File(duong).readAsBytesSync());
      if (a?.tong case final tong?) {
        final c = chotTongQuet(luat: kq.soTien, ai: tong, vanBan: van);
        kq = kq.voiSoTien(c.soTien, aiLap: c.luaChon.isNotEmpty || c.soTien == tong.toDouble());
        chon = c.luaChon;
      }
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
      // Lượt sinh trả null → `_chay` mở form với kết quả luật.
      _huyAi = true;
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
