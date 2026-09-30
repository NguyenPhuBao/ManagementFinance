import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/notification_dao.dart';
import '../../../../core/notification/de_xuat_thong_bao_nguon.dart';
import '../../../../core/notification/hoc_gio_thong_bao.dart';
import '../../../../core/notification/nhat_ky_thong_bao.dart';
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
  const NotificationCenterPage({
    super.key,
    this.idaccount,
    this.dao,
    this.nhatKy,
    this.taiDeXuat,
    this.nhomBanDau,
  });

  /// D1 — chip nhóm chọn sẵn khi mở (`/notifications?nhom=bienDong` từ thẻ *"Có N biến động chưa ghi"* và cú chạm
  /// thông báo tóm tắt). `null` = *Tất cả*.
  final NotificationGroup? nhomBanDau;

  /// Route trang Cài đặt thông báo — đích của thẻ gợi ý B5b.
  static const String routeCaiDat = '/settings/notifications';

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

  /// Nhật ký thông báo (B5a) — tiêm cho test; mặc định `sl<NhatKyThongBao>()`.
  /// Chưa đăng ký thì trang vẫn chạy, chỉ không ghi nhật ký.
  final NhatKyThongBao? nhatKy;

  /// Đề xuất chỉnh thông báo (B5b) — nạp MỘT lần lúc mở trang và lúc quay về
  /// từ trang Cài đặt. Mặc định `DeXuatThongBaoNguon.tai`; tiêm được cho test.
  final Future<List<DeXuatThongBao>> Function(int idaccount)? taiDeXuat;

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
  late _Loc _loc = _Loc.values.firstWhere(
    (l) => widget.nhomBanDau != null && l.nhom == widget.nhomBanDau,
    orElse: () => _Loc.tatCa,
  );

  /// Đề xuất B5b — ảnh chụp, không nghe stream (spec B5b §3).
  List<DeXuatThongBao> _deXuat = const [];

  @override
  void initState() {
    super.initState();
    _napDeXuat();
  }

  /// Nuốt lỗi: thẻ gợi ý là phần phụ, trục trặc ở đây không được làm vỡ feed.
  Future<void> _napDeXuat() async {
    final id = widget.idaccount;
    if (id == null) return;
    List<DeXuatThongBao> r = const [];
    try {
      final tai = widget.taiDeXuat ??
          (sl.isRegistered<DeXuatThongBaoNguon>()
              ? sl<DeXuatThongBaoNguon>().tai
              : null);
      if (tai != null) r = await tai(id);
    } catch (e) {
      debugPrint('[TrungTamThongBao] nạp đề xuất hỏng: $e');
    }
    if (mounted) setState(() => _deXuat = r);
  }

  /// Mở trang Cài đặt rồi nạp lại khi quay về: áp dụng hay bỏ qua ở bên kia
  /// làm đề xuất biến mất, không nạp lại là thẻ nói về thứ đã xử lý.
  Future<void> _moCaiDat() async {
    const route = NotificationCenterPage.routeCaiDat;
    // Cùng luật với cú chạm thông báo: route thuộc thanh tab thì `go` (bẫy 7.8).
    if (thuocThanhTab(route)) {
      context.go(route);
      return;
    }
    await context.push(route);
    await _napDeXuat();
  }

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
    final nhatKy = widget.nhatKy ??
        (sl.isRegistered<NhatKyThongBao>() ? sl<NhatKyThongBao>() : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Quay lại',
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
                  onPressed: chuaDoc == 0
                      ? null
                      : () async {
                          // Đọc khoá TRƯỚC khi đánh dấu: sau `markAllRead` thì
                          // tập "chưa đọc" đã rỗng. Một `doc_tat_ca` mỗi khoá.
                          final khoa = await dao.khoaChuaDoc(idaccount);
                          await dao.markAllRead(idaccount);
                          if (nhatKy != null) {
                            unawaited(nhatKy.ghiNhieu(khoa, SuKienThongBao.docTatCa,
                                idaccount: idaccount));
                          }
                        },
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
                // Thẻ gợi ý B5b đứng TRÊN feed và ngoài nó: không phải một
                // thông báo, và vẫn hiện khi feed rỗng hay đang lọc.
                if (_deXuat.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _TheGoiY(deXuat: _deXuat, onTap: _moCaiDat),
                  ),
                Expanded(child: _danhSach(dao, idaccount, nhatKy)),
              ],
            ),
    );
  }

  Widget _danhSach(NotificationDao dao, int idaccount, NhatKyThongBao? nhatKy) {
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
                if (nhatKy != null) {
                  unawaited(nhatKy.ghi(items[i].dedupeKey,
                      SuKienThongBao.moTrongApp, idaccount: idaccount));
                }
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
              onDismiss: () =>
                  _xoaCoHoanTac(context, dao, items[i], nhatKy, idaccount),
            );
          },
        );
      },
    );
  }
}

/// Thẻ *"Có N gợi ý chỉnh thông báo"* — màn Stitch `65dab656…`. Cùng khung
/// với thẻ thông báo (viền nhạt, bo 12, vòng biểu tượng 36) nhưng **không** có
/// dải màu chưa đọc, không giờ, không badge — nó là lối vào trang Cài đặt.
class _TheGoiY extends StatelessWidget {
  const _TheGoiY({required this.deXuat, required this.onTap});

  final List<DeXuatThongBao> deXuat;
  final VoidCallback onTap;

