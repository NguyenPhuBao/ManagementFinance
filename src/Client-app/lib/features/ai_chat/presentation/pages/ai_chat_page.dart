// lib/features/ai_chat/presentation/pages/ai_chat_page.dart
/// Màn **Trợ lý AI** — nơi DUY NHẤT mô hình trên máy phục vụ.
///
/// Lối B, người dùng chốt 2026-09-21: sáu khối Nhận xét của P2 **giữ mẫu câu**
/// (P1 đo được câu mô hình ở đó gần bằng mẫu, mà giá là 2,3 giây mỗi khối);
/// mô hình chỉ hơn hẳn ở **hỏi đáp tự do**, tức đúng màn này. Vì thế màn này
/// **tự dựng** đường sinh câu từ `sl<SlmRuntime>()` chứ không đọc
/// `sl<BoDienGiai>()` — DI cố ý không đăng ký nó.
///
/// ⚠️ Bản trước là **mockup tĩnh**: nó in *"Bạn đã chi 3.200.000đ"* và *"Ăn
/// uống tăng 35% (chủ yếu là Cafe & ShopeeFood)"* — những con số không đến từ
/// dữ liệu nào cả, cộng năm nút không có handler. Đó đúng loại lỗi mà thẻ
/// "Insight AI" (A6) đã phải gỡ: hứa một tính năng không tồn tại.
///
/// Không lưu lịch sử qua phiên (spec mục 4.6).
///
/// **Chữ hiện dần theo CÂU** (việc số 1, người dùng chốt 2026-09-22): token
/// của mô hình đi qua `gacTheoCau` — đủ một câu thì `kiemCauTraLoi` (số +
/// nhãn + giọng) rồi mới hiện; câu trượt thì huỷ sinh và **không bao giờ
/// hiện**. Đã có câu hiện rồi mới trượt thì giữ nguyên các câu ấy (chúng đều
/// đã kiểm) và dừng; chưa câu nào thì hiện câu lùi "chưa chắc".
///
/// **Bậc tool** (chặng 4b, 2026-09-23): câu hỏi đi qua `hoiBangCongCu` — mô hình
/// chọn một trong các tool đọc của `BoCongCu` (bốn từ chặng 4b, bảy từ bước 2),
/// hàng trả về tích luỹ vào `GoiSoTraCuu`, câu cuối kiểm trên chính gói ấy. Mô
/// hình không gọi tool nào (`KhongTraCuu`) thì màn rơi về bậc 1 — đường sáu gói
/// dựng sẵn ở `_luongBac1` — im lặng.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/presentation/bloc/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/connection_monitor.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../ai_edge/data/bo_cong_cu.dart';
import '../../../ai_edge/data/cong_tac_ai.dart';
import '../../../ai_edge/data/mo_hinh_tai_ve.dart';
import '../../../ai_edge/data/nguon_goi_so.dart';
import '../../../ai_edge/data/datasources/slm_runtime.dart';
import '../../../ai_edge/data/vong_lap_cong_cu.dart';
import '../../../ai_edge/domain/bo_markdown.dart';
import '../../../ai_edge/domain/cau_chao.dart';
import '../../../ai_edge/domain/chu_de_chan.dart';
import '../../../ai_edge/domain/cong_cu.dart';
import '../../../ai_edge/domain/gac_cau.dart';
import '../../../ai_edge/domain/goi_so.dart';
import '../../../ai_edge/domain/goi_so_tra_cuu.dart';
import '../../../ai_edge/domain/kiem_cau_tra_loi.dart';
import '../../../ai_edge/domain/lenh_tao.dart';
import '../../../ai_edge/domain/slm_prompt.dart';
import '../../../ai_edge/domain/the_cua_cau.dart';
import '../../../premium/data/repositories/goi_repository.dart';
import '../../../premium/domain/cau_quyen.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/goi_cubit.dart';
import '../../data/cong_tac_online.dart';
import '../../data/models/luot_hoi_online.dart';
import '../../data/repositories/tro_ly_online_repository.dart';
import '../../data/doc_lenh_bang_ai.dart';
import '../../data/nguon_lenh_tao.dart';
import '../../domain/duong_hoi.dart';
import '../../domain/su_kien_online.dart';
import '../widgets/tro_ly_ai/dong_khoa.dart';
import '../widgets/tro_ly_ai/hang_chip.dart';
import '../widgets/tro_ly_ai/nhan_nguon.dart';
import '../widgets/tro_ly_ai/the_lenh_tao.dart';
import '../widgets/tro_ly_ai/to_thong_tin_online.dart';

/// Bốn câu mở sẵn (spec mục 4.6). Chúng là **câu hỏi thật**, gửi đi y như khi
/// người dùng tự gõ — không phải bốn nhánh mã riêng.
///
/// ⚠️ Mỗi chip hỏi đúng thứ **một gói số có** (phân tích · ngân sách · mục
/// tiêu · hoá đơn). Bộ cũ có *"Dự báo tiết kiệm"* và *"Gợi ý cắt giảm chi
/// phí"* — hai thứ không gói nào mang — và mô hình trả lời bằng cách lấy con
/// số gần nghĩa nhất rồi gắn nhãn của câu hỏi vào (mục 9.5
/// `AI_EDGE_FEATURE.md`). Chip là thứ người dùng bấm đầu tiên; nó không được
/// dẫn vào đúng lỗi mà bộ kiểm sinh ra để chặn.
const List<String> kChipGoiY = [
  'Chi tiêu tháng này',
  'Tình hình ngân sách',
  'Tiến độ mục tiêu',
  'Hoá đơn sắp tới',
];

const String kChuaCoMoHinh =
    'Chưa có mô hình trên máy. Mở Cài đặt AI để tải về (2,41 GB) rồi hỏi lại.';

const String kCongTacDangTat =
    'Công tắc "Dùng AI trên máy" đang tắt. Bật lại ở Cài đặt AI để hỏi.';

/// Vì sao ô nhập bị khoá — **hai lý do khác nhau, hai câu khác nhau**.
///
/// ⚠️ Gộp làm một là để một câu nói dối: người đã tải xong 2,41 GB rồi tự tắt
/// công tắc sẽ đọc *"chưa có mô hình trên máy"* và đi tải lại. Thấy được khi
/// nhìn màn thật trên máy ảo, `flutter test` thì mù vì nó chỉ dựng một nhánh.
String cauKhoaHoiDap({required bool coTep}) =>
    coTep ? kCongTacDangTat : kChuaCoMoHinh;

