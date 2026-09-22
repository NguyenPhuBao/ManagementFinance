// lib/features/ai_edge/presentation/pages/cai_dat_ai_page.dart
/// Màn **Cài đặt AI** — tải / xoá mô hình trên máy và công tắc dùng nó.
///
/// Dựng theo màn Stitch `1da347e753964e15a91b10c473975923` *"Cài đặt AI -
/// FlowMoney"* (người dùng nghiệm thu 2026-09-22). ⚠️ Màn Stitch vẽ **ba
/// trạng thái xếp dọc** kèm nhãn *"Trạng thái 1/2/3"* — đó là bản **so sánh
/// khi thiết kế**, không phải bố cục thật; bản này dựng **một** trạng thái tại
/// một thời điểm.
///
/// Lối vào: màn Trợ lý AI (Task 8). **Không** có mục drawer — drawer đã bảy
/// mục và đây là cài đặt của một tính năng, không phải một tính năng.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/cong_tac_ai.dart';
import '../../data/mo_hinh_tai_ve.dart';

/// Dung lượng theo GiB, dấu **phẩy** thập phân.
///
/// ⚠️ Cố ý **không** đi qua `CurrencyFormatter`: đó là bộ định dạng *tiền* (nó
/// gắn `đ`), và dự án có test quét cấm mọi tệp khác dựng bộ định dạng số của
/// `intl` — nên phép đổi dấu ở đây làm bằng tay.
///
/// ⚠️ Và đừng viết tên lớp bị cấm ấy ra đây: phép quét đọc **cả dòng chú
/// thích**, nên chỉ nhắc tên nó là tệp này thành vi phạm (đã vấp thật
/// 2026-09-22; cùng bẫy với `lien_ket_ngan_hang_da_bo_test`).
String dungLuongGb(num byte) {
  final gb = byte / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(2).replaceAll('.', ',')} GB';
}

class CaiDatAiPage extends StatefulWidget {
  const CaiDatAiPage({
    super.key,
    this.daCoMoHinh,
    this.moHinh,
    this.congTac,
  });

  /// Ép sẵn trạng thái *đã có mô hình hay chưa*.
  ///
  /// `null` = hỏi [MoHinhTaiVe] thật (đường chạy thật). Khác `null` = **không
  /// chạm DI một lần nào**, để widget test dựng được cả hai trạng thái mà
  /// không phải dựng cả `injection_container`.
  final bool? daCoMoHinh;

  /// Tiêm cho test. `null` **và** [daCoMoHinh] `null` thì lấy từ `sl`.
  final MoHinhTaiVe? moHinh;

  final CongTacAi? congTac;

  @override
  State<CaiDatAiPage> createState() => _CaiDatAiPageState();
}

class _CaiDatAiPageState extends State<CaiDatAiPage> {
  late final CongTacAi _congTac;
  MoHinhTaiVe? _moHinh;
  StreamSubscription<TienDoTai>? _theoDoi;

  TrangThaiMoHinh _tt = TrangThaiMoHinh.chuaTai;
  double _phanTram = 0;
  String? _loi;
  bool _bat = true;

  @override
  void initState() {
    super.initState();
    _congTac = widget.congTac ?? const CongTacAi();

    if (widget.daCoMoHinh != null) {
      // Trạng thái ép sẵn: không hỏi DI, không nghe stream nào.
      _tt = widget.daCoMoHinh!
          ? TrangThaiMoHinh.daTai
          : TrangThaiMoHinh.chuaTai;
    } else {
      _moHinh = widget.moHinh ??
          (sl.isRegistered<MoHinhTaiVe>() ? sl<MoHinhTaiVe>() : null);
      _theoDoi = _moHinh?.tienDo.listen((t) {
        if (!mounted) return;
        setState(() {
          _tt = t.trangThai;
          _phanTram = t.phanTram;
          _loi = t.loi;
        });
      });
      unawaited(_doTrangThai());
    }

    unawaited(_docCongTac());
  }

  Future<void> _doTrangThai() async {
    final co = await _moHinh?.daCo() ?? false;
    if (!mounted) return;
    // ⚠️ Chỉ đặt lại khi đang KHÔNG tải: lượt dò này là bất đồng bộ, về muộn
    // hơn một sự kiện `dangTai` là thanh tiến độ biến mất giữa chừng.
    if (_tt == TrangThaiMoHinh.dangTai) return;
    setState(() {
      _tt = co ? TrangThaiMoHinh.daTai : TrangThaiMoHinh.chuaTai;
    });
  }

  Future<void> _docCongTac() async {
    final b = await _congTac.doc();
    if (!mounted) return;
    setState(() => _bat = b);
  }

  Future<void> _doiCongTac(bool v) async {
    setState(() => _bat = v);
    await _congTac.ghi(v);
  }