  /// Phụ đề nói đúng loại gợi ý đang có: giờ nhắc, nhóm ít khi mở, hay cả hai.
  String get _phuDe {
    final coGio = deXuat.any((d) => d.loai != LoaiDeXuat.tatNhom);
    final coNhom = deXuat.any((d) => d.loai == LoaiDeXuat.tatNhom);
    if (coGio && coNhom) return 'Giờ nhắc và nhóm ít khi mở';
    return coGio ? 'Giờ nhắc' : 'Nhóm ít khi mở';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0DB)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune,
                    size: 18, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Có ${deXuat.length} gợi ý chỉnh thông báo',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _phuDe,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bộ lọc của trung tâm thông báo.
///
/// "Chưa đọc" nằm chung dải với các nhóm thay vì là một công tắc riêng: hai bộ
/// lọc chồng nhau (nhóm × trạng thái đọc) là mười hai tổ hợp người dùng phải
/// tự dựng trong đầu, còn một dải chip thì đọc được bằng mắt và luôn có đúng
/// một mục đang sáng.
/// ⚠️ **Mỗi `NotificationGroup` phải có đúng một mục ở đây.** Lưới an toàn
/// của `kinds` bên dưới canh `nhomCua()`, tức nó bắt được "loại mới quên xếp
/// nhóm" — nhưng **không** bắt được "nhóm mới quên chip". Nhóm `summary`
/// (2026-09-09) đã lọt qua đúng khe ấy và thông báo Tổng kết tuần chỉ hiện ở
/// "Tất cả". Phép canh còn thiếu nay nằm ở `notification_center_page_test`:
/// số `ChoiceChip` phải bằng `NotificationGroup.values.length + 2`.
enum _Loc { tatCa, chuaDoc, hoaDon, nganSach, mucTieu, heThong, tongKet, bienDong }

extension on _Loc {
  String get nhan => switch (this) {
        _Loc.tatCa => 'Tất cả',
        _Loc.chuaDoc => 'Chưa đọc',
        _Loc.hoaDon => 'Hoá đơn',
        _Loc.nganSach => 'Ngân sách',
        _Loc.mucTieu => 'Mục tiêu',
        _Loc.heThong => 'Hệ thống',
        _Loc.tongKet => 'Tổng kết',
        _Loc.bienDong => 'Biến động',
      };

  /// Nhóm tương ứng — `null` với hai chip không lọc theo nhóm.
  NotificationGroup? get nhom => switch (this) {
        _Loc.hoaDon => NotificationGroup.bill,
        _Loc.nganSach => NotificationGroup.budget,
        _Loc.mucTieu => NotificationGroup.goal,
        _Loc.heThong => NotificationGroup.system,
        _Loc.tongKet => NotificationGroup.summary,
        _Loc.bienDong => NotificationGroup.bienDong,
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
///
/// Lần dựng ĐẦU tự cuộn tới chip đang chọn: mở với `nhomBanDau` (D1 — thẻ *Có N biến động chưa ghi*, cú chạm tóm tắt)
/// chọn chip *Biến động* ở CUỐI dải, và ở 411 dp nó nằm ngoài mép phải — đo trên OnePlus 2026-09-30, người dùng thấy
/// *"Không có thông báo nào khớp bộ lọc"* mà không biết đang lọc gì.
class _HangChip extends StatefulWidget {
  final _Loc dangChon;
  final ValueChanged<_Loc> onChon;

  const _HangChip({required this.dangChon, required this.onChon});

  @override
  State<_HangChip> createState() => _HangChipState();
}

class _HangChipState extends State<_HangChip> {
  final GlobalKey _khoaDangChon = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.dangChon == _Loc.tatCa) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _khoaDangChon.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dangChon = widget.dangChon;
    final onChon = widget.onChon;
    // Cuộn ngang chứ không `Wrap`: bảy chip cần khoảng 630px còn điện thoại
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
                key: loc == dangChon ? _khoaDangChon : null,
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
  NhatKyThongBao? nhatKy,
  int idaccount,
) async {
  final thanh = ScaffoldMessenger.of(context);
  // D1: hàng biến động số dư — vuốt là *Bỏ qua*, xoá CỨNG (spec D1 §3.3: nội dung tin ngân hàng không nằm lại dưới
  // dạng hàng gạt mềm). Hoàn tác chèn lại đúng hàng đã chụp, nên vuốt nhầm vẫn lấy lại được.
  final laBienDong = item.kind == NotificationKind.bienDongSoDu.name;
  if (laBienDong) {
    await dao.xoaCung(item.idaccount, item.dedupeKey);
  } else {
    await dao.dismiss(item.id);
  }
  if (nhatKy != null) {
    unawaited(nhatKy.ghi(item.dedupeKey, SuKienThongBao.gatBo, idaccount: idaccount));
  }

  // Nội dung chung chung và tự ẩn sau vài giây: dải tạm thời là để báo việc
  // vừa xảy ra, không phải để đọc lại chi tiết.
  thanh.hideCurrentSnackBar();
  thanh.showSnackBar(
    SnackBar(
      content: const Text('Đã xoá thông báo'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Hoàn tác',
        onPressed: () {
          if (laBienDong) {
            dao.insertIfAbsent(item.toCompanion(true));
          } else {
            dao.khoiPhuc(item.id);
          }
          if (nhatKy != null) {
            unawaited(nhatKy.ghi(item.dedupeKey, SuKienThongBao.khoiPhuc, idaccount: idaccount));
          }
        },
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
