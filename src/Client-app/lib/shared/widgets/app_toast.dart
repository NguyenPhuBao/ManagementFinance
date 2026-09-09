import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/connection_monitor.dart';
import '../../core/sync/sync_models.dart';
import '../theme/app_colors.dart';

/// Toast nổi ở đáy màn hình, báo tình trạng kết nối và đồng bộ.
///
/// Bọc quanh nội dung màn hình chứ không thay thế nó — đặt ở `MaterialApp.builder`
/// nên phủ mọi trang mà không trang nào phải biết đến nó.
///
/// ## Vì sao nổi ở ĐÁY chứ không phải dải kín ngang ở đỉnh
///
/// Bản đầu là một thanh đặc màu kín chiều ngang nằm trong `Column`, tức nó đẩy
/// cả trang xuống mỗi lần xuất hiện. `Column` từng là lựa chọn có chủ ý: bản
/// trước nữa cho dải **nổi ở đỉnh** và trên máy thật nó che mất thanh tiêu đề
/// cùng nút chuông.
///
/// Lý lẽ ấy vẫn đúng — nhưng chỉ đúng với dải nổi ở đỉnh. Đặt ở đáy thì không
/// có gì quan trọng nằm dưới để mà che, nên nổi đè là an toàn, và đổi lại là
/// trang không còn bị giật một cú mỗi lần có thông báo.
///
/// Hình dáng viên thuốc lấy từ màn Stitch *"Thông báo nổi (toast) - FlowMoney"*
/// theo design system **Kinetic Finance**.
///
/// ## Mọi toast đều tự ẩn sau vài giây
///
/// Kể cả toast mất kết nối. Bản đầu giữ nó cho tới khi có mạng, với lập luận
/// "trạng thái kéo dài thì phải hiển thị kéo dài". Người dùng thử trên máy thật
/// và yêu cầu đổi: một dải đứng mãi trên đầu màn hình gây khó chịu hơn là hữu
/// ích, và thông tin "đang mất mạng" thì thanh trạng thái của hệ điều hành đã
/// nói rồi.
///
/// Câu trấn an trong toast mất kết nối ("thay đổi vẫn được lưu trên máy") vẫn
/// quan trọng ngang thông tin chính: thiếu nó, người dùng ngừng nhập liệu vì sợ
/// mất — đúng nỗi sợ mà kiến trúc offline-first sinh ra để xoá bỏ.
///
/// ## Thông báo đồng bộ không nêu số lượng
///
/// "Đã đồng bộ 5 thay đổi" nghe cụ thể hơn, nhưng con số ấy là chi tiết cài
/// đặt chứ không phải điều người dùng quan tâm — biết "đã xong" là đủ. Vẫn
/// phải phân biệt **xong** với **còn kẹt lại**: gộp hai trạng thái ấy vào một
/// câu là để người dùng tưởng dữ liệu đã an toàn.

/// Thời gian trượt + mờ, cho cả chiều vào lẫn chiều ra.
///
/// Công khai vì bộ test phải cộng nó vào khi chờ toast biến mất: nội dung được
/// giữ lại tới hết hiệu ứng ra, nên `find.text` còn thấy chữ trong khoảng ấy.
const Duration thoiGianHieuUngToast = Duration(milliseconds: 220);

/// Chiều cao thanh điều hướng dưới (`main_shell.dart`) cộng khoảng hở.
///
/// ⚠️ Widget này nằm ở `MaterialApp.builder`, TRÊN router, nên nó không biết
/// trang hiện tại có thanh điều hướng hay không. Trang ngoài shell sẽ thấy
/// toast nổi cao hơn mức cần thiết — chấp nhận đánh đổi đó thay vì dựng thêm
/// cơ chế truyền chiều cao ngược lên từ shell.
const double _cachDay = 80 + 12;

class AppToast extends StatefulWidget {
  const AppToast({
    super.key,
    required this.child,
    required this.connectionEvents,
    required this.pushResults,
    this.tuAnSau = const Duration(seconds: 4),
  });

  final Widget child;
  final Stream<ConnectionEvent> connectionEvents;
  final Stream<SyncResult> pushResults;

  /// Bao lâu thì toast tự biến mất. Áp dụng cho **mọi** toast, kể cả mất kết nối.
  final Duration tuAnSau;

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast> {
  StreamSubscription<ConnectionEvent>? _subKetNoi;
  StreamSubscription<SyncResult>? _subDay;
  Timer? _dongHoAn;
  Timer? _dongHoDon;

  _NoiDungToast? _dai;

  /// Đang ở vị trí hiện, hay đã trượt xuống chờ dọn.
  ///
  /// Tách khỏi [_dai] vì nội dung phải sống thêm đúng [thoiGianHieuUngToast]
  /// sau khi ẩn — bỏ nó đi ngay thì toast biến mất phụt, không có hiệu ứng ra.
  bool _dangHien = false;

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
    _dongHoDon?.cancel();
    super.dispose();
  }

  void _khiDoiKetNoi(ConnectionEvent e) {
    switch (e) {
      case ConnectionEvent.mat:
        _hien(
          const _NoiDungToast(
            chu: 'Không có kết nối — thay đổi vẫn được lưu trên máy',
            mau: AppColors.expense,
            icon: Icons.cloud_off_outlined,
            // Mất mạng là trạng thái ĐANG diễn ra, quan trọng hơn mọi tin về
            // việc vừa xong — có test canh điều này từ bản đầu.
            bac: _Bac.dongBo,
            nguon: _Nguon.ketNoi,
          ),
        );
      case ConnectionEvent.khoiPhuc:
        _hien(
          const _NoiDungToast(
            chu: 'Đã kết nối lại',
            mau: AppColors.income,
            icon: Icons.cloud_done_outlined,
            bac: _Bac.ketNoi,
            nguon: _Nguon.ketNoi,
          ),
        );
    }
  }