  Future<void> _tai() async {
    setState(() {
      _tt = TrangThaiMoHinh.dangTai;
      _phanTram = 0;
      _loi = null;
    });
    try {
      await _moHinh?.tai();
    } catch (_) {
      // `MoHinhTaiVe` đã phát trạng thái `loi` qua stream và đã xoá tệp dở —
      // bắt ở đây chỉ để lời gọi không ném ra khỏi handler của nút.
    }
  }

  Future<void> _xoa() async {
    final chac = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Xoá mô hình?'),
            content: Text(
              'Giải phóng ${dungLuongGb(kCoTepByte)}. App quay về dùng câu '
              'mẫu có sẵn; muốn dùng lại AI thì phải tải lại từ đầu.',
            ),
            actions: [
              TextButton(
                onPressed: () => c.pop(false),
                child: const Text('Huỷ'),
              ),
              TextButton(
                onPressed: () => c.pop(true),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.error),
                child: const Text('Xoá'),
              ),
            ],
          ),
        ) ??
        false;
    if (!chac) return;
    await _moHinh?.xoa();
    if (!mounted) return;
    setState(() => _tt = TrangThaiMoHinh.chuaTai);
  }

  @override
  void dispose() {
    _theoDoi?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daTai = _tt == TrangThaiMoHinh.daTai;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Cài đặt AI',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _nhanMuc('MÔ HÌNH TRÊN MÁY'),
            const SizedBox(height: 10),
            _the(child: _khoiTrangThai()),
            if (!daTai) ...[
              const SizedBox(height: 10),
              _dongWifi(),
            ],
            const SizedBox(height: 22),
            _nhanMuc('TUỲ CHỌN'),
            const SizedBox(height: 10),
            _theCongTac(),
            const SizedBox(height: 16),
            _khoiRiengTu(),
          ],
        ),
      ),
    );
  }

  // ── Mảnh dựng ───────────────────────────────────────────────────────────

  Widget _nhanMuc(String chu) => Text(
        chu,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      );

  Widget _the({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: child,
      );

  Widget _khoiTrangThai() {
    switch (_tt) {
      case TrangThaiMoHinh.dangTai:
        return _khoiDangTai();
      case TrangThaiMoHinh.daTai:
        return _khoiDaTai();
      case TrangThaiMoHinh.loi:
        return _khoiLoi();
      case TrangThaiMoHinh.chuaTai:
        return _khoiChuaTai();
    }
  }

  Widget _khoiChuaTai() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dongTieuDe(
            icon: Icons.cloud_download_outlined,
            tieuDe: 'Chưa tải mô hình',
            phu: 'Gemma 4 E2B · ${dungLuongGb(kCoTepByte)}',
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _tai,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Tải mô hình'),
          ),
        ],
      );

  Widget _khoiDangTai() {
    final xong = kCoTepByte * _phanTram;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dongTieuDe(
          icon: Icons.sync,
          tieuDe: 'Đang tải… ${(_phanTram * 100).round()}%',
          phu: '${dungLuongGb(xong)} / ${dungLuongGb(kCoTepByte)}',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  // Luôn có giá trị, không bao giờ để `null`: thanh vô định
                  // quay mãi làm `pumpAndSettle` của widget test treo.
                  value: _phanTram.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => _moHinh?.huy(),
              child: const Text('Huỷ'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _khoiDaTai() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  size: 20, color: AppColors.income),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Đã tải · ${dungLuongGb(kCoTepByte)}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              _chipHoatDong(),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _xoa,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Xoá mô hình'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.5)),
            ),
          ),
        ],
      );

  Widget _khoiLoi() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dongTieuDe(
            icon: Icons.error_outline,
            mauIcon: AppColors.error,
            tieuDe: 'Tải không xong',
            // Tệp dở đã bị `MoHinhTaiVe` xoá, nên lần sau là tải lại từ đầu —
            // nói ra để người dùng không tưởng mình mất nửa gói dữ liệu.
            phu: _loi ?? 'Kết nối đứt giữa chừng. Tải lại từ đầu.',
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _tai,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Thử lại'),
          ),
        ],
      );

  Widget _dongTieuDe({
    required IconData icon,
    required String tieuDe,
    required String phu,
    Color mauIcon = AppColors.textSecondary,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: mauIcon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieuDe,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  phu,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _chipHoatDong() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.income.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: AppColors.income, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text(
              'Hoạt động',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.income,
              ),
            ),
          ],
        ),
      );

  Widget _dongWifi() => Row(
        children: [
          const Icon(Icons.wifi, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cần Wi-Fi — tệp ${dungLuongGb(kCoTepByte)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      );

  Widget _theCongTac() => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _doiCongTac(!_bat),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dùng AI trên máy',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tắt thì app dùng câu mẫu có sẵn',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(value: _bat, onChanged: _doiCongTac),
              ],
            ),
          ),
        ),
      );

  Widget _khoiRiengTu() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline,
                size: 18, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mô hình chạy hoàn toàn trên máy bạn. Không có số liệu nào '
                'rời khỏi thiết bị.',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}