const String kGoiBasic =
    'Trợ lý AI là tính năng Premium. Nâng cấp để hỏi về số liệu của bạn.';

/// Ba lý do ô nhập bị khoá (spec Premium 2026-10-06 mục 8.1).
enum LyDoKhoaHoiDap { goiBasic, tamNgung, chuaCoMoHinh, congTacTat }

/// ⚠️ Basic xét TRƯỚC: không mời người không dùng được đi tải 2,41 GB. Hai lý
/// do còn lại giữ nguyên bài học ở [cauKhoaHoiDap] (hai câu khác nhau, không
/// gộp). Từ 2026-10-11 (trợ lý online §3.5): có đường online thì ô mở dù máy
/// chưa sẵn — mất mạng lúc hỏi mới nói [kKhongMangKhongMoHinh]. `null` = không khoá.
/// Tạm ngừng (B1) xét trước cả Basic.
LyDoKhoaHoiDap? lyDoKhoa({
  required bool laPremium,
  bool tamNgung = false,
  required bool coTep,
  required bool congTacBat,
  bool onlineBat = false,
}) {
  if (tamNgung) return LyDoKhoaHoiDap.tamNgung; // B1: admin tắt — mua không mở, không mời Nâng cấp
  if (!laPremium) return LyDoKhoaHoiDap.goiBasic;
  if (onlineBat) return null;
  if (!coTep) return LyDoKhoaHoiDap.chuaCoMoHinh;
  if (!congTacBat) return LyDoKhoaHoiDap.congTacTat;
  return null;
}

const String kKhongMangKhongMoHinh =
    'Đang không có mạng, và AI trên máy chưa sẵn (chưa tải / đang tắt). Nối mạng hoặc mở Cài đặt AI.';
const String kMayChuHongKhongMoHinh =
    'Máy chủ không phản hồi, và AI trên máy chưa sẵn (chưa tải / đang tắt). Thử lại sau hoặc mở Cài đặt AI.';

/// Máy chủ hỏng giữa chừng mà câu thuộc chủ đề AI trên máy từ chối (định nghĩa / tư vấn — Gemini trả lời
/// được): nói rõ lý do rơi, không để người dùng thấy câu từ chối trần (người dùng chốt 2026-10-17: lý do
/// rơi phải hiện cho người dùng, không chỉ trong log).
const String kMayChuHongTuChoi =
    'Máy chủ không phản hồi; AI trên máy chỉ nhận xét được trên số liệu của bạn trong app.';

const String kDangHoiOnline = 'Đang hỏi trợ lý online…';

String cauKhoa(LyDoKhoaHoiDap ly) => switch (ly) {
      LyDoKhoaHoiDap.goiBasic => kGoiBasic,
      LyDoKhoaHoiDap.tamNgung => cauMoDauQuyen(MaQuyen.aiAssistant, tamNgung: true),
      LyDoKhoaHoiDap.chuaCoMoHinh => kChuaCoMoHinh,
      LyDoKhoaHoiDap.congTacTat => kCongTacDangTat,
    };

/// ⚠️ Câu này là **nhánh lùi khi bộ kiểm số chặn**, và nó cố ý **không** nói
/// câu mô hình vừa viết. Hiện ra kèm lời cảnh báo thì người đọc vẫn nhớ con số
/// chứ không nhớ lời cảnh báo — cùng lý lẽ với việc `SlmDienGiai` rơi về mẫu
/// câu trong im lặng.
const String _kKhongChacChan =
    'Mình chưa chắc về con số cho câu này, nên không trả lời để khỏi nói sai.';

const String _kHong =
    'Mô hình trên máy không chạy được lúc này. Bạn thử lại sau nhé.';

/// Phiên đăng nhập **chưa sẵn sàng** — khác hẳn "mô hình hỏng".
///
/// ⚠️ Vì sao phải là câu riêng: `AuthBloc` chỉ vào `AuthSuccess` sau khi
/// `verifySession()` trả lời, mà lời gọi ấy là **mạng**. Mở app lúc không có
/// mạng thì nó phải đợi hết timeout (30 s) rồi mới giữ phiên cũ — và trong
/// suốt quãng ấy `currentAccountIdOrNull` trả `null`.
///
/// Dùng chung câu với `_kHong` là nói với người dùng rằng **mô hình** hỏng,
/// trong khi mô hình hoàn toàn bình thường và thứ duy nhất thiếu là mã tài
/// khoản. Đo thật 2026-09-22 (P3 Task 9): hỏi ngay sau khi mở app trong điều
/// kiện backend không tới được → câu "mô hình không chạy được"; chờ 45 giây
/// rồi hỏi lại **cùng câu hỏi ấy** → mô hình nạp trong 4.103 ms và trả lời
/// bình thường. Trớ trêu nhất là nó rơi đúng vào ca **mất mạng**, ca mà AI
/// trên máy sinh ra để phục vụ (mục 10.2 `docs/AI_EDGE_FEATURE.md`).
const String kChuaSanSangPhien =
    'Đang mở lại phiên đăng nhập trên máy. Bạn đợi vài giây rồi hỏi lại nhé.';

/// Câu của trợ lý sau khi người dùng bấm Huỷ lượt đọc lệnh tạo bằng AI (C3 §8) mà câu không theo mẫu của bộ luật.
const String kDaHuyLenh = 'Đã huỷ.';

/// Dòng chỉ báo từ lúc bấm Huỷ tới lúc engine thật sự dừng.
const String kDangHuyLenh = 'Đang huỷ…';

class _TinNhan {
  const _TinNhan.cuaToi(this.cau)
      : cuaToi = true,
        the = const [],
        lenh = null,
        nguon = null,
        ghiChu = null;
  const _TinNhan.cuaAi(this.cau, {this.the = const [], this.nguon, this.ghiChu})
      : cuaToi = false,
        lenh = null;

  /// C3 — thẻ lệnh tạo (không phải câu mô hình): tóm tắt + nút mở form điền sẵn.
  const _TinNhan.lenhTao(LenhTao this.lenh)
      : cuaToi = false,
        cau = '',
        the = const [],
        nguon = null,
        ghiChu = null;

