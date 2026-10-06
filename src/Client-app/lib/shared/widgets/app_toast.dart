import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/connection_monitor.dart';
import '../../core/realtime/realtime_event.dart';
import '../../core/sync/sync_models.dart';
import '../../core/ui/thong_bao_nhanh.dart';
import '../theme/app_colors.dart';

/// Toast nổi ở đáy màn hình, báo tình trạng kết nối, kết quả đồng bộ, và các
/// sự kiện thời gian thực từ máy chủ.
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
/// ## Đồng bộ: chỉ báo khi THẤT BẠI, và không nêu số lượng
///
/// Từ 2026-10-02 (người dùng chốt) đồng bộ **thành công thì im**: nó chạy sau
/// mỗi lần ghi, nên viên "Đã đồng bộ xong" của bản trước hiện sau mỗi thao tác.
/// Chỉ còn câu **còn kẹt lại** — "Một số thay đổi chưa lên được máy chủ" — và
/// nó không nêu con số: bao nhiêu bản ghi là chi tiết cài đặt chứ không phải
/// điều người dùng quan tâm.

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
    required this.realtimeEvents,
    this.thongBaoNhanh = const Stream<ThongDiepNhanh>.empty(),
    this.tuAnSau = const Duration(seconds: 4),
  });

  final Widget child;
  final Stream<ConnectionEvent> connectionEvents;
  final Stream<SyncResult> pushResults;
  final Stream<RealtimeEvent> realtimeEvents;

  /// Câu tự do từ `ThongBaoNhanh` (2026-09-19) — "Nhấn lần nữa để thoát", và từ
  /// E4 (2026-10-06) mọi câu phản hồi của các trang ("Vui lòng chọn danh mục",
  /// "Đã xoá giao dịch"). Bậc CAO NHẤT — người dùng chọn: phản hồi cho cú bấm vừa
  /// xong thắng toast nền, kẻo bấm Lưu mà không thấy vì sao không lưu được.
  final Stream<ThongDiepNhanh> thongBaoNhanh;

  /// Bao lâu thì toast tự biến mất. Áp dụng cho **mọi** toast, kể cả mất kết nối.
  final Duration tuAnSau;

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast> {
  StreamSubscription<ConnectionEvent>? _subKetNoi;
  StreamSubscription<SyncResult>? _subDay;
  StreamSubscription<RealtimeEvent>? _subRealtime;
  StreamSubscription<ThongDiepNhanh>? _subNhanh;
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
    _subRealtime = widget.realtimeEvents.listen(_khiCoRealtime);
    _subNhanh = widget.thongBaoNhanh.listen(_khiCoNhanh);
  }

  @override
  void dispose() {
    _subKetNoi?.cancel();
    _subDay?.cancel();
    _subRealtime?.cancel();
    _subNhanh?.cancel();
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

    // Cả batch không tới nơi (mất mạng, timeout, 5xx): không thay đổi nào bị TỪ
    // CHỐI — chúng chưa được gửi. Câu "chưa lên được máy chủ" ở đây là báo sai
    // loại lỗi, và vì giãn cách luỹ tiến thử lại mãi nên nó hiện ở mọi chu kỳ
    // (A4, 2026-09-28: máy thật không tới được backend dev).
    if (r.transportFailed) return;

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

    // Thành công thì IM (người dùng chốt 2026-10-02) — đồng bộ chạy sau mỗi lần
    // ghi, nên viên "Đã đồng bộ xong" hiện sau mỗi thao tác. Xung đột LWW cũng
    // rơi vào đây: bản server thắng, không có gì "chưa lên được".
    //
    // Một việc vẫn phải làm: gỡ câu "chưa lên được" nếu nó đang hiện. SyncEngine
    // phát kết quả lần đẩy đầu TRƯỚC bước Pull rồi phát kết quả lần thử lại ở
    // cuối chu kỳ, nên một thất bại tạm thời tới đây hai lượt — lượt sau mà lọt
    // thì câu ấy đã hết đúng. Gỡ theo NGUỒN, không theo bậc: toast mất mạng mang
    // bậc đồng bộ nhưng không phải của nguồn này.
    if (_dangHien && _dai?.nguon == _Nguon.dongBo) _an();
  }

  /// Sự kiện từ máy chủ. Chữ và màu suy từ chính enum — payload không được đọc,
  /// xem chú thích đầu `realtime_event.dart`.
  void _khiCoRealtime(RealtimeEvent e) {
    // Sự kiện im lặng (`sync.completed`): chỉ đánh thức đồng bộ, không hiện gì.
    // Lý do ở chú thích của `RealtimeEvent.dongBoXong`.
    final chu = e.loiNhan;
    if (chu == null) return;
    final laCanhBao = e == RealtimeEvent.ocrTrung;
    _hien(
      _NoiDungToast(
        chu: chu,
        mau: laCanhBao ? AppColors.warning : AppColors.income,
        icon: laCanhBao
            ? Icons.info_outline
            : Icons.notifications_active_outlined,
        bac: _Bac.realtime,
        nguon: _Nguon.realtime,
      ),
    );
  }

  /// Câu phản hồi: bậc cao nhất, nguồn riêng — câu mới thay câu cũ cùng nguồn.
  void _khiCoNhanh(ThongDiepNhanh t) {
    final (mau, icon) = switch (t.loai) {
      LoaiThongBao.loi => (AppColors.expense, Icons.error_outline),
      LoaiThongBao.xong => (AppColors.income, Icons.check),
      LoaiThongBao.thongTin => (AppColors.primary, Icons.info_outline),
    };
    _hien(
      _NoiDungToast(
        chu: t.cau,
        mau: mau,
        icon: icon,
        bac: _Bac.phanHoi,
        nguon: _Nguon.nhanh,
        hanhDong: t.hanhDong,
      ),
    );
  }

  void _bamHanhDong(HanhDongToast h) {
    h.chay();
    _an();
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

    _dongHoAn = Timer(widget.tuAnSau, _an);
  }

  /// Cho toast đang hiện trượt ra rồi dọn — hết giờ, hoặc bị gỡ sớm.
  void _an() {
    _dongHoAn?.cancel();
    _dongHoDon?.cancel();
    if (!mounted) return;
    setState(() => _dangHien = false);
    // Giữ nội dung tới hết hiệu ứng ra, nếu không nó biến mất phụt.
    _dongHoDon = Timer(thoiGianHieuUngToast, () {
      if (!mounted) return;
      setState(() => _dai = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dai = _dai;

    // E4: bàn phím mở thì viên nổi 12 dp TRÊN bàn phím — đa số câu lỗi ("Vui lòng
    // nhập…") hiện đúng lúc form đang mở bàn phím, mà chỗ cố định trên thanh tab
    // thì nằm sau bàn phím.
    final mq = MediaQuery.of(context);
    final day = mq.viewInsets.bottom > 0
        ? mq.viewInsets.bottom + 12
        : _cachDay + mq.viewPadding.bottom;

    // `Stack` chứ không `Column`: toast nổi không được chạm vào bố cục trang.
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          Positioned(
            left: 16,
            right: 16,
            bottom: day,
            // Chỉ viên có nút mới nhận chạm — viên thường không được chặn trang
            // bên dưới. Viên đang trượt ra cũng thôi nhận chạm.
            child: IgnorePointer(
              ignoring: dai?.hanhDong == null || !_dangHien,
              child: AnimatedSlide(
                duration: thoiGianHieuUngToast,
                curve: Curves.easeOutCubic,
                offset: _dangHien ? Offset.zero : const Offset(0, 0.5),
                child: AnimatedOpacity(
                  duration: thoiGianHieuUngToast,
                  opacity: _dangHien ? 1 : 0,
                  child: dai == null
                      ? const SizedBox.shrink()
                      : Center(child: _Vien(noiDung: dai, khiBam: _bamHanhDong)),
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
  const _Vien({required this.noiDung, required this.khiBam});

  final _NoiDungToast noiDung;
  final void Function(HanhDongToast) khiBam;

  @override
  Widget build(BuildContext context) {
    final hanhDong = noiDung.hanhDong;
    return Container(
      key: const Key('toast-vien'),
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
            key: const Key('toast-vong'),
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
          // E4: 3 dòng — câu lỗi của các trang dài hơn câu nền.
          Flexible(
            child: Text(
              noiDung.chu,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (hanhDong != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => khiBam(hanhDong),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  hanhDong.nhan,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
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

  /// Sự kiện thời gian thực: một việc vừa xảy ra với tiền của người dùng.
  realtime,

  /// Kết quả đồng bộ, và cả việc mất mạng. Cả hai nói về cùng một nỗi lo: dữ
  /// liệu vừa ghi đã an toàn chưa.
  dongBo,

  /// Phản hồi cho cú bấm của người dùng (`ThongBaoNhanh`) — cao nhất từ E4
  /// (2026-10-06, người dùng chọn). Trước đó câu tự do ở bậc thấp nhất vì chỉ có
  /// "Nhấn lần nữa để thoát"; nay nó mang cả "Vui lòng chọn danh mục" — bị toast
  /// nền nuốt là bấm Lưu mà không biết vì sao không lưu được.
  phanHoi,
}

/// Ai phát ra thông báo. Dùng để cho một nguồn được cập nhật chính nó bất kể
/// bậc — xem `_hien`.
enum _Nguon { ketNoi, realtime, dongBo, nhanh }

class _NoiDungToast {
  const _NoiDungToast({
    required this.chu,
    required this.mau,
    required this.icon,
    required this.bac,
    required this.nguon,
    this.hanhDong,
  });

  final String chu;
  final Color mau;
  final IconData icon;
  final _Bac bac;
  final _Nguon nguon;
  final HanhDongToast? hanhDong;
}
