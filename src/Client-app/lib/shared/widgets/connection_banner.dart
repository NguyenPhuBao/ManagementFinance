import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/connection_monitor.dart';
import '../../core/sync/sync_models.dart';
import '../theme/app_colors.dart';

/// Dải mỏng trượt xuống từ mép trên, báo tình trạng kết nối và đồng bộ.
///
/// Bọc quanh nội dung màn hình chứ không thay thế nó — đặt ở `MaterialApp.builder`
/// nên phủ mọi trang mà không trang nào phải biết đến nó.
///
/// ## Vì sao ba loại dải hành xử khác nhau
///
/// **Mất kết nối** mô tả một **trạng thái đang kéo dài**, nên dải ở lại cho tới
/// khi có mạng. Ẩn nó đi trong khi mạng vẫn mất là nói dối. Câu trấn an đi kèm
/// ("thay đổi vẫn được lưu trên máy") quan trọng ngang thông tin chính: thiếu
/// nó, người dùng ngừng nhập liệu vì sợ mất — đúng nỗi sợ mà kiến trúc
/// offline-first sinh ra để xoá bỏ.
///
/// **Đã kết nối lại** và **đã đồng bộ N thay đổi** mô tả một **sự kiện vừa xảy
/// ra**, nên chúng tự ẩn. Để mãi thì chúng chiếm chỗ mà không còn nói gì.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({
    super.key,
    required this.child,
    required this.connectionEvents,
    required this.pushResults,
    this.tuAnSau = const Duration(seconds: 4),
  });

  final Widget child;
  final Stream<ConnectionEvent> connectionEvents;
  final Stream<SyncResult> pushResults;

  /// Bao lâu thì dải "sự kiện" tự biến mất. Dải mất kết nối không dùng giá trị
  /// này — nó ở lại tới khi có mạng.
  final Duration tuAnSau;

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  StreamSubscription<ConnectionEvent>? _subKetNoi;
  StreamSubscription<SyncResult>? _subDay;
  Timer? _dongHoAn;

  _NoiDungDai? _dai;

  @override
  void initState() {
    super.initState();
    _subKetNoi = widget.connectionEvents.listen(_khiDoiKetNoi);
    _subDay = widget.pushResults.listen(_khiDayXong);
  }

  @override
  void dispose() {
    _subKetNoi?.cancel();
    _subDay?.cancel();
    _dongHoAn?.cancel();
    super.dispose();
  }

  void _khiDoiKetNoi(ConnectionEvent e) {
    switch (e) {
      case ConnectionEvent.mat:
        _hien(
          const _NoiDungDai(
            chu: 'Không có kết nối — thay đổi vẫn được lưu trên máy',
            mau: AppColors.expense,
            icon: Icons.cloud_off_outlined,
          ),
          tuAn: false,
        );
      case ConnectionEvent.khoiPhuc:
        // KHÔNG ghi đè dải kết quả đồng bộ đang hiện.
        //
        // Đo trên máy thật: SyncEngine phản ứng ngay khi mạng về và đẩy xong
        // sau ~0,4 giây, còn bộ theo dõi kết nối phải chờ hết ngưỡng ổn định
        // (3 giây) mới dám báo. Nên dải "Đã đồng bộ N thay đổi" ra trước và sẽ
        // bị "Đã kết nối lại" nuốt mất — mà đó lại là dải trả lời đúng câu
        // người dùng lo: dữ liệu ghi lúc mất mạng đã an toàn chưa.
        if (_dai?.laKetQuaDongBo ?? false) return;
        _hien(
          const _NoiDungDai(
            chu: 'Đã kết nối lại',
            mau: AppColors.income,
            icon: Icons.cloud_done_outlined,
          ),
          tuAn: true,
        );
    }
  }

  void _khiDayXong(SyncResult r) {
    // "Đã đồng bộ 0 thay đổi" là câu vô nghĩa. SyncEngine đã không phát trong
    // trường hợp này, nhưng dải tự chống thêm một lớp.
    if (r.succeeded == 0 && r.failed == 0) return;

    if (r.failed > 0) {
      _hien(
        _NoiDungDai(
          chu: 'Còn ${r.failed} thay đổi chưa lên được máy chủ',
          mau: AppColors.expense,
          icon: Icons.sync_problem_outlined,
          laKetQuaDongBo: true,
        ),
        tuAn: true,
      );
      return;
    }

    _hien(
      _NoiDungDai(
        chu: 'Đã đồng bộ ${r.succeeded} thay đổi',
        mau: AppColors.income,
        icon: Icons.cloud_done_outlined,
        laKetQuaDongBo: true,
      ),
      tuAn: true,
    );
  }

  void _hien(_NoiDungDai noiDung, {required bool tuAn}) {
    if (!mounted) return;
    _dongHoAn?.cancel();
    setState(() => _dai = noiDung);

    if (!tuAn) return;
    _dongHoAn = Timer(widget.tuAnSau, () {
      if (!mounted) return;
      setState(() => _dai = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dai = _dai;

    // `Column` chứ không `Stack`: dải nổi đè lên nội dung sẽ che mất thanh tiêu
    // đề và nút chuông của trang bên dưới — quan sát được trên máy thật. Đẩy
    // nội dung xuống thì không che gì cả, đổi lại là một cú dịch nhẹ khi dải
    // xuất hiện, và cú dịch ấy chính là tín hiệu cho người dùng biết có thứ mới.
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          if (dai != null)
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: dai.mau,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(dai.icon, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    // `Expanded` + `ellipsis`: câu mất kết nối dài, và màn hẹp
                    // thì nó phải co chứ không được tràn.
                    Expanded(
                      child: Text(
                        dai.chu,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _NoiDungDai {
  const _NoiDungDai({
    required this.chu,
    required this.mau,
    required this.icon,
    this.laKetQuaDongBo = false,
  });

  final String chu;
  final Color mau;
  final IconData icon;

  /// Dải này nói về kết quả đồng bộ (giàu thông tin nhất) hay chỉ về trạng thái
  /// kết nối. Dùng để xếp thứ tự ưu tiên — xem `_khiDoiKetNoi`.
  final bool laKetQuaDongBo;
}
