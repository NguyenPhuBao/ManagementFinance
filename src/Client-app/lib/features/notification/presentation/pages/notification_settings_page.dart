import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/notification/os/os_notifier.dart';
import '../../../../core/notification/prefs/notification_prefs.dart';
import '../../../../core/notification/prefs/notification_prefs_store.dart';
import '../../../../shared/theme/app_colors.dart';

/// Trang cài đặt thông báo — `/settings/notifications`.
///
/// Thiết kế Stitch **chưa vẽ màn này**; bố cục bám đúng kiểu thẻ đang dùng ở
/// `settings_page.dart` (thẻ trắng bo 12, tiêu đề mục chữ hoa, mỗi hàng là
/// icon + nhãn + control, ngăn nhau bằng `Divider`).
///
/// Trang **không có nút Lưu**: mỗi thay đổi ghi thẳng xuống kho. Trang cài đặt
/// kiểu này không ai đi tìm nút lưu — họ gạt công tắc rồi bấm quay lại.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.idaccount,
    this.store,
    this.osNotifier,
  });

  /// Tài khoản đang đăng nhập, `null` khi chưa có phiên dùng được.
  ///
  /// Trang **không tự đi hỏi `AuthBloc`**: nơi gọi (route) đọc
  /// `currentAccountIdOrNull` rồi truyền vào. Cùng mẫu với `NotificationPanel`.
  /// Nhờ vậy trang là một widget thuần, dựng được trong test mà không phải
  /// dựng cả cây bloc, và trạng thái "chưa đăng nhập" test được thật sự chứ
  /// không phải suy ra từ một ngoại lệ thiếu provider.
  final int? idaccount;

  final NotificationPrefsStore? store;
  final OsNotifier? osNotifier;

  static const Key khoaCongTacOs = Key('notification_settings_os');

  static Key khoaCongTacNhom(NotificationGroup nhom) =>
      Key('notification_settings_${nhom.name}');

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPrefs _prefs = NotificationPrefs.macDinh;
  bool _dangNap = true;
  int? _idaccount;

  NotificationPrefsStore get _store =>
      widget.store ?? sl<NotificationPrefsStore>();

  OsNotifier get _os => widget.osNotifier ?? sl<OsNotifier>();

  @override
  void initState() {
    super.initState();
    _nap();
  }

  Future<void> _nap() async {
    final id = widget.idaccount;
    if (id == null) {
      if (mounted) setState(() => _dangNap = false);
      return;
    }

    final p = await _store.read(id);
    if (!mounted) return;
    setState(() {
      _idaccount = id;
      _prefs = p;
      _dangNap = false;
    });
  }

  Future<void> _ghi(NotificationPrefs moi) async {
    final id = _idaccount;
    // `idaccount` CHỈ đến từ phiên đăng nhập — không có thì không ghi gì cả.
    // Mặc định về 1 là ghi tuỳ chọn vào hồ sơ tài khoản admin thật.
    if (id == null) return;

    setState(() => _prefs = moi);
    await _store.write(id, moi);
  }

  /// Bật công tắc tổng là chỗ **duy nhất** trong app xin quyền thông báo.
  ///
  /// Xin đúng lúc này chứ không lúc mở app: trên iOS người dùng chỉ được hỏi
  /// **một lần** trong cả vòng đời cài đặt, và từ chối là mất vĩnh viễn. Hỏi
  /// khi họ vừa chủ động bật công tắc là lúc khả năng đồng ý cao nhất.
  Future<void> _doiCongTacOs(bool bat) async {
    if (!bat) {
      await _ghi(_prefs.copyWith(osBat: false));
      return;
    }

    final duoc = await _os.requestPermission();
    // Hệ điều hành từ chối thì công tắc phải quay về tắt. Để nó sáng là nói
    // dối: người dùng tưởng đã bật và sẽ không bao giờ đi tìm lý do vì sao
    // chẳng nhận được gì.
    await _ghi(_prefs.copyWith(osBat: duoc));

    if (!duoc && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hệ điều hành đang chặn thông báo của FlowMoney. '
            'Bật lại trong Cài đặt của máy.',
          ),
        ),
      );
    }
  }

  Future<void> _doiNhom(NotificationGroup nhom, bool bat) async {
    final tat = {..._prefs.nhomTat};
    if (bat) {
      tat.remove(nhom);
    } else {
      tat.add(nhom);
    }
    await _ghi(_prefs.copyWith(nhomTat: tat));
  }

  Future<void> _chonGio() async {
    final chon = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _prefs.gioNhac, minute: _prefs.phutNhac),
    );
    if (chon == null) return;
    await _ghi(_prefs.copyWith(gioNhac: chon.hour, phutNhac: chon.minute));
  }

  @override
  Widget build(BuildContext context) {
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
          'Cài đặt thông báo',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _dangNap
          ? const Center(child: CircularProgressIndicator())
          : _idaccount == null
              ? const _ChuaDangNhap()
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _the(
                        tieuDe: 'THÔNG BÁO TRÊN MÁY',
                        children: [
                          _hangCongTac(
                            khoa: NotificationSettingsPage.khoaCongTacOs,
                            icon: Icons.notifications_active_outlined,
                            nhan: 'Hiện trên màn hình khoá',
                            phu: 'Tắt thì thông báo vẫn được lưu trong app, '
                                'chỉ không hiện ra ngoài.',
                            giaTri: _prefs.osBat,
                            onChanged: _doiCongTacOs,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _the(
                        tieuDe: 'LOẠI THÔNG BÁO',
                        children: [
                          for (final nhom in NotificationGroup.values) ...[
                            if (nhom != NotificationGroup.values.first)
                              const Divider(
                                  height: 1, color: AppColors.outlineVariant),
                            _hangCongTac(
                              khoa: NotificationSettingsPage.khoaCongTacNhom(
                                  nhom),
                              icon: _iconNhom(nhom),
                              nhan: _tenNhom(nhom),
                              phu: _moTaNhom(nhom),
                              giaTri: _prefs.batNhom(nhom),
                              onChanged: (v) => _doiNhom(nhom, v),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      _the(
                        tieuDe: 'NHẮC HOÁ ĐƠN',
                        children: [
                          _hangBam(
                            icon: Icons.schedule_outlined,
                            nhan: 'Giờ nhắc trong ngày',
                            phu: 'Nhắc đặt trước sẽ nổ vào giờ này.',
                            trailing: Text(
                              _gioHienThi,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            onTap: _chonGio,
                          ),
                          const Divider(
                              height: 1, color: AppColors.outlineVariant),
                          _hangSoNgay(),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  String get _gioHienThi =>
      '${_prefs.gioNhac.toString().padLeft(2, '0')}:'
      '${_prefs.phutNhac.toString().padLeft(2, '0')}';

  Widget _the({required String tieuDe, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              tieuDe,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _hangCongTac({
    required Key khoa,
    required IconData icon,
    required String nhan,
    required String phu,
    required bool giaTri,
    required ValueChanged<bool> onChanged,
  }) {
    return _khung(
      icon: icon,
      nhan: nhan,
      phu: phu,
      trailing: Switch(
        key: khoa,
        value: giaTri,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF006E1C),
      ),
    );
  }

  Widget _hangBam({
    required IconData icon,
    required String nhan,
    required String phu,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: _khung(icon: icon, nhan: nhan, phu: phu, trailing: trailing),
    );
  }

  Widget _hangSoNgay() {
    // Danh sách rời chứ không phải ô nhập số: nhập tay mở đường cho những giá
    // trị vô nghĩa (âm, 400) mà `NotificationPrefs` sẽ lặng lẽ quy về mặc định
    // — người dùng gõ xong thấy số nhảy về 3 và không hiểu vì sao.
    const luaChon = [0, 1, 2, 3, 5, 7];

    return _khung(
      icon: Icons.event_outlined,
      nhan: 'Nhắc trước',
      phu: 'Dùng cho hoá đơn không tự đặt số ngày.',
      trailing: DropdownButton<int>(
        value: luaChon.contains(_prefs.soNgayNhacHoaDon)
            ? _prefs.soNgayNhacHoaDon
            : null,
        hint: Text('${_prefs.soNgayNhacHoaDon} ngày'),
        underline: const SizedBox.shrink(),
        items: [
          for (final n in luaChon)
            DropdownMenuItem(
              value: n,
              child: Text(n == 0 ? 'Đúng ngày' : '$n ngày'),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          _ghi(_prefs.copyWith(soNgayNhacHoaDon: v));
        },
      ),
    );
  }

  Widget _khung({
    required IconData icon,
    required String nhan,
    required String phu,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nhan,
                  style: const TextStyle(
                      fontSize: 16, color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  phu,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

String _tenNhom(NotificationGroup nhom) {
  switch (nhom) {
    case NotificationGroup.bill:
      return 'Hoá đơn';
    case NotificationGroup.budget:
      return 'Ngân sách';
    case NotificationGroup.goal:
      return 'Mục tiêu';
    case NotificationGroup.system:
      return 'Hệ thống';
  }
}

String _moTaNhom(NotificationGroup nhom) {
  switch (nhom) {
    case NotificationGroup.bill:
      return 'Sắp đến hạn và quá hạn.';
    case NotificationGroup.budget:
      return 'Sắp chạm ngưỡng và đã vượt hạn mức.';
    case NotificationGroup.goal:
      return 'Hoàn thành và trễ tiến độ.';
    case NotificationGroup.system:
      return 'Đồng bộ hỏng và số dư ví âm.';
  }
}

IconData _iconNhom(NotificationGroup nhom) {
  switch (nhom) {
    case NotificationGroup.bill:
      return Icons.receipt_long_outlined;
    case NotificationGroup.budget:
      return Icons.account_balance_wallet_outlined;
    case NotificationGroup.goal:
      return Icons.flag_outlined;
    case NotificationGroup.system:
      return Icons.sync_problem_outlined;
  }
}

class _ChuaDangNhap extends StatelessWidget {
  const _ChuaDangNhap();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Vui lòng đăng nhập để cài đặt thông báo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