  final LenhTao? lenh;

  /// Nguồn của câu AI (nhãn dưới bong bóng); `null` = câu cố định của hệ thống, không nhãn.
  final NguonTraLoi? nguon;
  final String? ghiChu;

  final bool cuaToi;
  final String cau;

  /// Thẻ số liệu đi **kèm** câu — điều kiện 12 của đặc tả gốc: không để người
  /// dùng chỉ thấy văn bản mà không thấy nguồn số.
  final List<String> the;
}

class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    this.coMoHinh,
    this.onHoi,
    this.onHoiBac1,
    this.onChao,
    this.traLoiMau,
    this.theSoLieuMau,
    this.doTrangThai,
    this.nguonLenhTao,
    this.docLenh,
    this.laPremium,
    this.onHoiOnline,
    this.coMang,
    this.congTacOnline,
  });

  /// Khe tiêm cho test: luồng sự kiện của nhánh online (spec trợ lý online 2026-10-11). `null` = đường thật qua
  /// `TroLyOnlineRepository` (DI); chưa đăng ký → online tắt.
  final Stream<SuKienOnline> Function(String cauHoi, List<TinLichSu> history)? onHoiOnline;

  /// Khe tiêm cho test: có mạng lúc gửi? `null` = `ConnectionMonitor.coMangNgay`.
  final Future<bool> Function()? coMang;

  /// Khe tiêm cho test: công tắc Trợ lý online. `null` = qua DI nếu đã đăng ký.
  final CongTacOnline? congTacOnline;

  /// `null` = hỏi thật (`MoHinhTaiVe` + `CongTacAi` qua DI). Khác `null` =
  /// **không chạm DI**, để widget test dựng được cả hai trạng thái.
  final bool? coMoHinh;

  /// Trợ lý AI là đặc quyền Premium (spec Premium 2026-10-06 mục 8.1). `null` =
  /// đọc `GoiCubit` qua `context`; **không có provider thì coi là Premium** —
  /// chỉ test cũ gặp ca ấy, app thật luôn có `GoiCubit` ở gốc cây.
  final bool? laPremium;

  /// Khe tiêm cho test: thay cả đường sinh câu — từ chặng 4b là **vòng lặp
  /// tool** — bằng một luồng sự kiện **đã gác** (`CauQua` / `BiChan`, cộng
  /// `DangTraCuu` / `KhongTraCuu` của bậc tool). `null` = đường thật. Gác theo
  /// câu và vòng lặp có test riêng (`gac_cau_test`, `vong_lap_cong_cu_test`); ở
  /// đây test chỉ canh màn phản ứng với sự kiện.
  final Stream<SuKienGac> Function(String cauHoi)? onHoi;

  /// Khe tiêm cho test: đường BẬC 1 (sáu gói dựng sẵn) mà màn rơi về khi vòng
  /// lặp tool phát [KhongTraCuu]. `null` = đường thật.
  final Stream<SuKienGac> Function(String cauHoi)? onHoiBac1;

  /// Khe tiêm cho test: đường CÂU CHÀO (`cau_chao.dart`) — luồng đã gác. `null` =
  /// đường thật (một lượt sinh không tool).
  final Stream<SuKienGac> Function(String cau)? onChao;

  /// Khe tiêm cho test: hội thoại dựng sẵn.
  final List<String>? traLoiMau;
  final List<String>? theSoLieuMau;

  /// Khe tiêm cho test: đọc `(có tệp, công tắc đang bật)`. `null` = hỏi DI.
  final Future<(bool, bool)> Function()? doTrangThai;

  /// Khe tiêm cho test: ví / danh mục chi cho lệnh tạo (C3). `null` = `napNguonLenhTao` qua DI.
  final Future<NguonLenhTao> Function()? nguonLenhTao;

  /// Khe tiêm cho test: phiên AI đọc lệnh tạo (C3 §8). `null` = `DocLenhBangAi` qua DI nếu đã đăng ký, không thì màn
  /// chỉ dùng bộ luật.
  final DocLenh? docLenh;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _oNhap = TextEditingController();
  final _cuon = ScrollController();
  final _tinNhan = <_TinNhan>[];

  /// Hai cờ chứ không một: xem [cauKhoaHoiDap].
  bool _coTep = false;
  bool _batCongTac = true;
  bool _dangHoi = false;

  /// Các câu đã qua kiểm của lượt trả lời **đang đến**, nối bằng khoảng
  /// trắng. `null` = chưa câu nào (đang hiện "Đang nghĩ…").
  String? _traLoiDangDen;

  /// Chữ dòng chỉ báo trong lúc tool chạy (`cauDangTraCuu`); `null` = "Đang nghĩ…".
  String? _dangTraCuu;

  /// Phiên AI lệnh tạo (C3 §8) đang chạy — dòng chỉ báo có thêm nút Huỷ. [_daHuyLenh]: người dùng vừa bấm nó.
  bool _dangDocLenh = false;
  bool _daHuyLenh = false;

  /// Đã bấm Huỷ, engine chưa dừng: dòng chỉ báo đổi thành [kDangHuyLenh] và nút Huỷ biến mất.
  bool _dangHuyLenh = false;

  /// Premium? Tiêm cho test, hoặc đọc `GoiCubit` (đã `watch` trong `build` để
  /// gói lên giữa phiên — socket `account.upgraded` — là ô mở ngay).
  bool get _laPremium {
    final t = widget.laPremium;
    if (t != null) return t;
    try {
      // `context.read` (provider) ném `ProviderNotFoundException`;
      // `BlocProvider.of` bọc nó thành `FlutterError` — không bắt được.
      return context.read<GoiCubit>().coQuyen(MaQuyen.aiAssistant);
    } on ProviderNotFoundException {
      return true;
    }
  }

  /// B1: `ai_assistant` TẠM NGỪNG (admin tắt ở cột của gói) — băng khoá không mời Nâng cấp. Tiêm `laPremium` (test) → không.
  bool get _tamNgungAi {
    if (widget.laPremium != null) return false;
    try {
      return context.read<GoiCubit>().trangThaiCua(MaQuyen.aiAssistant) == TrangThaiQuyen.tamNgung;
    } on ProviderNotFoundException {
      return false;
    }
  }

  // ── Trợ lý online (spec 2026-10-11) ──
  late final String _conversationId = const Uuid().v4();
  void Function(String lyDo)? _huyOnline;
  bool _daDungOnline = false;

  /// Công tắc online bật ∧ có đường online (khe tiêm hoặc DI). Đọc vô điều kiện ở `initState` / `_moCaiDatAi`.
  bool _onlineBat = false;

  /// Ghi chú gắn vào câu TRÊN MÁY kế tiếp khi vừa rơi từ online (`kGhiChuRoiVeMay`).
  String? _ghiChuRoi;

  CongTacOnline? get _congTacOnline =>
      widget.congTacOnline ?? (sl.isRegistered<CongTacOnline>() ? sl<CongTacOnline>() : null);
  Future<bool> _coMang() => (widget.coMang ?? _coMangThat)();
  Future<bool> _coMangThat() =>
      sl.isRegistered<ConnectionMonitor>() ? sl<ConnectionMonitor>().coMangNgay() : Future.value(false);
  bool _coDuongOnline() => widget.onHoiOnline != null || sl.isRegistered<TroLyOnlineRepository>();

  Future<void> _docOnlineBat() async {
    final bat = (await _congTacOnline?.docBat() ?? false) && _coDuongOnline();
    if (!mounted || bat == _onlineBat) return;
    setState(() => _onlineBat = bat);
  }

  LyDoKhoaHoiDap? get _lyDoKhoa => lyDoKhoa(
      laPremium: _laPremium, tamNgung: _tamNgungAi, coTep: _coTep, congTacBat: _batCongTac, onlineBat: _onlineBat);

  /// Chỉ Basic khoá CẢ ô (kể cả lệnh tạo C3 — người dùng chốt câu 3); hai lý do
  /// cũ vẫn để ô mở cho lệnh tạo (chốt 2026-09-30).
  bool get _khoaCaO => _lyDoKhoa == LyDoKhoaHoiDap.goiBasic || _lyDoKhoa == LyDoKhoaHoiDap.tamNgung;

  /// Ô nhập mở (chip, hint, băng khoá). Khi online bật, ô mở dù máy chưa có mô hình — xem [_maySan].
  bool get _coMoHinh => _lyDoKhoa == null;

  /// Mô hình trên máy thật sự sẵn: có tệp ∧ công tắc "Dùng AI trên máy" bật.
  bool get _maySan => _coTep && _batCongTac;

  @override
  void initState() {
    super.initState();
    _tinNhan.add(const _TinNhan.cuaAi(
      'Xin chào! Mình trả lời dựa trên số liệu trong app của bạn — chi tiêu, '
      'ngân sách, mục tiêu. Bạn muốn biết gì?',
    ));
    for (final c in widget.traLoiMau ?? const <String>[]) {
      _tinNhan.add(_TinNhan.cuaAi(c, the: widget.theSoLieuMau ?? const []));
    }

    if (widget.coMoHinh != null) {
      _coTep = widget.coMoHinh!;
    } else {
      _doMoHinh();
    }
    unawaited(_docOnlineBat());
  }

  Future<void> _doMoHinh() async {
    final (co, bat) = await (widget.doTrangThai ?? _doTuDi)();
    if (!mounted) return;
    setState(() {
      _coTep = co;
      _batCongTac = bat;
    });
  }

  /// Hai điều kiện, không một: tệp có trên máy **và** người dùng chưa tắt công
  /// tắc ở màn Cài đặt AI. Bỏ vế thứ hai thì công tắc ấy không gác gì — ở lối
  /// B, DI không gác hộ nữa (Task 7 Step 4).
  Future<(bool, bool)> _doTuDi() async {
    if (!sl.isRegistered<MoHinhTaiVe>() || !sl.isRegistered<CongTacAi>()) {
      return (false, true);
    }
    return (await sl<MoHinhTaiVe>().daCo(), await sl<CongTacAi>().doc());
  }

  /// ⚠️ Mở màn Cài đặt AI rồi **đọc lại** trạng thái khi quay về.
  ///
  /// `initState` chỉ chạy một lần; quay lại bằng `pop` thì nó **không** chạy
  /// lại, nên người dùng tắt công tắc ở màn kia xong quay về vẫn thấy chip
  /// xanh và ô nhập mở — bấm vào thì mới biết là không. Đo được trên máy ảo
  /// ngày 2026-09-22; `flutter test` mù với nó, cùng họ với **G48**.
  Future<void> _moCaiDatAi() async {
    await context.push('/ai-settings');
    if (!mounted) return;
    await _docOnlineBat();
    if (!mounted || widget.coMoHinh != null) return;
    await _doMoHinh();
  }

  @override
  void dispose() {
    _huyOnline?.call('rời màn');
    _oNhap.dispose();
    _cuon.dispose();
    super.dispose();
  }

  // ── Hỏi ─────────────────────────────────────────────────────────────────

  Future<void> _hoi(String cauHoi) async {
    final c = cauHoi.trim();
    // Ô nhập mở cả khi chưa có mô hình (C3, người dùng chốt 2026-09-30): lệnh tạo chỉ luật.
    // Basic thì khoá cả ô — kể cả lệnh tạo (spec Premium 8.1); hết hạn giữa phiên lộ ở đây, câu đang sinh không bị cắt.
    if (c.isEmpty || _dangHoi || _khoaCaO) return;

    setState(() {
      _tinNhan.add(_TinNhan.cuaToi(c));
      _dangHoi = true;
      _dangTraCuu = null;
    });
    _oNhap.clear();
    _ghiChuRoi = null; // ghi chú "rơi về máy" chỉ sống trong MỘT lượt hỏi
    _cuonXuong();

    // C3 §8 — cổng rộng TRƯỚC mọi thứ khác (chặn chủ đề, định tuyến, phiên sáu tool): có mô hình thì AI đọc và luật
    // kiểm từng ô; không thì bộ luật dự phòng. Kết quả là thẻ mở form điền sẵn — không lưu gì.
    if (coVeLenhTao(c, now: DateTime.now())) {
      _daHuyLenh = false;
      final lenh = await _docLenhTao(c);
      if (!mounted) return;
      if (lenh != null) {
        debugPrint('[SLM] lệnh tạo ${lenh.runtimeType} nguồn ${lenh.nguon.name} → form');
        _themCuaAi(_TinNhan.lenhTao(lenh));
        return;
      }
      if (_daHuyLenh) {
        // ⚠️ Lệch spec §8.4 có chủ ý: vừa bấm Huỷ một lượt chờ thì DỪNG, không đẩy sang lượt chờ của vòng hỏi đáp.
        _themCuaAi(const _TinNhan.cuaAi(kDaHuyLenh));
        return;
      }
      // Lọt cổng mà mô hình không gọi tool nào (hoặc hỏng) và câu không theo mẫu: không phải lệnh — đi tiếp như cũ.
    }

    // Cổng 3 (spec trợ lý online §3.1): công tắc bật ∧ có mạng lúc gửi ∧ không phải dữ liệu sống.
    final ct = _congTacOnline;
    var matMang = false;
    if (ct != null && _coDuongOnline()) {
      final congTacBat = await ct.docBat();
      if (!mounted) return;
      final coMang = congTacBat && await _coMang();
      matMang = congTacBat && !coMang;
      if (!mounted) return;
      if (nenHoiOnline(congTacBat: congTacBat, coMang: coMang, cauHoi: c)) {
        final diOnline = await _xinDongYOnline(ct);
        if (!mounted) return;
        if (diOnline) {
          final kq = await _hoiOnline(c);
          if (!mounted || kq is! RoiVeMay) return;
          debugPrint('[Online] rơi về máy: ${kq.lyDo}');
          _ghiChuRoi = kGhiChuRoiVeMay;
          // đi tiếp đường trên máy bên dưới với CÙNG câu
        }
      }
    }

    // Không phải lệnh mà máy chưa sẵn: câu cố định theo NGUYÊN NHÂN thật (vừa rơi từ online · dữ liệu sống · mất mạng ·
    // chủ đề máy từ chối · chưa tải / tắt mô hình) — băng nhắc tải vẫn ở đó. Dữ liệu sống đứng TRƯỚC mất mạng: nối mạng
    // cũng không trả lời được câu ấy.
    if (!_maySan) {
      final vuaRoi = _ghiChuRoi != null;
      _ghiChuRoi = null;
      final String cau;
      if (vuaRoi) {
        cau = kMayChuHongKhongMoHinh;
      } else if (chuDeBiChanOnline(c)) {
        cau = kCauTuChoi;
      } else if (matMang) {
        cau = kKhongMangKhongMoHinh;
      } else if (chuDeBiChan(c)) {
        cau = kCauTuChoi; // chủ đề bị từ chối bất kể mô hình — trung thực hơn mời tải mô hình
      } else {
        cau = cauKhoaHoiDap(coTep: _coTep);
      }
      _themCuaAi(_TinNhan.cuaAi(cau));
      return;
    }

    // ⚠️ Chặn TRƯỚC khi gọi mô hình: 2,3 giây cho một câu chắc chắn bị vứt đi
    // là lãng phí, và mô hình không nên thấy câu hỏi ấy.
    if (chuDeBiChan(c)) {
      final vuaRoi = _ghiChuRoi != null;
      _ghiChuRoi = null;
      _themCuaAi(_TinNhan.cuaAi(vuaRoi ? kMayChuHongTuChoi : kCauTuChoi));
      return;
    }

    try {
      // Câu chào (2026-10-09, người dùng chọn "mô hình đáp, không tra cứu"): đo
      // OnePlus, "xin chao ban" vào phiên sáu tool, mô hình gọi nhầm tool giao
      // dịch và đáp "Tôi đã tìm thấy các giao dịch…" sau 15 s. Nay Gemma đáp
      // trong một lượt sinh không tool, câu bị kiểm trên gói rỗng (mọi chữ số bị
      // chặn); không câu nào qua thì câu dự phòng.
      if (laCauChao(c)) {
        final luongChao =
            widget.onChao != null ? widget.onChao!(c) : _luongChao(c);
        await _nhanTungCau(kemDuPhongChao(luongChao), const <GoiSo>[]);
        return;
      }
      final (luong, goi) = widget.onHoi != null
          ? (widget.onHoi!(c), const <GoiSo>[])
          : await _luongThat(c) ?? (null, const <GoiSo>[]);
      // `null`: `_luongThat` đã tự trả một câu cố định (chưa có phiên, chưa
      // có mô hình) và xong lượt.
      if (luong == null) return;
      final canBac1 = await _nhanTungCau(luong, goi);
      if (!canBac1 || !mounted) return;

      // L1 (spec 4b mục 3.6): mô hình không gọi tool nào → câu ấy bị vứt, rơi
      // về bậc 1 hôm nay. Im lặng với người dùng (H3) — họ chỉ thấy chờ lâu hơn.
      final (l1, g1) = widget.onHoiBac1 != null
          ? (widget.onHoiBac1!(c), const <GoiSo>[])
          : await _luongBac1(c);
      await _nhanTungCau(l1, g1);
    } catch (e, st) {
      // ⚠️ PHẢI log. Người dùng chỉ thấy một câu chung chung ("Mô hình trên
      // máy không chạy được lúc này"), và nếu chỗ này im thì **không còn dấu
      // vết nào** để lần ra vì sao — nghiệm thu máy thật 2026-09-22 (P3 Task
      // 9) vấp đúng thế: câu ấy hiện lên sau khi cài đè APK, logcat sạch
      // trơn, và phải sửa mã rồi cài lại mới biết chuyện gì xảy ra.
      debugPrint('[SLM] hỏi đáp hỏng: $e\n$st');
      _themCuaAi(const _TinNhan.cuaAi(_kHong));
    }
  }

  /// Ví / danh mục cho lệnh tạo — nạp MỘT lần mỗi lần mở màn (không đọc lại mỗi câu). Chưa có phiên → rỗng.
  Future<NguonLenhTao>? _nguonLenh;
  Future<NguonLenhTao> _napNguonLenh() {
    final tiem = widget.nguonLenhTao;
    if (tiem != null) return _nguonLenh ??= tiem();
    final id = currentAccountIdOrNull(context);
    if (id == null || id <= 0) return Future.value((vi: const <MucChon>[], danhMucChi: const <MucChon>[]));
    return _nguonLenh ??= napNguonLenhTao(id);
  }

  /// `null` → không có đường mô hình cho lệnh tạo (test không tiêm, DI chưa đăng ký): chỉ luật.
  DocLenh? get _docLenh => widget.docLenh ?? (sl.isRegistered<DocLenhBangAi>() ? sl<DocLenhBangAi>() : null);

  /// AI đọc trước (máy có mô hình), luật kiểm từng ô (`lenhTaoTuAi`); không thì bộ luật §2–§3. `null` = không phải
  /// lệnh: câu tự nhiên mà mô hình không gọi tool, lượt hỏng / quá hạn, hoặc người dùng bấm Huỷ.
  Future<LenhTao?> _docLenhTao(String c) async {
    final nguon = await _napNguonLenh();
    final now = DateTime.now();
    final doc = _docLenh;
    if (_maySan && doc != null && mounted) {
      setState(() {
        _dangDocLenh = true;
        _dangTraCuu = kDangDocLenh;
      });
      final kq = await doc.doc(
        c,
        now: now,
        tenVi: [for (final v in nguon.vi) v.ten],
        tenDanhMuc: [for (final d in nguon.danhMucChi) d.ten],
      );
      if (!mounted) return null;
      setState(() {
        _dangDocLenh = false;
        _dangHuyLenh = false;
        _dangTraCuu = null;
      });
      if (kq != null) return lenhTaoTuAi(c, kq, now: now, vi: nguon.vi, danhMucChi: nguon.danhMucChi);
    }
    return lenhTaoTheoCauHoi(c, now: now, vi: nguon.vi, danhMucChi: nguon.danhMucChi);
  }

  /// ⚠️ Phản hồi NGAY: engine còn vài giây mới thôi giải mã (đo Realme 2026-10-01: ~5 s từ lúc bấm tới lúc lượt trả
  /// về), và suốt quãng ấy màn đứng nguyên thì người dùng không biết cú chạm có ăn không. Ô nhập vẫn khoá tới khi lượt
  /// thật sự dừng — mở sớm là mở phiên mới khi phiên cũ chưa đóng.
  void _huyDocLenh() {
    setState(() {
      _daHuyLenh = true;
      _dangHuyLenh = true;
      _dangTraCuu = kDangHuyLenh;
    });
    unawaited(_docLenh?.huy());
  }

  /// Tờ thông tin một lần (§3.5 b). `true` = đi online; `false` = câu này trên máy.
  Future<bool> _xinDongYOnline(CongTacOnline ct) async {
    if (await ct.daDocTo()) return true;
    if (!mounted) return false;
    final chon = await moToThongTinOnline(context);
    if (!mounted) return false;
    switch (chon) {
      case LuaChonToThongTin.daHieu:
        await ct.ghiDaDocTo();
        return true;
      case LuaChonToThongTin.chiTrenMay:
        await ct.ghiBat(false);
        await ct.ghiDaDocTo();
        if (mounted) setState(() => _onlineBat = false);
        return false;
      case null:
        return false; // chưa quyết (vuốt tắt): lần sau hỏi lại, không ghi gì
    }
  }

  /// Dừng lượt online: huỷ yêu cầu; datasource phát `LoiOnline(cancel)` và
  /// `quyetDinhSauOnline(daDung: true)` giữ phần đã hiện kèm ghi chú "đã dừng".
  void _dungOnline() {
    _daDungOnline = true;
    _huyOnline?.call('người dùng dừng');
    setState(() {});
  }

  bool get _hienNutDung => _huyOnline != null && !_daDungOnline;

  Widget _nutDung() => TextButton(
        key: const Key('dung-online'),
        onPressed: _dungOnline,
        child: const Text(
          'Dừng',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary),
        ),
      );

  /// Một lượt online: nối chunk vào `_traLoiDangDen`, kết bằng luật rơi §3.3. Không bao giờ ném — hỏng thì [RoiVeMay].
  Future<KetQuaOnline> _hoiOnline(String c) async {
    var daCoChu = false;
    final chu = StringBuffer();
    try {
      final history = xepHistory([
        // Bỏ câu vừa thêm (`_hoi` đã add `cuaToi`): history không gồm câu đang hỏi. Tin AI không nguồn là câu cố
        // định của hệ thống (từ chối, lời chào gieo sẵn…), không phải lời mô hình — không gửi lên server.
        for (final t in _tinNhan.take(_tinNhan.length - 1))
          (cuaToi: t.cuaToi, cau: t.cau, laThe: t.lenh != null || (!t.cuaToi && t.nguon == null)),
      ]);
      final luot = widget.onHoiOnline != null
          ? LuotHoiOnline(suKien: widget.onHoiOnline!(c, history), huy: (_) {})
          : sl<TroLyOnlineRepository>().hoi(cauHoi: c, conversationId: _conversationId, history: history);
      setState(() {
        _huyOnline = luot.huy;
        _daDungOnline = false;
        _dangTraCuu = kDangHoiOnline;
        _traLoiDangDen = null;
      });
      final luong = luot.suKien;
      SuKienOnline cuoi = const LoiOnline(http: null, lyDo: 'không sự kiện');
      var chot = false;
      await for (final sk in luong) {
        if (!mounted) return const HoanTat();
        if (chot) continue;
        if (_daDungOnline) continue; // khung tới sau Dừng không được nối vào bong bóng
        cuoi = sk;
        if (sk is! ChuOnline) {
          chot = true; // KHÔNG `break`: huỷ đăng ký giữa chừng treo trong test và thừa với datasource (đúng một sự kiện cuối)
          continue;
        }
        daCoChu = daCoChu || sk.text.isNotEmpty;
        chu.write(sk.text);
        setState(() => _traLoiDangDen = chu.toString());
        _cuonXuong();
      }
      debugPrint('[Online] kết thúc: ${cuoi.runtimeType}');
      final kq = quyetDinhSauOnline(daCoChu: daCoChu, cuoi: cuoi, daDung: _daDungOnline);
      // Gói hết hạn giữa phiên: server 403 → đọc lại gói để băng khoá cập nhật.
      if (cuoi case LoiOnline(http: 403)) {
        if (sl.isRegistered<GoiRepository>()) unawaited(sl<GoiRepository>().lamMoi());
      }
      _chotOnline(kq, chu.toString());
      return kq;
    } catch (e) {
      debugPrint('[Online] hỏng: ${e.runtimeType}');
      // Bảng §3.3: đã có chữ thì giữ phần đã hiện; chưa có thì rơi về máy.
      final KetQuaOnline kq = daCoChu ? const GiuPhanDaCo(kGhiChuGianDoan) : const RoiVeMay('exception');
      _chotOnline(kq, chu.toString());
      return kq;
    } finally {
      _huyOnline = null;
    }
  }

  /// Chốt bong bóng online theo [kq]: hoàn tất / giữ phần đã có (kèm ghi chú) thành tin nhắn; rơi về máy thì gỡ bong bóng
  /// đang hiện (kể cả câu thông báo ⚠️ của server) để câu đi tiếp trên máy.
  void _chotOnline(KetQuaOnline kq, String chu) {
    if (!mounted) return;
    switch (kq) {
      case HoanTat():
        _themCuaAi(_TinNhan.cuaAi(boDanhDauMarkdown(chu), nguon: NguonTraLoi.online));
      case GiuPhanDaCo(:final ghiChu):
        if (chu.isNotEmpty) {
          _themCuaAi(_TinNhan.cuaAi(boDanhDauMarkdown(chu), nguon: NguonTraLoi.online, ghiChu: ghiChu));
        } else {
          setState(() {
            _dangHoi = false;
            _traLoiDangDen = null;
            _dangTraCuu = null;
          });
        }
      case RoiVeMay():
        setState(() {
          _traLoiDangDen = null;
          _dangTraCuu = null;
        });
    }
  }

  void _themCuaAi(_TinNhan t) {
    if (!mounted) return;
    setState(() {
      _tinNhan.add(t);
      _traLoiDangDen = null;
      _dangTraCuu = null;
      _dangHoi = false;
    });
    _cuonXuong();
  }

  /// Luồng sự kiện đã gác của đường thật, kèm gói số để dựng thẻ. `null` khi
  /// lượt này kết thúc bằng một câu cố định (đã thêm vào hội thoại).
  Future<(Stream<SuKienGac>, List<GoiSo>)?> _luongThat(String cauHoi) async {
    final id = currentAccountIdOrNull(context);
    if (id == null || id <= 0) {
      debugPrint('[SLM] chưa hỏi được: AuthBloc chưa ở AuthSuccess (id=$id)');
      _themCuaAi(const _TinNhan.cuaAi(kChuaSanSangPhien));
      return null;
    }

    final moHinh = sl<MoHinhTaiVe>();
    if (!await moHinh.daCo()) {
      _themCuaAi(const _TinNhan.cuaAi(kChuaCoMoHinh));
      return null;
    }

    final runtime = sl<SlmRuntime>();
    if (!runtime.dangSan) await runtime.moHinhSan(await moHinh.duongTep());

    // Bậc tool (chặng 4b, hướng A): prompt không mang số; dữ liệu chỉ vào qua
    // tool và tích luỹ vào `goi` — chính đối tượng này về sau dựng thẻ số liệu,
    // nên nó phải là MỘT thể hiện xuyên suốt lượt hỏi.
    final goi = GoiSoTraCuu();
    return (
      hoiBangCongCu(
        cauHoi,
        runtime: runtime,
        boCongCu: sl<BoCongCu>(),
        goi: goi,
        idaccount: id,
        now: DateTime.now(),
      ),
      <GoiSo>[goi],
    );
  }

  /// Câu chào: một lượt sinh KHÔNG tool; `kiemCauChao` chặn mọi câu có chữ số,
  /// vì lời chào không được mang số liệu (`cau_chao.dart`).
  ///
  /// ⚠️ Phải NẠP mô hình như `_luongThat`: `sinhDan` ném *"Mô hình chưa nạp"* khi
  /// câu chào là câu đầu tiên của phiên (nghiệm thu OnePlus 2026-10-09 — đường bậc
  /// 1 cũng gọi thẳng `sinhDan` nhưng chỉ chạy SAU vòng lặp tool, khi mô hình đã
  /// nạp, nên chưa từng vấp).
  Stream<SuKienGac> _luongChao(String cau) async* {
    final runtime = sl<SlmRuntime>();
    if (!runtime.dangSan) {
      await runtime.moHinhSan(await sl<MoHinhTaiVe>().duongTep());
    }
    yield* gacTheoCau(
      runtime.sinhDan(promptTroChuyen(cau), tranToken: 120),
      kiem: kiemCauChao,
      huy: runtime.huy,
    );
  }

  /// BẬC 1 — đường hỏi đáp trước chặng 4b, nay là nhánh lùi L1: sáu gói dựng
  /// sẵn, một lượt sinh, gác theo câu trên chính sáu gói ấy.
  Future<(Stream<SuKienGac>, List<GoiSo>)> _luongBac1(String cauHoi) async {
    final id = currentAccountIdOrNull(context);
    if (id == null || id <= 0) {
      throw StateError('mất phiên giữa lượt hỏi (id=$id)');
    }
    final goi = await sl<NguonGoiSo>().tatCa(id);
    final runtime = sl<SlmRuntime>();
    // `kiemCauTraLoi` là định nghĩa duy nhất của "một câu được phép hiện":
    // số của nhiều gói (`kiemSoNhieuGoi`) + nhãn + giọng theo mức tổng hợp.
    return (
      gacTheoCau(
        runtime.sinhDan(promptHoiDap(cauHoi, goi), tranToken: 300),
        kiem: (cau) => kiemCauTraLoi(cau, goi),
        huy: runtime.huy,
      ),
      goi,
    );
  }

  /// Hiện từng câu qua kiểm ngay khi nó tới; hết luồng thì chốt thành một tin
  /// nhắn kèm thẻ. Câu bị chặn chỉ đi vào log. Trả `true` khi vòng lặp tool
  /// phát [KhongTraCuu] — người gọi rơi về bậc 1.
  Future<bool> _nhanTungCau(Stream<SuKienGac> luong, List<GoiSo> goi) async {
    final cauDaQua = <String>[];
    var canBac1 = false;
    await for (final sk in luong) {
      switch (sk) {
        case CauQua(:final cau):
          // Gỡ markdown ở lúc HIỆN — câu đã qua kiểm, số không đổi (bẫy 4.36).
          cauDaQua.add(boDanhDauMarkdown(cau));
          if (!mounted) return false;
          setState(() => _traLoiDangDen = cauDaQua.join(' '));
          _cuonXuong();
        case BiChan(:final cau):
          debugPrintCauHong(cau);
        case DangTraCuu(:final ten):
          if (!mounted) return false;
          setState(() => _dangTraCuu = ten == null ? null : cauDangTraCuu(ten));
        case KhongTraCuu():
          canBac1 = true;
      }
    }
    if (canBac1) return true;
    if (cauDaQua.isEmpty) {
      _themCuaAi(const _TinNhan.cuaAi(_kKhongChacChan));
      return false;
    }
    final vanBan = cauDaQua.join(' ');
    final ghiChu = _ghiChuRoi;
    _ghiChuRoi = null;
    _themCuaAi(_TinNhan.cuaAi(vanBan, the: _theChoCau(vanBan, goi), nguon: NguonTraLoi.trenMay, ghiChu: ghiChu));
    return false;
  }

  /// Thẻ số liệu = **những con số câu ấy thật sự nhắc tới**, lấy từ gói. Không
  /// phải mọi số của cả sáu gói: một câu hai dòng kèm hai mươi thẻ thì thẻ
  /// thôi là nguồn kiểm chứng, nó thành tiếng ồn. Phép khớp ở `theCuaCau` —
  /// ⚠️ **không** so chuỗi con (đã vấp thật, xem docstring ở đó).
  List<String> _theChoCau(String cau, List<GoiSo> goi) => theCuaCau(cau, goi);

  void _cuonXuong() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_cuon.hasClients) return;
      _cuon.animateTo(
        _cuon.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Dựng ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Nghe GoiCubit để gói đổi giữa phiên (lên Premium qua socket, hết hạn khi
    // app quay lại) là dựng lại ngay. Không provider (test cũ) thì bỏ qua.
    if (widget.laPremium == null) {
      try {
        context.watch<GoiCubit>();
      } on ProviderNotFoundException {
        // Không có GoiCubit trong cây — coi là Premium, xem [AiChatPage.laPremium].
      }
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _thanhTren(context),
      body: Column(
        children: [
          HangChip(
            nhan: kChipGoiY,
            bat: _coMoHinh && !_dangHoi,
            onChon: _hoi,
          ),
          Expanded(
            child: ListView.separated(
              controller: _cuon,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _tinNhan.length + (_dangHoi ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) {
                if (i >= _tinNhan.length) {
                  final dangDen = _traLoiDangDen;
                  return dangDen == null
                      ? _dangSoan()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _boCuaAi(_TinNhan.cuaAi(boDanhDauMarkdown(dangDen))),
                            if (_hienNutDung)
                              Align(
                                alignment: Alignment.centerRight,
                                child: _nutDung(),
                              ),
                          ],
                        );
                }
                final t = _tinNhan[i];
                if (t.lenh case final l?) return TheLenhTao(lenh: l);
                return t.cuaToi ? _boCuaToi(t) : _boCuaAi(t);
              },
            ),
          ),
          if (_lyDoKhoa case final ly?)
            DongKhoa(
              cau: cauKhoa(ly),
              goiBasic: ly == LyDoKhoaHoiDap.goiBasic,
              tamNgung: ly == LyDoKhoaHoiDap.tamNgung,
              onCaiDatAi: _moCaiDatAi,
            ),
          _thanhNhap(),
        ],
      ),
    );
  }

  PreferredSizeWidget _thanhTren(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surfaceContainerLow,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Quay lại',
        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () => context.pop(),
      ),
      centerTitle: true,
      title: const Text(
        'Trợ lý Tài chính AI',
        style: TextStyle(
          color: AppColors.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Cài đặt AI',
          icon: const Icon(Icons.settings, color: AppColors.onSurfaceVariant),
          // Lối vào DUY NHẤT của `/ai-settings` (Task 7). Route ấy nằm ngoài
          // shell nên phải `push` — `go` thì thanh tab biến mất.
          onPressed: _moCaiDatAi,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.outlineVariant, height: 1),
      ),
    );
  }

  Widget _boCuaAi(_TinNhan t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Text(
                  t.cau,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              if (t.nguon != null) NhanNguon(nguon: t.nguon!, ghiChu: t.ghiChu),
              if (t.the.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final s in t.the) _theSo(s)],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _theSo(String chu) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(
          chu,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );

  Widget _boCuaToi(_TinNhan t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              t.cau,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dangSoan() => Row(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Có nút Dừng: chữ chiếm hết phần trống (tight) để không bị Spacer chia đôi và xuống dòng ở 360 dp.
          Flexible(
            fit: _hienNutDung ? FlexFit.tight : FlexFit.loose,
            child: Text(
              _dangTraCuu ?? 'Đang nghĩ…',
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
          ),
          if (_hienNutDung) ...[_nutDung()],
          // Chỉ lượt đọc lệnh tạo (C3 §8) huỷ được: nó là lượt chờ THÊM trước vòng hỏi đáp, và có đường lùi là luật.
          if (_dangDocLenh && !_dangHuyLenh)
            TextButton(
              key: const Key('huy-doc-lenh'),
              onPressed: _huyDocLenh,
              child: const Text('Huỷ'),
            ),
        ],
      );
  Widget _thanhNhap() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _oNhap,
                // Basic khoá cả ô (kể cả lệnh tạo) — spec Premium 8.1.
                enabled: !_dangHoi && !_khoaCaO,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _hoi,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.onSurface),
                decoration: InputDecoration(
                  // Chưa có mô hình: ô vẫn gõ được lệnh tạo (C3) — gợi ý nói đúng thứ gõ được.
                  hintText: _khoaCaO
                      ? 'Tính năng Premium'
                      : _coMoHinh
                          ? 'Hỏi về số liệu của bạn…'
                          : 'VD: tạo hoá đơn Netflix 100k',
                  hintStyle: const TextStyle(color: AppColors.outline),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 8),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: !_dangHoi && !_khoaCaO
                    ? AppColors.primary
                    : AppColors.outline,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                tooltip: 'Gửi',
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed:
                    !_dangHoi && !_khoaCaO ? () => _hoi(_oNhap.text) : null,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tách ra một hàm để `debugPrint` không nằm giữa thân `_hoiThat` — và để chỗ
/// này có tên gọi khi đọc log.
void debugPrintCauHong(String cau) {
  // Câu mang số tiền / tên của người dùng — bản release không in (soát bảo mật 2026-10-24).
  debugPrint('[SLM] câu hỏi đáp không qua bộ kiểm số, không hiện${kDebugMode ? ': $cau' : ''}');
}
