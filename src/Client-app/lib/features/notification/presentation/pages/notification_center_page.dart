import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/notification_dao.dart';
import '../../../../core/notification/notification_deeplink.dart';
import '../../../../core/notification/notification_rules.dart';
import '../../../../core/notification/prefs/notification_prefs.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../shared/theme/app_colors.dart';

/// Trung tâm thông báo — màn "Xem tất cả" từ panel trên trang chủ.
///
/// Thiết kế Stitch chưa vẽ màn này (chỉ có panel rút gọn trên Home), nên bố cục
/// bám hệ màu và kiểu thẻ đang dùng thật trong `AppColors`.
class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key, this.idaccount, this.dao});

  /// Tài khoản đang đăng nhập, `null` khi chưa có phiên dùng được.
  ///
  /// ⚠️ Trang **không tự đi hỏi `AuthBloc`**: nơi gọi (route) đọc
  /// `currentAccountIdOrNull` rồi truyền vào, đúng mẫu `NotificationSettingsPage`
  /// và `NotificationPanel`.
  ///
  /// Bản đầu viết `idaccount ?? currentAccountIdOrNull(context)` và đó là một
  /// lỗi thật: `null` khi ấy mang **hai nghĩa** — "chưa đăng nhập" và "chưa
  /// truyền, đi hỏi AuthBloc" — nên trạng thái chưa đăng nhập không biểu diễn
  /// được nếu trong cây không có provider, và nó ném `ProviderNotFoundException`
  /// ngay giữa `build`.
  final int? idaccount;

  /// Bỏ trống thì lấy từ chỗ dựng phụ thuộc. Ở đây `??` là an toàn: một DAO
  /// không bao giờ mang nghĩa "cố ý để trống".
  final NotificationDao? dao;

  @override
  State<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  /// Số hàng của trang đầu, và cũng là bước tăng mỗi lần bấm "Tải thêm".
  ///
  /// 20 chứ không phải 50 như mặc định của `watchFeed`: mỗi mục ở đây là một
  /// thẻ có viền và ba dòng chữ, nên 50 hàng ngay từ đầu là một nhịp khựng
  /// thấy được — cho một danh sách mà người dùng gần như không bao giờ cuộn hết.
  static const int _buocTrang = 20;

  int _gioiHan = _buocTrang;
  _Loc _loc = _Loc.tatCa;

  void _doiLoc(_Loc moi) {
    setState(() {
      _loc = moi;
      // Về lại trang đầu. Giữ nguyên giới hạn cũ thì đổi bộ lọc xong là tải
      // luôn sáu chục hàng của nhóm mới — đúng thứ phân trang sinh ra để tránh.
      _gioiHan = _buocTrang;
    });
  }

  @override
  Widget build(BuildContext context) {
    final idaccount = widget.idaccount;
    final dao = widget.dao ?? sl<AppDatabase>().notificationDao;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thông báo',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (idaccount != null)
            StreamBuilder<int>(
              stream: dao.watchUnreadCount(idaccount),
              builder: (context, snapshot) {
                final chuaDoc = snapshot.data ?? 0;
                return TextButton(
                  onPressed:
                      chuaDoc == 0 ? null : () => dao.markAllRead(idaccount),
                  child: Text(
                    'Đọc tất cả',
                    style: TextStyle(
                      color: chuaDoc == 0
                          ? AppColors.outlineVariant
                          : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: idaccount == null
          ? const _Rong(loi: 'Vui lòng đăng nhập để xem thông báo.')
          : Column(
              children: [
                _HangChip(dangChon: _loc, onChon: _doiLoc),
                Expanded(child: _danhSach(dao, idaccount)),
              ],
            ),
    );
  }

  Widget _danhSach(NotificationDao dao, int idaccount) {
    return StreamBuilder<List<AppNotification>>(
      stream: dao.watchFeed(
        idaccount,
        limit: _gioiHan,
        kinds: _loc.kinds,
        chiChuaDoc: _loc.chiChuaDoc,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return _Rong(
            loi: _loc == _Loc.tatCa
                ? 'Chưa có thông báo nào.'
                : 'Không có thông báo nào khớp bộ lọc.',
          );
        }

        // "Còn hàng chưa tải" suy ra từ việc trang này ĐẦY, không từ một truy
        // vấn COUNT riêng: thêm một stream thứ hai chỉ để biết điều đó là nhân
        // đôi số lần đánh thức cho một câu trả lời dùng đúng một lần mỗi khung
        // hình. Đánh đổi đã biết: khi số hàng chia hết cho bước trang thì nút
        // thừa ra một lượt — bấm vào thì danh sách không dài thêm và nút biến
        // mất. Rẻ hơn hẳn cái giá của phương án kia.
        final coTheTaiThem = items.length >= _gioiHan;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length + (coTheTaiThem ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return _NutTaiThem(
                onNhan: () => setState(() => _gioiHan += _buocTrang),
              );
            }
            return _ThongBaoTile(
              item: items[i],
              onTap: () {
                dao.markRead(items[i].id);
                final route = items[i].deeplink;
                if (route == null) return;
                // `go` chứ không `push` cho route thuộc thanh tab: push
                // dựng thêm một bản shell thứ hai chồng lên bản đang có,
                // hai bản trùng page key và Navigator ném assertion —
                // app chết màn đỏ. Xem `notification_deeplink.dart`.
                if (thuocThanhTab(route)) {
                  context.go(route);
                } else {
                  context.push(route);
                }
              },
              onLongPress: () => _doiTrangThaiDoc(context, dao, items[i]),
              onDismiss: () => _xoaCoHoanTac(context, dao, items[i]),
            );
          },
        );
      },
    );
  }
}