  void _khiDayXong(SyncResult r) {
    // "Đã đồng bộ 0 thay đổi" là câu vô nghĩa. SyncEngine đã không phát trong
    // trường hợp này, nhưng toast tự chống thêm một lớp.
    if (r.succeeded == 0 && r.failed == 0) return;

    if (r.failed > 0) {
      _hien(
        const _NoiDungToast(
          chu: 'Một số thay đổi chưa lên được máy chủ',
          mau: AppColors.expense,
          icon: Icons.sync_problem_outlined,
          bac: _Bac.dongBo,
          nguon: _Nguon.dongBo,
        ),
      );
      return;
    }

    _hien(
      const _NoiDungToast(
        chu: 'Đã đồng bộ xong',
        mau: AppColors.income,
        icon: Icons.cloud_done_outlined,
        bac: _Bac.dongBo,
        nguon: _Nguon.dongBo,
      ),
    );
  }

  void _hien(_NoiDungToast noiDung) {
    if (!mounted) return;

    // Đang có thông báo bậc CAO hơn hiện thì bỏ hẳn cái mới, KHÔNG xếp hàng:
    // một thông báo tạm thời trễ vài giây là thông báo sai ngữ cảnh.
    //
    // Hai điều kiện phụ, cả hai đều cần:
    //
    // - Chỉ tính khi toast cũ CÒN đang hiện. Cái đã hết hạn và đang mờ ra thì
    //   không được quyền chặn tin mới.
    // - Chỉ tính giữa hai nguồn KHÁC nhau. Một nguồn luôn được cập nhật chính
    //   nó: "Đã kết nối lại" mang bậc thấp nhưng nó thay thế đúng "Không có kết
    //   nối" mà nó nối tiếp. Bỏ vế này thì thứ tự trở thành một vòng luẩn quẩn —
    //   mất > đồng bộ > khôi phục, nhưng khôi phục lại phải thắng mất — và
    //   người dùng mất mạng một lần rồi sẽ không bao giờ thấy báo có mạng lại.
    final dangCo = _dai;
    if (_dangHien &&
        dangCo != null &&
        dangCo.nguon != noiDung.nguon &&
        dangCo.bac.index > noiDung.bac.index) {
      return;
    }

    _dongHoAn?.cancel();
    _dongHoDon?.cancel();
    setState(() {
      _dai = noiDung;
      _dangHien = true;
    });

    _dongHoAn = Timer(widget.tuAnSau, () {
      if (!mounted) return;
      setState(() => _dangHien = false);
      // Giữ nội dung tới hết hiệu ứng ra, nếu không nó biến mất phụt.
      _dongHoDon = Timer(thoiGianHieuUngToast, () {
        if (!mounted) return;
        setState(() => _dai = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dai = _dai;

    // `Stack` chứ không `Column`: toast nổi không được chạm vào bố cục trang.
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: 16,
            right: 16,
            bottom: _cachDay + MediaQuery.of(context).viewPadding.bottom,
            child: IgnorePointer(
              child: AnimatedSlide(
                duration: thoiGianHieuUngToast,
                curve: Curves.easeOutCubic,
                offset: _dangHien ? Offset.zero : const Offset(0, 0.5),
                child: AnimatedOpacity(
                  duration: thoiGianHieuUngToast,
                  opacity: _dangHien ? 1 : 0,
                  child: dai == null
                      ? const SizedBox.shrink()
                      : Center(child: _Vien(noiDung: dai)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viên thuốc nổi — thu gọn theo nội dung, không kéo hết bề ngang.
class _Vien extends StatelessWidget {
  const _Vien({required this.noiDung});

  final _NoiDungToast noiDung;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: 48,
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE3E3DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        // `min`: viên phải ôm lấy nội dung, không kéo hết bề ngang.
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: noiDung.mau,
              shape: BoxShape.circle,
            ),
            child: Icon(noiDung.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          // `Flexible` + `ellipsis`: câu dài phải co lại chứ không được tràn.
          // Máy thật rộng 411dp, bộ test mặc định 800dp.
          Flexible(
            child: Text(
              noiDung.chu,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bậc ưu tiên khi hai thông báo tranh nhau một chỗ. Bậc cao ghi đè bậc thấp;
/// **bằng bậc thì cái đến sau thắng** vì nó mới hơn.
///
/// Thứ tự này đến từ một quan sát trên máy thật: `SyncEngine` đẩy xong sau ~0,4
/// giây còn bộ theo dõi kết nối phải chờ hết ngưỡng ổn định 3 giây, nên không
/// xếp bậc thì toast đồng bộ luôn bị toast "đã kết nối lại" nuốt mất — mà đó
/// lại là toast trả lời đúng câu người dùng lo.
enum _Bac {
  /// Trạng thái kết nối — thấp nhất.
  ketNoi,

  /// Kết quả đồng bộ, và cả việc mất mạng — cao nhất. Cả hai nói về cùng một
  /// nỗi lo: dữ liệu vừa ghi đã an toàn chưa.
  dongBo,
}

/// Ai phát ra thông báo. Dùng để cho một nguồn được cập nhật chính nó bất kể
/// bậc — xem `_hien`.
enum _Nguon { ketNoi, dongBo }

class _NoiDungToast {
  const _NoiDungToast({
    required this.chu,
    required this.mau,
    required this.icon,
    required this.bac,
    required this.nguon,
  });

  final String chu;
  final Color mau;
  final IconData icon;
  final _Bac bac;
  final _Nguon nguon;
}
