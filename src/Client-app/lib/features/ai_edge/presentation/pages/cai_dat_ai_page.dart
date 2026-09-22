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

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/cong_tac_ai.dart';
import '../../data/mo_hinh_tai_ve.dart';
import '../../domain/hoi_dung_4g.dart';

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
    this.coWifi,
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

  /// Máy có đang ở Wi-Fi không. Tiêm để test dựng được cả hai nhánh mà không
  /// chạm nền tảng; đường chạy thật đọc `Connectivity()`.
  final Future<bool> Function()? coWifi;

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
      // ⚠️ Lượt tải có thể đã chạy từ LẦN MỞ APP TRƯỚC — stream chỉ phát những
      // gì xảy ra từ lúc nghe trở đi, nên không hỏi lại là màn hiện "Chưa tải"
      // cho một lượt đang chạy. Cùng họ G48.
      unawaited(_moHinh?.khoiPhuc() ?? Future<void>.value());
    }

    unawaited(_docCongTac());
  }

  Future<void> _doTrangThai() async {
    final co = await _moHinh?.daCo() ?? false;
    if (!mounted) return;
    // ⚠️ Chỉ đặt lại khi KHÔNG có lượt nào sống: lượt dò này là bất đồng bộ,
    // về muộn hơn một sự kiện của nguồn là thanh tiến độ biến mất giữa chừng.
    if (_tt == TrangThaiMoHinh.dangTai ||
        _tt == TrangThaiMoHinh.tamDung ||
        _tt == TrangThaiMoHinh.choMang) {
      return;
    }
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

  /// ⚠️ KHÔNG `setState` đặt `dangTai` như bản cũ — trạng thái đến từ stream
  /// của nguồn. Đặt tay ở đây là vẽ "đang tải" cho một lượt có thể chưa bắt
  /// đầu (người dùng bấm "Để sau", hoặc lượt đang chờ Wi-Fi).
  Future<void> _tai() async {
    final wifi = await (widget.coWifi?.call() ?? _doWifiThat());
    if (!mounted) return;

    var chiWifi = true;
    if (!wifi) {
      final dongY = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text(kCauHoi4G),
              content: const Text(kCauMoTa4G),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text(kCauTuChoi4G),
                ),
                TextButton(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: const Text(kCauDongY4G),
                ),
              ],
            ),
          ) ??
          false;
      if (!dongY) return;
      chiWifi = false;
    }

    await _moHinh?.tai(chiWifi: chiWifi);
  }

  Future<bool> _doWifiThat() async {
    try {
      final kq = await Connectivity().checkConnectivity();
      return kq.contains(ConnectivityResult.wifi);
    } catch (_) {
      // Không đọc được (nền tảng lạ) thì coi như có Wi-Fi: lượt tải vẫn bị
      // `requiresWiFi` gác ở tầng dưới, và màn sẽ nói "Đang chờ Wi-Fi".
      return true;
    }
  }

  // ⚠️ Ba handler dưới KHÔNG gọi `setState`: trạng thái đến từ stream của
  // nguồn. Bấm Tạm dừng trên THÔNG BÁO hệ thống cũng phải làm màn đổi theo,
  // nên nguồn là sự thật duy nhất — màn tự đặt là mở đường cho hai nơi nói
  // hai điều khác nhau.
  Future<void> _tamDung() async => _moHinh?.tamDung();

  Future<void> _tiepTuc() async => _moHinh?.tiepTuc();

  Future<void> _huy() async => _moHinh?.huy();

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
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Huỷ'),
              ),
              TextButton(
                onPressed: () => Navigator.of(c).pop(true),
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
      case TrangThaiMoHinh.tamDung:
        return _khoiTamDung();
      case TrangThaiMoHinh.choMang:
        return _khoiChoMang();
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
            const SizedBox(width: 8),
            TextButton(onPressed: _tamDung, child: const Text('Tạm dừng')),
            TextButton(onPressed: _huy, child: const Text('Huỷ')),
          ],
        ),
      ],
    );
  }

  Widget _khoiTamDung() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dongTieuDe(
            icon: Icons.pause_circle_outline,
            tieuDe: 'Đã tạm dừng · ${(_phanTram * 100).round()}%',
            phu: 'Phần đã tải được giữ lại, bấm Tiếp tục để tải nốt.',
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _phanTram.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _tiepTuc,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Tiếp tục'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: _huy, child: const Text('Huỷ')),
            ],
          ),
        ],
      );

  /// `requiresWiFi` làm lượt đứng im VÔ THỜI HẠN mà gói không báo lỗi nào —
  /// gộp vào "đang tải" là một thanh 0 % đứng yên mãi mãi.
  Widget _khoiChoMang() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dongTieuDe(
            icon: Icons.wifi_off_outlined,
            tieuDe: 'Đang chờ Wi-Fi',
            phu: 'Lượt tải sẽ tự tiếp tục khi máy vào Wi-Fi. '
                'Phần đã tải được giữ lại.',
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: _huy, child: const Text('Huỷ tải')),
        ],
      );

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
            // Tệp dở ĐƯỢC GIỮ (resume, 2026-09-22): Thử lại là tiếp tục từ
            // chỗ đứt, không tải lại từ đầu — nói ra để người dùng không
            // tưởng mình mất nửa gói dữ liệu.
            phu: '${_loi ?? 'Kết nối đứt giữa chừng.'} '
                'Phần đã tải được giữ lại.',
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _tiepTuc,
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

  /// ⚠️ Chip này phải theo **công tắc**, không chỉ theo việc tệp có trên máy.
  /// Để nguyên chữ "Hoạt động" khi công tắc đã tắt là đặt một lời khẳng định
  /// xanh lá ngay trên chính cái công tắc đang nói ngược lại — và người dùng
  /// tin cái chip. Thấy được khi nhìn màn thật trên máy ảo 2026-09-22.
  Widget _chipHoatDong() {
    final mau = _bat ? AppColors.income : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: mau, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _bat ? 'Hoạt động' : 'Đang tắt',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: mau,
            ),
          ),
        ],
      ),
    );
  }

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