/// Bộ lọc của trung tâm thông báo.
///
/// "Chưa đọc" nằm chung dải với bốn nhóm thay vì là một công tắc riêng: hai bộ
/// lọc chồng nhau (nhóm × trạng thái đọc) là mười hai tổ hợp người dùng phải
/// tự dựng trong đầu, còn một dải chip thì đọc được bằng mắt và luôn có đúng
/// một mục đang sáng.
enum _Loc { tatCa, chuaDoc, hoaDon, nganSach, mucTieu, heThong }

extension on _Loc {
  String get nhan => switch (this) {
        _Loc.tatCa => 'Tất cả',
        _Loc.chuaDoc => 'Chưa đọc',
        _Loc.hoaDon => 'Hoá đơn',
        _Loc.nganSach => 'Ngân sách',
        _Loc.mucTieu => 'Mục tiêu',
        _Loc.heThong => 'Hệ thống',
      };

  /// Nhóm tương ứng — `null` với hai chip không lọc theo nhóm.
  NotificationGroup? get nhom => switch (this) {
        _Loc.hoaDon => NotificationGroup.bill,
        _Loc.nganSach => NotificationGroup.budget,
        _Loc.mucTieu => NotificationGroup.goal,
        _Loc.heThong => NotificationGroup.system,
        _Loc.tatCa || _Loc.chuaDoc => null,
      };

  /// Danh sách `kind` gửi xuống DAO. `null` nghĩa là **không lọc theo loại**.
  ///
  /// Suy từ `nhomCua()` chứ không chép tay: bảng ấy dùng `switch` không có
  /// `default`, nên thêm một `NotificationKind` mà quên xếp nhóm là lỗi biên
  /// dịch. Một danh sách chép tay ở đây là bỏ đúng cái lưới ấy đi — loại mới
  /// sẽ lặng lẽ không lọt vào chip nào.
  List<String>? get kinds {
    final n = nhom;
    if (n == null) return null;
    return [
      for (final k in NotificationKind.values)
        if (nhomCua(k) == n) k.name,
    ];
  }

  bool get chiChuaDoc => this == _Loc.chuaDoc;
}

/// Dải chip lọc, cuộn ngang.
class _HangChip extends StatelessWidget {
  final _Loc dangChon;
  final ValueChanged<_Loc> onChon;

  const _HangChip({required this.dangChon, required this.onChon});

