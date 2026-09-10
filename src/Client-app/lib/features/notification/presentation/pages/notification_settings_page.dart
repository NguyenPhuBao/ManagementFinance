import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/notification/os/os_notifier.dart';
import '../../../../core/notification/prefs/notification_prefs.dart';
import '../../../../core/notification/prefs/notification_prefs_store.dart';
import '../../../../core/utils/currency_formatter.dart';
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

  static const Key khoaCongTacImLang = Key('notification_settings_im_lang');

  static Key khoaCongTacNhom(NotificationGroup nhom) =>
      Key('notification_settings_${nhom.name}');

  static const Key khoaNguongSoDu = Key('notification_settings_nguong_so_du');

  static const Key khoaCongTacGhiChep =
      Key('notification_settings_ghi_chep');

  static const Key khoaGioGhiChep = Key('notification_settings_gio_ghi_chep');

  static const Key khoaCongTacTongKet =
      Key('notification_settings_tong_ket');
  static const Key khoaThuTongKet = Key('notification_settings_thu_tong_ket');
  static const Key khoaGioTongKet = Key('notification_settings_gio_tong_ket');

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  NotificationPrefs _prefs = NotificationPrefs.macDinh;
  bool _dangNap = true;
  int? _idaccount;

  /// Hệ điều hành có **đang** cho phép hiện thông báo không.
  ///
  /// Tách khỏi `_prefs.osBat` vì hai thứ này trả lời hai câu khác nhau:
  /// `osBat` là *ý muốn của người dùng*, còn cờ này là *sự thật của máy*.
  /// Người dùng có thể thu hồi quyền trong Cài đặt của máy sau khi đã bật công
  /// tắc, và khi ấy công tắc sáng trong lúc thông báo bị chặn hoàn toàn — nó
  /// nói dối, và họ sẽ không bao giờ đi tìm lý do vì sao chẳng nhận được gì.
  bool _coQuyenOs = true;

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

    // Chỉ HỎI, tuyệt đối không XIN: trên iOS người dùng chỉ được hỏi một lần
    // trong cả vòng đời cài đặt, tiêu phí nó lúc mở trang là mất vĩnh viễn.
    // Chỉ hỏi khi người dùng đã bật — tắt rồi thì câu trả lời không đổi gì.
    final coQuyen = p.osBat ? await _os.daCoQuyen() : true;

    if (!mounted) return;
    setState(() {
      _idaccount = id;
      _prefs = p;
      _coQuyenOs = coQuyen;
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
    if (mounted) setState(() => _coQuyenOs = duoc);
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

  /// Giờ RIÊNG cho lời nhắc ghi chép — xem `NotificationPrefs.gioNhacGhiChep`.
  Future<void> _chonGioGhiChep() async {
    final chon = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: _prefs.gioNhacGhiChep, minute: _prefs.phutNhacGhiChep),
    );
    if (chon == null) return;
    await _ghi(_prefs.copyWith(
      gioNhacGhiChep: chon.hour,
      phutNhacGhiChep: chon.minute,
    ));
  }

  /// Giờ RIÊNG cho Tổng kết tuần — xem `NotificationPrefs.thuTongKet`.
  Future<void> _chonGioTongKet() async {
    final chon = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: _prefs.gioTongKet, minute: _prefs.phutTongKet),
    );
    if (chon == null) return;
    await _ghi(_prefs.copyWith(
      gioTongKet: chon.hour,
      phutTongKet: chon.minute,
    ));
  }

  /// Chọn thứ trong tuần. Bảy dòng trong một bảng chọn thay vì bảy chip: chúng
  /// không vừa một hàng ở 411dp, và một `Wrap` hai hàng đọc như hai nhóm.
  Future<void> _chonThuTongKet() async {
    final chon = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var thu = DateTime.monday; thu <= DateTime.sunday; thu++)
              ListTile(
                title: Text(_tenThu(thu)),
                trailing: thu == _prefs.thuTongKet
                    ? const Icon(Icons.check, color: AppColors.income)
                    : null,
                onTap: () => Navigator.pop(ctx, thu),
              ),
          ],
        ),
      ),
    );
    if (chon == null) return;
    await _ghi(_prefs.copyWith(thuTongKet: chon));
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
                            // Hiển thị SỰ THẬT, không phải chỉ ý muốn: quyền
                            // bị thu hồi thì công tắc phải tắt. Nhưng
                            // `_prefs.osBat` được GIỮ NGUYÊN trong kho — cấp
                            // lại quyền trong Cài đặt máy là thông báo chạy
                            // lại ngay, không bắt người dùng vào đây gạt lại.
                            giaTri: _prefs.osBat && _coQuyenOs,
                            onChanged: _doiCongTacOs,
                          ),
                          const Divider(
                              height: 1, color: AppColors.outlineVariant),
                          _hangCongTac(
                            khoa: NotificationSettingsPage.khoaCongTacImLang,
                            icon: Icons.bedtime_outlined,
                            nhan: 'Giờ im lặng',
                            phu: 'Trong khoảng này thông báo vẫn được lưu, '
                                'chỉ không hiện ra ngoài.',
                            giaTri: _prefs.imLangBat,
                            onChanged: (v) =>
                                _ghi(_prefs.copyWith(imLangBat: v)),
                          ),
                          // Hai mốc giờ chỉ hiện khi công tắc bật: chúng không
                          // có ý nghĩa gì khi tính năng còn tắt, và mời người
                          // dùng chỉnh một thứ không tác dụng là cách nhanh
                          // nhất để họ mất tin vào trang cài đặt.
                          if (_prefs.imLangBat) ...[
                            const Divider(
                                height: 1, color: AppColors.outlineVariant),
                            _hangGioImLang(
                              nhan: 'Từ',
                              phut: _prefs.imLangTuPhut,
                              onChon: (p) =>
                                  _ghi(_prefs.copyWith(imLangTuPhut: p)),
                            ),
                            const Divider(
                                height: 1, color: AppColors.outlineVariant),
                            _hangGioImLang(
                              nhan: 'Đến',
                              phut: _prefs.imLangDenPhut,
                              onChon: (p) =>
                                  _ghi(_prefs.copyWith(imLangDenPhut: p)),
                            ),
                          ],
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
                          // Bốn loại báo "tiền vừa rời ví" cố ý bỏ qua công
                          // tắc nhóm — xem `luonBao()`. Im lặng về ngoại lệ ấy
                          // là để người dùng gạt tắt rồi tin rằng mình đã tắt.
                          const _GhiChu(
                            'Báo khi app tự thanh toán hoá đơn hoặc tự trích '
                            'tiền mục tiêu luôn được bật.',
                          ),
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
                      const SizedBox(height: 24),
                      _the(
                        tieuDe: 'SỐ DƯ VÍ',
                        children: [_hangNguongSoDu()],
                      ),
                      const SizedBox(height: 24),
                      _the(
                        tieuDe: 'NHẮC GHI CHÉP',
                        children: [
                          _hangCongTac(
                            khoa:
                                NotificationSettingsPage.khoaCongTacGhiChep,
                            icon: Icons.edit_calendar_outlined,
                            nhan: 'Nhắc ghi chép hằng ngày',
                            phu: 'Nhắc vào cuối ngày nếu hôm đó bạn chưa ghi '
                                'giao dịch nào.',
                            giaTri: _prefs.nhacGhiChepBat,
                            onChanged: (v) =>
                                _ghi(_prefs.copyWith(nhacGhiChepBat: v)),
                          ),
                          // Giờ chỉ hiện khi công tắc bật, cùng lý lẽ với hai
                          // mốc giờ im lặng bên trên.
                          if (_prefs.nhacGhiChepBat) ...[
                            const Divider(
                                height: 1, color: AppColors.outlineVariant),
                            _hangBam(
                              khoa: NotificationSettingsPage.khoaGioGhiChep,
                              icon: Icons.schedule_outlined,
                              nhan: 'Giờ nhắc',
                              phu: 'Giờ im lặng không chặn lời nhắc này.',
                              trailing: Text(
                                _gioGhiChepHienThi,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              onTap: _chonGioGhiChep,
                            ),
                          ],
                          const _GhiChu(
                            'Lời nhắc này chỉ hiện ngoài màn hình, không lưu '
                            'vào trung tâm thông báo.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _the(
                        tieuDe: 'TỔNG KẾT TUẦN',
                        children: [
                          _hangCongTac(
                            khoa:
                                NotificationSettingsPage.khoaCongTacTongKet,
                            icon: Icons.calendar_view_week_outlined,
                            nhan: 'Tổng kết tuần',
                            phu: 'Mỗi tuần một lời mời nhìn lại bạn đã tiêu '
                                'vào đâu.',
                            giaTri: _prefs.tongKetTuanBat,
                            onChanged: (v) =>
                                _ghi(_prefs.copyWith(tongKetTuanBat: v)),
                          ),
                          // Thứ và giờ chỉ hiện khi công tắc bật, cùng lý lẽ
                          // với lời nhắc ghi chép bên trên.
                          if (_prefs.tongKetTuanBat) ...[
                            const Divider(
                                height: 1, color: AppColors.outlineVariant),
                            _hangBam(
                              khoa: NotificationSettingsPage.khoaThuTongKet,
                              icon: Icons.event_outlined,
                              nhan: 'Ngày trong tuần',
                              phu: 'Tổng kết nói về tuần vừa khép lại.',
                              trailing: Text(
                                _tenThu(_prefs.thuTongKet),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              onTap: _chonThuTongKet,
                            ),
                            const Divider(
                                height: 1, color: AppColors.outlineVariant),
                            _hangBam(
                              khoa: NotificationSettingsPage.khoaGioTongKet,
                              icon: Icons.schedule_outlined,
                              nhan: 'Giờ nhắc',
                              phu: 'Giờ im lặng không chặn lời nhắc này.',
                              trailing: Text(
                                _gioTongKetHienThi,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              onTap: _chonGioTongKet,
                            ),
                          ],
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

  String get _gioTongKetHienThi =>
      '${_prefs.gioTongKet.toString().padLeft(2, '0')}:'
      '${_prefs.phutTongKet.toString().padLeft(2, '0')}';

  String get _gioGhiChepHienThi =>
      '${_prefs.gioNhacGhiChep.toString().padLeft(2, '0')}:'
      '${_prefs.phutNhacGhiChep.toString().padLeft(2, '0')}';

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
    Key? khoa,
  }) {
    return InkWell(
      key: khoa,
      onTap: onTap,
      child: _khung(icon: icon, nhan: nhan, phu: phu, trailing: trailing),
    );
  }

  /// Một mốc của khoảng im lặng. Lưu bằng **số phút từ nửa đêm**, nên phải quy
  /// đổi cả hai chiều ngay tại đây — chỗ duy nhất biết cả hai đơn vị.
  Widget _hangGioImLang({
    required String nhan,
    required int phut,
    required ValueChanged<int> onChon,
  }) {
    final gio = TimeOfDay(hour: phut ~/ 60, minute: phut % 60);

    return _hangBam(
      icon: Icons.nightlight_outlined,
      nhan: nhan,
      phu: nhan == 'Từ' ? 'Bắt đầu im lặng.' : 'Kết thúc im lặng.',
      trailing: Text(
        '${gio.hour.toString().padLeft(2, '0')}:'
        '${gio.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
      onTap: () async {
        final chon = await showTimePicker(context: context, initialTime: gio);
        if (chon == null) return;
        onChon(chon.hour * 60 + chon.minute);
      },
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

  Widget _hangNguongSoDu() {
    // Danh sách rời chứ không phải ô nhập tiền, cùng lý lẽ với `_hangSoNgay`:
    // gõ tay mở đường cho những giá trị mà `NotificationPrefs` sẽ lặng lẽ quy
    // về 0, và người dùng chỉ thấy con số của mình biến mất.
    const luaChon = [0, 50000, 100000, 200000, 500000, 1000000, 2000000];

    return _khung(
      icon: Icons.account_balance_wallet_outlined,
      nhan: 'Cảnh báo số dư thấp',
      phu: 'Báo khi một ví còn dưới mức này. Ví nợ không tính.',
      trailing: DropdownButton<int>(
        key: NotificationSettingsPage.khoaNguongSoDu,
        // Giá trị lạ — do sửa tay hoặc do một bản sau đổi danh sách — rơi về
        // `null` kèm `hint`, chứ không được ném giữa `build`.
        value: luaChon.contains(_prefs.nguongSoDuThap)
            ? _prefs.nguongSoDuThap
            : null,
        hint: Text(CurrencyFormatter.format(_prefs.nguongSoDuThap)),
        underline: const SizedBox.shrink(),
        items: [
          for (final n in luaChon)
            DropdownMenuItem(
              value: n,
              // `0` phải đọc thành "Tắt", không phải "0 đ": một ngưỡng bằng
              // không đọc như "báo khi ví hết sạch", trong khi nó tắt hẳn
              // tính năng.
              child: Text(n == 0 ? 'Tắt' : CurrencyFormatter.format(n)),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          _ghi(_prefs.copyWith(nguongSoDuThap: v));
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
    case NotificationGroup.summary:
      return 'Tổng kết';
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
      return 'Đồng bộ hỏng và cảnh báo số dư ví.';
    case NotificationGroup.summary:
      return 'Nhìn lại tuần vừa qua.';
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
    case NotificationGroup.summary:
      return Icons.calendar_view_week_outlined;
  }
}

/// Dòng chú thích cuối thẻ. Chữ nhỏ, màu phụ — nó giải thích một ngoại lệ chứ
/// không phải một hàng điều khiển.
class _GhiChu extends StatelessWidget {
  const _GhiChu(this.noiDung);

  final String noiDung;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Text(
        noiDung,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
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

/// Tên thứ trong tuần theo quy ước `DateTime.weekday` (1 = thứ Hai).
String _tenThu(int thu) => switch (thu) {
      DateTime.tuesday => 'Thứ Ba',
      DateTime.wednesday => 'Thứ Tư',
      DateTime.thursday => 'Thứ Năm',
      DateTime.friday => 'Thứ Sáu',
      DateTime.saturday => 'Thứ Bảy',
      DateTime.sunday => 'Chủ nhật',
      // Thứ Hai là mặc định, và cũng là chỗ rơi cho giá trị lạ — `fromJson` đã
      // kẹp về dải 1–7 nên nhánh này chỉ còn là lưới cuối.
      _ => 'Thứ Hai',
    };
