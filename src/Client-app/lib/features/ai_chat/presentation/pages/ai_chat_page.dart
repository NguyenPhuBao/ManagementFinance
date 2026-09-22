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
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../ai_edge/data/cong_tac_ai.dart';
import '../../../ai_edge/data/mo_hinh_tai_ve.dart';
import '../../../ai_edge/data/nguon_goi_so.dart';
import '../../../ai_edge/data/slm_runtime.dart';
import '../../../ai_edge/domain/chu_de_chan.dart';
import '../../../ai_edge/domain/goi_so.dart';
import '../../../ai_edge/domain/kiem_so.dart';
import '../../../ai_edge/domain/slm_prompt.dart';

/// Bốn câu mở sẵn (spec mục 4.6). Chúng là **câu hỏi thật**, gửi đi y như khi
/// người dùng tự gõ — không phải bốn nhánh mã riêng.
const List<String> kChipGoiY = [
  'Phân tích chi tiêu tháng này',
  'Dự báo tiết kiệm',
  'Gợi ý cắt giảm chi phí',
  'Tình hình ngân sách',
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

/// ⚠️ Câu này là **nhánh lùi khi bộ kiểm số chặn**, và nó cố ý **không** nói
/// câu mô hình vừa viết. Hiện ra kèm lời cảnh báo thì người đọc vẫn nhớ con số
/// chứ không nhớ lời cảnh báo — cùng lý lẽ với việc `SlmDienGiai` rơi về mẫu
/// câu trong im lặng.
const String _kKhongChacChan =
    'Mình chưa chắc về con số cho câu này, nên không trả lời để khỏi nói sai.';

const String _kHong =
    'Mô hình trên máy không chạy được lúc này. Bạn thử lại sau nhé.';

class _TinNhan {
  const _TinNhan.cuaToi(this.cau)
      : cuaToi = true,
        the = const [];
  const _TinNhan.cuaAi(this.cau, {this.the = const []}) : cuaToi = false;

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
    this.traLoiMau,
    this.theSoLieuMau,
    this.doTrangThai,
  });

  /// `null` = hỏi thật (`MoHinhTaiVe` + `CongTacAi` qua DI). Khác `null` =
  /// **không chạm DI**, để widget test dựng được cả hai trạng thái.
  final bool? coMoHinh;

  /// Khe tiêm cho test: thay cả đường sinh câu. `null` = đường thật.
  final Future<String> Function(String cauHoi)? onHoi;

  /// Khe tiêm cho test: hội thoại dựng sẵn.
  final List<String>? traLoiMau;
  final List<String>? theSoLieuMau;

  /// Khe tiêm cho test: đọc `(có tệp, công tắc đang bật)`. `null` = hỏi DI.
  final Future<(bool, bool)> Function()? doTrangThai;

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

  bool get _coMoHinh => _coTep && _batCongTac;

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
    if (!mounted || widget.coMoHinh != null) return;
    await _doMoHinh();
  }

  @override
  void dispose() {
    _oNhap.dispose();
    _cuon.dispose();
    super.dispose();
  }

  // ── Hỏi ─────────────────────────────────────────────────────────────────

  Future<void> _hoi(String cauHoi) async {
    final c = cauHoi.trim();
    if (c.isEmpty || !_coMoHinh || _dangHoi) return;

    setState(() {
      _tinNhan.add(_TinNhan.cuaToi(c));
      _dangHoi = true;
    });
    _oNhap.clear();
    _cuonXuong();

    // ⚠️ Chặn TRƯỚC khi gọi mô hình: 2,3 giây cho một câu chắc chắn bị vứt đi
    // là lãng phí, và mô hình không nên thấy câu hỏi ấy.
    if (chuDeBiChan(c)) {
      _themCuaAi(const _TinNhan.cuaAi(kCauTuChoi));
      return;
    }

    try {
      final kq = widget.onHoi != null
          ? _TinNhan.cuaAi(await widget.onHoi!(c))
          : await _hoiThat(c);
      _themCuaAi(kq);
    } catch (e) {
      _themCuaAi(const _TinNhan.cuaAi(_kHong));
    }
  }

  void _themCuaAi(_TinNhan t) {
    if (!mounted) return;
    setState(() {
      _tinNhan.add(t);
      _dangHoi = false;
    });
    _cuonXuong();
  }

  Future<_TinNhan> _hoiThat(String cauHoi) async {
    final id = currentAccountIdOrNull(context);
    if (id == null || id <= 0) return const _TinNhan.cuaAi(_kHong);

    final moHinh = sl<MoHinhTaiVe>();
    if (!await moHinh.daCo()) return const _TinNhan.cuaAi(kChuaCoMoHinh);

    final goi = await sl<NguonGoiSo>().tatCa(id);
    final runtime = sl<SlmRuntime>();
    if (!runtime.dangSan) await runtime.moHinhSan(await moHinh.duongTep());

    final cau = await runtime.sinh(promptHoiDap(cauHoi, goi), tranToken: 300);

    // ⚠️ `kiemSoNhieuGoi`, không phải `goi.any(kiemSo)`: câu trả lời ở đây
    // được phép rút số từ nhiều màn cùng lúc.
    if (!kiemSoNhieuGoi(cau, goi)) {
      debugPrintCauHong(cau);
      return const _TinNhan.cuaAi(_kKhongChacChan);
    }
    return _TinNhan.cuaAi(cau, the: _theChoCau(cau, goi));
  }

  /// Thẻ số liệu = **những con số câu ấy thật sự nhắc tới**, lấy từ gói. Không
  /// phải mọi số của cả bốn gói: một câu hai dòng kèm hai mươi thẻ thì thẻ
  /// thôi là nguồn kiểm chứng, nó thành tiếng ồn.
  List<String> _theChoCau(String cau, List<GoiSo> goi) => [
        for (final g in goi)
          for (final s in g.soLieu)
            if (cau.contains(s.chuoi)) '${s.nhan} ${s.chuoi}',
      ];

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _thanhTren(context),
      body: Column(
        children: [
          _hangChip(),
          Expanded(
            child: ListView.separated(
              controller: _cuon,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _tinNhan.length + (_dangHoi ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) {
                if (i >= _tinNhan.length) return _dangSoan();
                final t = _tinNhan[i];
                return t.cuaToi ? _boCuaToi(t) : _boCuaAi(t);
              },
            ),
          ),
          if (!_coMoHinh) _dongChuaCoMoHinh(),
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

  Widget _hangChip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.background.withValues(alpha: 0.95),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final c in kChipGoiY) ...[
              _chip(c),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String nhan) {
    final bat = _coMoHinh && !_dangHoi;
    return Material(
      color: bat
          ? AppColors.secondaryContainer
          : AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        // ⚠️ `null` khi chưa có mô hình: ô nhập đã khoá mà chip vẫn hỏi được
        // thì có một đường vòng quanh chính cái khoá ấy.
        onTap: bat ? () => _hoi(nhan) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Text(
            nhan,
            style: TextStyle(
              color: bat
                  ? AppColors.onSurfaceVariant
                  : AppColors.outline,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
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

  Widget _dangSoan() => const Row(
        children: [
          SizedBox(
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
          SizedBox(width: 12),
          Text(
            'Đang nghĩ…',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
        ],
      );

  Widget _dongChuaCoMoHinh() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cauKhoaHoiDap(coTep: _coTep),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: _moCaiDatAi,
              child: const Text('Cài đặt AI'),
            ),
          ],
        ),
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
                enabled: _coMoHinh && !_dangHoi,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: _hoi,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: _coMoHinh
                      ? 'Hỏi về số liệu của bạn…'
                      : (_coTep ? 'AI trên máy đang tắt' : 'Cần tải mô hình trước'),
                  hintStyle: const TextStyle(color: AppColors.outline),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 8),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _coMoHinh && !_dangHoi
                    ? AppColors.primary
                    : AppColors.outline,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                tooltip: 'Gửi',
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _coMoHinh && !_dangHoi
                    ? () => _hoi(_oNhap.text)
                    : null,
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
  debugPrint('[SLM] câu hỏi đáp không qua bộ kiểm số, không hiện: $cau');
}
