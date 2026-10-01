import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/notification/de_xuat_thong_bao_nguon.dart';
import '../../../../core/notification/hoc_gio_thong_bao.dart';
import '../../../../core/notification/kenh_bien_dong.dart';
import '../../../../core/notification/os/os_notifier.dart';
import '../../../../core/notification/prefs/notification_prefs.dart';
import '../../../../core/notification/prefs/notification_prefs_store.dart';
import '../../../../core/notification/reminder_scheduler.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/domain/doc_tin_bien_dong.dart';
import 'dong_y_bien_dong_page.dart';

/// Trang cài đặt thông báo — `/settings/notifications`.
///
/// Bố cục bám kiểu thẻ đang dùng ở `settings_page.dart` (thẻ trắng bo 12, tiêu
/// đề mục chữ hoa, mỗi hàng là icon + nhãn + control, ngăn nhau bằng
/// `Divider`) — trang dựng khi Stitch chưa vẽ màn này. Màn Stitch
/// `d42ce712…` (2026-09-30, D1) vẽ lại cả trang; bản thi công **chỉ** lấy từ
/// đó thẻ *Tự động hoá giao dịch* (công tắc Biến động số dư + dòng quyền), các
/// thẻ khác giữ bố cục cũ.
///
/// Trang **không có nút Lưu**: mỗi thay đổi ghi thẳng xuống kho. Trang cài đặt
/// kiểu này không ai đi tìm nút lưu — họ gạt công tắc rồi bấm quay lại.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.idaccount,
    this.store,
    this.osNotifier,
    this.datLaiLich,
    this.taiDeXuat,
    this.boQuaDeXuat,
    this.kenhBienDong,
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

  /// Đặt lại lịch đang chờ sau khi người dùng đổi một **mốc** (giờ nhắc hoá
  /// đơn, giờ nhắc ghi chép, giờ hay thứ tổng kết) — G59. Mặc định
  /// `ReminderScheduler.resync(id, datLai: true)`; tiêm được cho test.
  final Future<void> Function(int idaccount)? datLaiLich;

  /// Đề xuất giờ nhắc / tắt nhóm (B5b) — nạp MỘT lần lúc mở trang. Mặc định
  /// `DeXuatThongBaoNguon.tai`; tiêm được cho test.
  final Future<List<DeXuatThongBao>> Function(int idaccount)? taiDeXuat;

  /// *Bỏ qua* / *Giữ* một đề xuất — im 30 ngày. Mặc định
  /// `DeXuatThongBaoNguon.boQua`.
  final Future<void> Function(int idaccount, DeXuatThongBao d)? boQuaDeXuat;

  /// Kênh tới tầng Kotlin của D1 (đọc biến động số dư). Mặc định `sl<KenhBienDong>()`; tiêm được
  /// cho test.
  final KenhBienDong? kenhBienDong;

  static const Key khoaCongTacOs = Key('notification_settings_os');

  static const Key khoaCongTacImLang = Key('notification_settings_im_lang');

  static Key khoaCongTacNhom(NotificationGroup nhom) =>
      Key('notification_settings_${nhom.name}');

  static const Key khoaNguongSoDu = Key('notification_settings_nguong_so_du');

  static const Key khoaNguongChiLon =
      Key('notification_settings_nguong_chi_lon');

  static const Key khoaCongTacGhiChep = Key('notification_settings_ghi_chep');

  static const Key khoaGioGhiChep = Key('notification_settings_gio_ghi_chep');

  static const Key khoaCongTacTongKet = Key('notification_settings_tong_ket');
  static const Key khoaThuTongKet = Key('notification_settings_thu_tong_ket');
  static const Key khoaGioTongKet = Key('notification_settings_gio_tong_ket');

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
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

  /// Đề xuất B5b còn hiện. Áp dụng hay bỏ qua thì gỡ khỏi đây ngay — không
  /// nạp lại (đề xuất là ảnh chụp lúc mở trang).
  List<DeXuatThongBao> _deXuat = const [];

  /// D1: quyền *Truy cập thông báo* của Android — sự thật của máy, tách khỏi cờ
  /// `docBienDong` (ý muốn). Đọc lại mỗi lần app quay về từ nền: người dùng cấp quyền ở Cài đặt hệ
  /// thống rồi quay lại, dòng trạng thái phải đổi theo ngay.
  bool _coQuyenBienDong = false;

  NotificationPrefsStore get _store =>
      widget.store ?? sl<NotificationPrefsStore>();

  OsNotifier get _os => widget.osNotifier ?? sl<OsNotifier>();

  KenhBienDong get _kenh =>
      widget.kenhBienDong ??
      (sl.isRegistered<KenhBienDong>()
          ? sl<KenhBienDong>()
          : const KenhBienDongTrong());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _docQuyenBienDong();
  }

  Future<void> _docQuyenBienDong() async {
    final co = await _kenh.coQuyen();
    if (mounted) setState(() => _coQuyenBienDong = co);
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
    final deXuat = await _taiDeXuat(id);
    final coQuyenBienDong = await _kenh.coQuyen();

    if (!mounted) return;
    setState(() {
      _idaccount = id;
      _prefs = p;
      _coQuyenOs = coQuyen;
      _coQuyenBienDong = coQuyenBienDong;
      _deXuat = deXuat;
      _dangNap = false;
    });
  }

  /// Nuốt lỗi: đề xuất là phần phụ, một trục trặc không được làm vỡ trang.
  Future<List<DeXuatThongBao>> _taiDeXuat(int id) async {
    try {
      final tai = widget.taiDeXuat ??
          (sl.isRegistered<DeXuatThongBaoNguon>()
              ? sl<DeXuatThongBaoNguon>().tai
              : null);
      return tai == null ? const [] : await tai(id);
    } catch (e) {
      debugPrint('[CaiDatThongBao] nạp đề xuất hỏng: $e');
      return const [];
    }
  }

  DeXuatThongBao? _goiY(LoaiDeXuat loai, [NotificationGroup? nhom]) {
    for (final d in _deXuat) {
      if (d.loai == loai && d.nhom == nhom) return d;
    }
    return null;
  }

  void _goBo(DeXuatThongBao d) => setState(() => _deXuat = [
        for (final x in _deXuat)
          if (x != d) x
      ]);

  /// Áp dụng đi qua đường lưu DUY NHẤT của trang (`_ghi` / `_doiNhom`), nên đổi
  /// giờ kéo theo đặt lại lịch đang chờ (G59) như khi người dùng tự chọn.
  Future<void> _apDung(DeXuatThongBao d) async {
    _goBo(d);
    final g = d.gio;
    switch (d.loai) {
      case LoaiDeXuat.gioHoaDon:
        await _ghi(_prefs.copyWith(gioNhac: g!.gio, phutNhac: g.phut));
      case LoaiDeXuat.gioGhiChep:
        await _ghi(
            _prefs.copyWith(gioNhacGhiChep: g!.gio, phutNhacGhiChep: g.phut));
      case LoaiDeXuat.gioTongKet:
        await _ghi(_prefs.copyWith(
          thuTongKet: d.thu ?? _prefs.thuTongKet,
          gioTongKet: g?.gio ?? _prefs.gioTongKet,
          phutTongKet: g?.phut ?? _prefs.phutTongKet,
        ));
      case LoaiDeXuat.tatNhom:
        await _doiNhom(d.nhom!, false);
    }
  }

  Future<void> _boQua(DeXuatThongBao d) async {
    final id = _idaccount;
    _goBo(d);
    if (id == null) return;
    try {
      final boQua = widget.boQuaDeXuat ??
          (sl.isRegistered<DeXuatThongBaoNguon>()
              ? sl<DeXuatThongBaoNguon>().boQua
              : null);
      await boQua?.call(id, d);
    } catch (e) {
      debugPrint('[CaiDatThongBao] ghi bỏ qua hỏng: $e');
    }
  }

  /// Dòng gợi ý dưới một hàng — `null` khi không có đề xuất loại ấy.
  Widget? _dongGoiY(LoaiDeXuat loai, [NotificationGroup? nhom]) {
    final d = _goiY(loai, nhom);
    if (d == null) return null;
    String hhmm(({int gio, int phut}) g) =>
        '${g.gio.toString().padLeft(2, '0')}:${g.phut.toString().padLeft(2, '0')}';
    final g = d.gio;
    final thu = d.thu == null ? null : _tenThuThuong(d.thu!);
    final (cau, nhanApDung, nhanBoQua) = switch (loai) {
      LoaiDeXuat.gioHoaDon => (
          'Bạn hay mở nhắc hoá đơn lúc khoảng ${hhmm(g!)}.',
          'Đổi sang ${hhmm(g)}',
          'Bỏ qua',
        ),
      LoaiDeXuat.gioGhiChep => (
          'Bạn hay ghi giao dịch lúc khoảng ${hhmm(g!)}.',
          'Đổi sang ${hhmm(g)}',
          'Bỏ qua',
        ),
      LoaiDeXuat.gioTongKet => (
          g == null
              ? 'Bạn hay mở tổng kết tuần vào $thu.'
              : thu == null
                  ? 'Bạn hay mở tổng kết tuần lúc khoảng ${hhmm(g)}.'
                  : 'Bạn hay mở tổng kết tuần vào khoảng $thu ${hhmm(g)}.',
          'Đổi sang ${[
            if (thu != null) thu,
            if (g != null) hhmm(g)
          ].join(' ')}',
          'Bỏ qua',
        ),
      LoaiDeXuat.tatNhom => (
          '$kSoLienTiep thông báo gần nhất của nhóm này chưa được mở.',
          'Tắt nhóm',
          'Giữ',
        ),
    };
    return _DongGoiY(
      cau: cau,
      nhanApDung: nhanApDung,
      nhanBoQua: nhanBoQua,
      apDung: () => _apDung(d),
      boQua: () => _boQua(d),
    );
  }

  Future<void> _ghi(NotificationPrefs moi) async {
    final id = _idaccount;
    // `idaccount` CHỈ đến từ phiên đăng nhập — không có thì không ghi gì cả.
    // Mặc định về 1 là ghi tuỳ chọn vào hồ sơ tài khoản admin thật.
    if (id == null) return;

    final cu = _prefs;
    setState(() => _prefs = moi);
    await _store.write(id, moi);
    // G59: khoá lịch không chứa giờ, nên lượt quét thường giữ lịch đang chờ ở
    // mốc cũ. Chỉ đặt lại khi một MỐC đổi — gạt công tắc thì lượt quét thường
    // lo, luỹ đẳng. Nuốt lỗi: tuỳ chọn đã lưu, lượt quét sau vẫn còn.
    if (_doiMocLich(cu, moi)) {
      try {
        await (widget.datLaiLich ?? _datLaiMacDinh)(id);
      } catch (e) {
        debugPrint('[CaiDatThongBao] đặt lại lịch hỏng: $e');
      }
    }
  }

  static Future<void> _datLaiMacDinh(int id) async {
    if (!sl.isRegistered<ReminderScheduler>()) return;
    await sl<ReminderScheduler>().resync(id, datLai: true);
  }

  /// Bảy trường quyết định MỐC nổ của một lịch đặt trước.
  static bool _doiMocLich(NotificationPrefs a, NotificationPrefs b) =>
      a.gioNhac != b.gioNhac ||
      a.phutNhac != b.phutNhac ||
      a.gioNhacGhiChep != b.gioNhacGhiChep ||
      a.phutNhacGhiChep != b.phutNhacGhiChep ||
      a.thuTongKet != b.thuTongKet ||
      a.gioTongKet != b.gioTongKet ||
      a.phutTongKet != b.phutTongKet;

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
    // Biến động số dư (D1): cờ riêng, mặc định tắt — không đi qua tập nhóm tắt
    // (xem `NotificationPrefs.docBienDong`).
    if (nhom == NotificationGroup.bienDong) {
      await _doiBienDong(bat);
      return;
    }
    final tat = {..._prefs.nhomTat};
    if (bat) {
      tat.remove(nhom);
    } else {
      tat.add(nhom);
    }
    await _ghi(_prefs.copyWith(nhomTat: tat));
  }

  /// D1 Task 6 — công tắc *Biến động số dư*. Bật lần đầu phải qua màn xin đồng ý (backend bắt buộc,
  /// Nghị định 13): chỉ *Đồng ý* mới bật dịch vụ Kotlin (`datBat(true)`); *Không, cảm ơn* hay Back
  /// thì cờ vẫn tắt và không gì được bật. Đã đồng ý một lần thì bật lại không hỏi nữa. Tắt thì
  /// `datBat(false)` — quyền hệ thống app không tự thu hồi được, nên có dòng nhắc chỗ thu hồi.
  Future<void> _doiBienDong(bool bat) async {
    if (_idaccount == null) return;
    if (!bat) {
      await _ghi(_prefs.copyWith(docBienDong: false));
      await _kenh.datBat(false);
      return;
    }
    if (!_prefs.dongYBienDong) {
      final dongY = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const DongYBienDongPage()),
      );
      if (dongY != true || !mounted) return;
      await _ghi(_prefs.copyWith(docBienDong: true, dongYBienDong: true));
      await _kenh.datBat(true);
      // "Đồng ý và mở Cài đặt": app không tự cấp được quyền. Máy đã có quyền (tài khoản khác từng
      // bật) thì mở Cài đặt là một bước thừa.
      if (!await _kenh.coQuyen()) await _kenh.moCaiDat();
    } else {
      await _ghi(_prefs.copyWith(docBienDong: true));
      await _kenh.datBat(true);
    }
    await _docQuyenBienDong();
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
      initialTime: TimeOfDay(
          hour: _prefs.gioNhacGhiChep, minute: _prefs.phutNhacGhiChep),
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
  ///
  /// G60 (2026-09-29): bảy dòng cao ~392 dp mà bottom sheet mặc định chỉ được
  /// 9/16 màn — máy cao dưới ~700 dp tràn và *Chủ nhật* không chạm được.
  /// `isScrollControlled` cho bảng cao theo nội dung; thân vẫn cuộn được cho màn
  /// còn thấp hơn nữa (xoay ngang).
  Future<void> _chonThuTongKet() async {
    final chon = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
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
          tooltip: 'Quay lại',
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
                          // Biến động số dư có thẻ riêng bên dưới (Stitch `d42ce712…`): nó là
                          // công tắc TÍNH NĂNG đứng sau màn xin đồng ý, không phải một loại
                          // thông báo thường.
                          for (final nhom in NotificationGroup.values)
                            if (nhom != NotificationGroup.bienDong) ...[
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
                              if (_dongGoiY(LoaiDeXuat.tatNhom, nhom)
                                  case final w?)
                                w,
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
                      _theBienDong(),
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
                          if (_dongGoiY(LoaiDeXuat.gioHoaDon) case final w?) w,
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
                        tieuDe: 'KHOẢN CHI LỚN',
                        children: [_hangNguongChiLon()],
                      ),
                      const SizedBox(height: 24),
                      _the(
                        tieuDe: 'NHẮC GHI CHÉP',
                        children: [
                          _hangCongTac(
                            khoa: NotificationSettingsPage.khoaCongTacGhiChep,
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
                            if (_dongGoiY(LoaiDeXuat.gioGhiChep) case final w?)
                              w,
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
                            khoa: NotificationSettingsPage.khoaCongTacTongKet,
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
                            if (_dongGoiY(LoaiDeXuat.gioTongKet) case final w?)
                              w,
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  String get _gioHienThi => '${_prefs.gioNhac.toString().padLeft(2, '0')}:'
      '${_prefs.phutNhac.toString().padLeft(2, '0')}';

  String get _gioTongKetHienThi =>
      '${_prefs.gioTongKet.toString().padLeft(2, '0')}:'
      '${_prefs.phutTongKet.toString().padLeft(2, '0')}';

  String get _gioGhiChepHienThi =>
      '${_prefs.gioNhacGhiChep.toString().padLeft(2, '0')}:'
      '${_prefs.phutNhacGhiChep.toString().padLeft(2, '0')}';

  /// D1 — thẻ *Tự động hoá giao dịch* (Stitch `d42ce712…`): công tắc *Biến động số dư* và, khi
  /// bật, một dòng trạng thái quyền nói sự thật của máy. Công tắc giữ khoá
  /// `khoaCongTacNhom(bienDong)` như mọi nhóm.
  Widget _theBienDong() {
    final bat = _prefs.docBienDong;
    return _the(
      tieuDe: 'TỰ ĐỘNG HOÁ GIAO DỊCH',
      nhanMoi: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 18,
                                color: AppColors.onSecondaryContainer),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _tenNhom(NotificationGroup.bienDong),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _moTaNhom(NotificationGroup.bienDong),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    key: NotificationSettingsPage.khoaCongTacNhom(
                        NotificationGroup.bienDong),
                    value: bat,
                    onChanged: _doiBienDong,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF006E1C),
                  ),
                ],
              ),
              if (bat) ...[
                const SizedBox(height: 14),
                _dongQuyenBienDong(),
              ] else if (_coQuyenBienDong) ...[
                const SizedBox(height: 10),
                const Text(
                  kNhacThuHoiQuyen,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Hai biến thể của Stitch: *Chưa cấp quyền — Mở Cài đặt* và *Đã cấp quyền — đang đọc N
  /// nguồn*. N và tên nguồn suy từ [nguonDangDoc] (người dùng chốt: không hứa nguồn chưa đo).
  Widget _dongQuyenBienDong() {
    final co = _coQuyenBienDong;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: co
                  ? AppColors.secondaryContainer
                  : AppColors.warning.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              co ? Icons.check_circle : Icons.warning_rounded,
              size: 18,
              color: co ? AppColors.onSecondaryContainer : AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: co
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã cấp quyền — đang đọc ${nguonDangDoc.length} nguồn',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nguonDangDoc.join(', '),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  )
                : const Text(
                    'Chưa cấp quyền truy cập thông báo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          if (co)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle,
                      size: 6, color: AppColors.onSecondaryContainer),
                  SizedBox(width: 4),
                  Text(
                    'Hoạt động',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            )
          else
            // `TextButton` chứ không `ElevatedButton`: theme của app ép mọi ElevatedButton rộng vô
            // hạn (bẫy 4.11 `ANALYTICS_FEATURE.md`) — trong `Row` là trắng cả trang.
            TextButton(
              onPressed: _kenh.moCaiDat,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const StadiumBorder(),
              ),
              child: const Text('Mở Cài đặt',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _the({
    required String tieuDe,
    required List<Widget> children,
    bool nhanMoi = false,
  }) {
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
            child: Row(
              children: [
                Expanded(
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
                if (nhanMoi)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Mới',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
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

  /// Ngưỡng "khoản chi lớn" — bản sao có chủ ý của [_hangNguongSoDu].
  ///
  /// Danh sách rời chứ không phải ô nhập tiền, cùng lý lẽ: gõ tay mở đường cho
  /// những giá trị mà `NotificationPrefs` sẽ lặng lẽ kẹp về 0 hoặc về trần, và
  /// người dùng chỉ thấy con số của mình biến mất.
  ///
  /// Các mức bắt đầu từ 500.000 chứ không từ 50.000 như ngưỡng số dư: đây là
  /// ngưỡng của **một** khoản chi, và một mức quá thấp biến tính năng thành
  /// một thông báo cho gần như mọi giao dịch — đúng kiểu báo động giả làm
  /// người dùng tắt sạch thông báo rồi không bật lại.
  Widget _hangNguongChiLon() {
    const luaChon = [
      0,
      500000,
      1000000,
      2000000,
      5000000,
      10000000,
      20000000,
    ];

    return _khung(
      icon: Icons.trending_up_outlined,
      nhan: 'Cảnh báo khoản chi lớn',
      phu: 'Báo khi một khoản chi đạt tới mức này.',
      trailing: DropdownButton<int>(
        key: NotificationSettingsPage.khoaNguongChiLon,
        // Giá trị lạ rơi về `null` kèm `hint` thay vì ném giữa `build` — cùng
        // lý do với ô ngưỡng số dư.
        value:
            luaChon.contains(_prefs.nguongChiLon) ? _prefs.nguongChiLon : null,
        hint: Text(CurrencyFormatter.format(_prefs.nguongChiLon)),
        underline: const SizedBox.shrink(),
        items: [
          for (final n in luaChon)
            DropdownMenuItem(
              value: n,
              // `0` đọc thành "Tắt": một ngưỡng bằng không đọc như "báo mọi
              // khoản chi", trong khi nó tắt hẳn tính năng.
              child: Text(n == 0 ? 'Tắt' : CurrencyFormatter.format(n)),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          _ghi(_prefs.copyWith(nguongChiLon: v));
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
                  style:
                      const TextStyle(fontSize: 16, color: AppColors.primary),
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
    case NotificationGroup.bienDong:
      return 'Biến động số dư';
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
    case NotificationGroup.bienDong:
      return 'Đọc thông báo ngân hàng / ví điện tử trên máy để điền sẵn giao dịch.';
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
    case NotificationGroup.bienDong:
      return Icons.account_balance_outlined;
  }
}

/// Dòng chú thích cuối thẻ. Chữ nhỏ, màu phụ — nó giải thích một ngoại lệ chứ
/// không phải một hàng điều khiển.
/// Dòng gợi ý B5b — màn Stitch `065eccd8…`: chữ phụ xám 12 px thẳng lề với
/// chữ của hàng bên trên (20 + biểu tượng 24 + 16), rồi nút viền *áp dụng* và
/// nút chữ xám *bỏ qua*. Không hộp màu, không biểu tượng — không tranh với hàng
/// cài đặt. `Wrap` để nút dài (*Đổi sang chủ nhật 21:30*) xuống dòng ở 360 dp.
class _DongGoiY extends StatelessWidget {
  const _DongGoiY({
    required this.cau,
    required this.nhanApDung,
    required this.nhanBoQua,
    required this.apDung,
    required this.boQua,
  });

  final String cau;
  final String nhanApDung;
  final String nhanBoQua;
  final VoidCallback apDung;
  final VoidCallback boQua;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cau,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: apDung,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(nhanApDung, style: const TextStyle(fontSize: 13)),
              ),
              TextButton(
                onPressed: boQua,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(nhanBoQua, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tên thứ giữa câu: chữ thường ở đầu (*"thứ Bảy"*, *"chủ nhật"*).
String _tenThuThuong(int thu) {
  final t = _tenThu(thu);
  return t[0].toLowerCase() + t.substring(1);
}

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