  @override
  Widget build(BuildContext context) {
    // Cuộn ngang chứ không `Wrap`: sáu chip cần khoảng 540px còn điện thoại
    // thật rộng 411dp, nên `Wrap` xuống hàng thứ hai và ăn mất một thẻ thông
    // báo trên màn hình vốn đã chật. `SingleChildScrollView` cho `Row` bề rộng
    // vô hạn nên cũng không bao giờ tràn.
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (final loc in _Loc.values) ...[
              ChoiceChip(
                label: Text(loc.nhan),
                selected: loc == dangChon,
                onSelected: (_) => onChon(loc),
                showCheckmark: false,
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: loc == dangChon
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: loc == dangChon
                      ? AppColors.primary
                      : AppColors.outlineVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutTaiThem extends StatelessWidget {
  final VoidCallback onNhan;

  const _NutTaiThem({required this.onNhan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onNhan,
        child: const Text(
          'Tải thêm',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Đảo cờ đã đọc của một thông báo.
///
/// Nhấn giữ chứ không phải một nút riêng trên thẻ: chạm đã dùng cho điều hướng
/// và vuốt trái đã dùng cho xoá, nên đây là cử chỉ còn trống. Đánh đổi đã
/// biết — nhấn giữ khó phát hiện, nên dải báo bên dưới là chỗ duy nhất nói cho
/// người dùng biết vừa xảy ra chuyện gì.
Future<void> _doiTrangThaiDoc(
  BuildContext context,
  NotificationDao dao,
  AppNotification item,
) async {
  final thanh = ScaffoldMessenger.of(context);
  final daDoc = item.readAt != null;

  if (daDoc) {
    await dao.markUnread(item.id);
  } else {
    await dao.markRead(item.id);
  }

  thanh.hideCurrentSnackBar();
  thanh.showSnackBar(SnackBar(
    content: Text(daDoc ? 'Đã đánh dấu chưa đọc' : 'Đã đánh dấu đã đọc'),
    duration: const Duration(seconds: 2),
  ));
}

/// Xoá mềm kèm một lối quay lại.
///
/// Vuốt xoá là thao tác dễ lỡ tay nhất trên danh sách, và ở đây nó đắt hơn
/// bình thường: hàng đã xoá **vẫn nằm trong bảng** để chặn trùng, nên lượt quét
/// sau nhìn thấy `dedupeKey` ấy rồi bỏ qua. Không có nút hoàn tác thì một cú
/// vuốt nhầm làm thông báo biến mất khỏi giao diện vĩnh viễn.
Future<void> _xoaCoHoanTac(
  BuildContext context,
  NotificationDao dao,
  AppNotification item,
) async {
  final thanh = ScaffoldMessenger.of(context);
  await dao.dismiss(item.id);

  // Nội dung chung chung và tự ẩn sau vài giây: dải tạm thời là để báo việc
  // vừa xảy ra, không phải để đọc lại chi tiết.
  thanh.hideCurrentSnackBar();
  thanh.showSnackBar(
    SnackBar(
      content: const Text('Đã xoá thông báo'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () => dao.khoiPhuc(item.id),
      ),
    ),
  );
}

class _ThongBaoTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDismiss;

  const _ThongBaoTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onDismiss,
  });

  Color get _mau => switch (item.severity) {
        'critical' => AppColors.error,
        'warning' => AppColors.expense,
        _ => AppColors.income,
      };

  IconData get _bieuTuong => switch (item.subjectType) {
        'budget' => Icons.pie_chart_outline,
        'bill' => Icons.receipt_long,
        'goal' => Icons.savings_outlined,
        'sync' => Icons.sync_problem,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final daDoc = item.readAt != null;

    return Dismissible(
      key: ValueKey('notification-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: daDoc ? AppColors.surfaceContainerLow : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0DB)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dải màu chỉ vẽ cho mục CHƯA đọc: đã đọc rồi thì nó chỉ còn là
                // nhiễu thị giác.
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: daDoc ? Colors.transparent : _mau,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _mau.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_bieuTuong, size: 18, color: _mau),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: daDoc
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.body,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                relativeTimeVi(item.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rong extends StatelessWidget {
  final String loi;
  const _Rong({required this.loi});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_off_outlined,
              size: 56, color: AppColors.outlineVariant),
          const SizedBox(height: 12),
          Text(loi,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
