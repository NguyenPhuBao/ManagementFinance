import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../data/de_xuat_thong_bao_nguon.dart';
import '../../domain/hoc_gio_thong_bao.dart';
import '../../data/datasources/kenh_bien_dong.dart';
import '../../data/datasources/kenh_phien_ngan_hang.dart';
import '../../data/moc_phien_store.dart';
import '../../data/datasources/os_notifier.dart';
import '../../domain/notification_prefs.dart';
import '../../data/notification_prefs_store.dart';
import '../../application/reminder_scheduler.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../transaction/domain/doc_tin_bien_dong.dart';
import 'dong_y_bien_dong_page.dart';
import 'dong_y_nhac_sau_ngan_hang_page.dart';
import '../../../../core/ui/thong_bao_nhanh.dart';
import '../../../premium/domain/quyen_tinh_nang.dart';
import '../../../premium/presentation/bloc/co_quyen.dart';
import '../../../premium/presentation/widgets/the_khoa_quyen.dart';
import '../widgets/cai_dat_thong_bao/dong_goi_y.dart';
import '../widgets/cai_dat_thong_bao/hang_nguong.dart';
import '../widgets/cai_dat_thong_bao/khung_cai_dat.dart';
import '../widgets/cai_dat_thong_bao/khoi_nhac_sau_ngan_hang.dart';
import '../widgets/cai_dat_thong_bao/ten_nhom_thong_bao.dart';
import '../widgets/cai_dat_thong_bao/the_bien_dong.dart';

export '../widgets/cai_dat_thong_bao/the_bien_dong.dart' show kTieuDeTreNen, kTieuDeTreNenNhac, kMoTaTreNen;

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
    this.kenhPhienNganHang,
    this.mocPhien,
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

  /// Kênh tới tầng Kotlin của nhắc ghi sau khi dùng app ngân hàng. Mặc định `sl<KenhPhienNganHang>()`; tiêm được cho
  /// test.
  final KenhPhienNganHang? kenhPhienNganHang;

  /// Mốc đã xét theo tài khoản của nhắc ghi. Mặc định `sl<MocPhienStore>()`.
  final MocPhienStore? mocPhien;

  static const Key khoaCongTacOs = Key('notification_settings_os');

  /// Công tắc *Nhắc ghi sau khi dùng app ngân hàng* (khối dưới D1 trong thẻ *Tự động hoá giao dịch*).
  static const Key khoaCongTacNhacSauNganHang = Key('notification_settings_nhac_sau_ngan_hang');

  /// Nút "Mở Cài đặt" của dòng quyền *Truy cập dữ liệu sử dụng* — khác nút của D1 (*Truy cập thông báo*).
  static const Key khoaMoCaiDatSuDung = Key('notification_settings_mo_cai_dat_su_dung');

  /// Nút "Mở cài đặt" của hàng gợi ý pin trong thẻ D1.
  static const Key khoaMoCaiDatPin = Key('notification_settings_mo_cai_dat_pin');

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

  /// Máy có cho FlowMoney chạy nền không (miễn tối ưu pin). Đã cho thì ẩn hàng gợi ý pin — nói "có thể trễ" khi
  /// không trễ là nói sai. Đọc lại cùng lúc với quyền, mỗi lần quay về từ Cài đặt.
  bool _duocChayNen = true;

  /// Nhắc ghi sau khi dùng app ngân hàng: quyền *Truy cập dữ liệu sử dụng* — sự thật của máy, tách khỏi cờ
  /// `nhacSauNganHang` (ý muốn). Đọc lại cùng lúc với quyền D1.
  bool _coQuyenPhien = false;

  NotificationPrefsStore get _store =>
      widget.store ?? sl<NotificationPrefsStore>();

  OsNotifier get _os => widget.osNotifier ?? sl<OsNotifier>();

  KenhBienDong get _kenh =>
      widget.kenhBienDong ??
      (sl.isRegistered<KenhBienDong>()
          ? sl<KenhBienDong>()
          : const KenhBienDongTrong());

  KenhPhienNganHang get _kenhPhien =>
      widget.kenhPhienNganHang ??
      (sl.isRegistered<KenhPhienNganHang>() ? sl<KenhPhienNganHang>() : const KenhPhienNganHangTrong());

  MocPhienStore get _mocPhien =>
      widget.mocPhien ?? (sl.isRegistered<MocPhienStore>() ? sl<MocPhienStore>() : _mocTam);
  final MocPhienStore _mocTam = InMemoryMocPhienStore();

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
    final chayNen = await _kenh.duocChayNen();
    final coPhien = await _kenhPhien.coQuyen();
    if (mounted) {
      setState(() {
        _coQuyenBienDong = co;
        _duocChayNen = chayNen;
        _coQuyenPhien = coPhien;
      });
    }
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
    final duocChayNen = await _kenh.duocChayNen();
    final coQuyenPhien = await _kenhPhien.coQuyen();

    if (!mounted) return;
    setState(() {
      _idaccount = id;
      _prefs = p;
      _coQuyenOs = coQuyen;
      _coQuyenBienDong = coQuyenBienDong;
      _duocChayNen = duocChayNen;
      _coQuyenPhien = coQuyenPhien;
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
    final thu = d.thu == null ? null : tenThuThuongThongBao(d.thu!);
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
    return DongGoiY(
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
      baoNhanh('Hệ điều hành đang chặn thông báo của FlowMoney. '
            'Bật lại trong Cài đặt của máy.');
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

  /// Công tắc *Nhắc ghi sau khi dùng app ngân hàng* (spec 2026-10-03 §3.1) — khuôn [_doiBienDong]: bật lần đầu phải qua
  /// màn đồng ý; *Không, cảm ơn* / Back → không bật gì. MỖI lần bật đặt mốc đã xét = bây giờ: phiên trước lúc bật (kể
  /// cả lúc đang tắt) không bao giờ được nhắc.
  Future<void> _doiNhacSauNganHang(bool bat) async {
    final id = _idaccount;
    if (id == null) return;
    if (!bat) {
      await _ghi(_prefs.copyWith(nhacSauNganHang: false));
      await _kenhPhien.datBat(false);
      return;
    }
    var vuaDongY = false;
    if (!_prefs.dongYNhacSauNganHang) {
      final dongY = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const DongYNhacSauNganHangPage()),
      );
      if (dongY != true || !mounted) return;
      await _ghi(_prefs.copyWith(nhacSauNganHang: true, dongYNhacSauNganHang: true));
      vuaDongY = true;
    } else {
      await _ghi(_prefs.copyWith(nhacSauNganHang: true));
    }
    final bayGio = DateTime.now();
    await _mocPhien.ghi(id, bayGio);
    await _kenhPhien.datBat(true, daXetDen: bayGio);
    // "Đồng ý và mở Cài đặt": app không tự cấp được quyền. Máy đã có quyền thì mở Cài đặt là một bước thừa.
    if (vuaDongY && !await _kenhPhien.coQuyen()) await _kenhPhien.moCaiDat();
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
                  title: Text(tenThuThongBao(thu)),
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
              ? const ChuaDangNhapCaiDat()
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TheCaiDat(
                        tieuDe: 'THÔNG BÁO TRÊN MÁY',
                        children: [
                          HangCongTac(
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
                          HangCongTac(
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
                            HangGioImLang(
                              nhan: 'Từ',
                              phut: _prefs.imLangTuPhut,
                              onChon: (p) =>
                                  _ghi(_prefs.copyWith(imLangTuPhut: p)),
                            ),
                            const Divider(
                                height: 1, color: AppColors.outlineVariant),
                            HangGioImLang(
                              nhan: 'Đến',
                              phut: _prefs.imLangDenPhut,
                              onChon: (p) =>
                                  _ghi(_prefs.copyWith(imLangDenPhut: p)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      TheCaiDat(
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
                              HangCongTac(
                                khoa: NotificationSettingsPage.khoaCongTacNhom(
                                    nhom),
                                icon: iconNhomThongBao(nhom),
                                nhan: tenNhomThongBao(nhom),
                                phu: moTaNhomThongBao(nhom),
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
                          const GhiChuCaiDat(
                            'Báo khi app tự thanh toán hoá đơn hoặc tự trích '
                            'tiền mục tiêu luôn được bật.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TheBienDong(
                        prefs: _prefs,
                        coQuyenBienDong: _coQuyenBienDong,
                        duocChayNen: _duocChayNen,
                        onDoiBienDong: _doiBienDong,
                        khoaCongTac: NotificationSettingsPage.khoaCongTacNhom(NotificationGroup.bienDong),
                        dongQuyen: _dongQuyenBienDong(),
                        dongTreNen: DongTreNen(
                          moCaiDatPin: _kenh.moCaiDatPin,
                          khoaMoCaiDatPin: NotificationSettingsPage.khoaMoCaiDatPin,
                        ),
                        khoiNhacSau: KhoiNhacSauNganHang(
                          prefs: _prefs,
                          coQuyenBienDong: _coQuyenBienDong,
                          coQuyenPhien: _coQuyenPhien,
                          duocChayNen: _duocChayNen,
                          onDoi: _doiNhacSauNganHang,
                          khoaCongTac: NotificationSettingsPage.khoaCongTacNhacSauNganHang,
                          dongQuyen: _dongQuyenPhien(),
                          dongTreNen: DongTreNen(
                            tieuDe: kTieuDeTreNenNhac,
                            moCaiDatPin: _kenh.moCaiDatPin,
                            khoaMoCaiDatPin: NotificationSettingsPage.khoaMoCaiDatPin,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TheCaiDat(
                        tieuDe: 'NHẮC HOÁ ĐƠN',
                        children: [
                          HangBam(
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
                          HangSoNgay(prefs: _prefs, onGhi: _ghi),
                        ],
                      ),
                      const SizedBox(height: 24),
                      TheCaiDat(
                        tieuDe: 'SỐ DƯ VÍ',
                        children: [HangNguongSoDu(prefs: _prefs, onGhi: _ghi, khoa: NotificationSettingsPage.khoaNguongSoDu)],
                      ),
                      const SizedBox(height: 24),
                      TheCaiDat(
                        tieuDe: 'KHOẢN CHI LỚN',
                        children: [HangNguongChiLon(prefs: _prefs, onGhi: _ghi, khoa: NotificationSettingsPage.khoaNguongChiLon)],
                      ),
                      const SizedBox(height: 24),
                      TheCaiDat(
                        tieuDe: 'NHẮC GHI CHÉP',
                        children: [
                          HangCongTac(
                            khoa: NotificationSettingsPage.khoaCongTacGhiChep,
                            icon: Icons.edit_calendar_outlined,
                            nhan: 'Nhắc ghi chép hằng ngày',
                            phu: 'Nhắc vào cuối ngày nếu hôm đó bạn chưa ghi '
                                'giao dịch nào.',
                            giaTri: _prefs.nhacGhiChepBat,
                            // Quyền `daily_recording_reminder` (B1): khoá, GIỮ giá trị; lịch do ReminderScheduler tự huỷ.
                            onChanged: (v) => _ghi(_prefs.copyWith(nhacGhiChepBat: v)),
                            biKhoa: !context.coQuyen(MaQuyen.dailyRecordingReminder),
                          ),
                          if (!context.coQuyen(MaQuyen.dailyRecordingReminder))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: DongKhoaCongTac(
                                  ma: MaQuyen.dailyRecordingReminder, dangBat: _prefs.nhacGhiChepBat),
                            ),
                          // Giờ chỉ hiện khi công tắc bật, cùng lý lẽ với hai
                          // mốc giờ im lặng bên trên.
                          if (_prefs.nhacGhiChepBat) ...[
                            const Divider(
                                height: 1, color: AppColors.outlineVariant),
                            HangBam(
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
                          const GhiChuCaiDat(
                            'Lời nhắc này chỉ hiện ngoài màn hình, không lưu '
                            'vào trung tâm thông báo.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TheCaiDat(
                        tieuDe: 'TỔNG KẾT TUẦN',
                        children: [
                          HangCongTac(
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
                            HangBam(
                              khoa: NotificationSettingsPage.khoaThuTongKet,
                              icon: Icons.event_outlined,
                              nhan: 'Ngày trong tuần',
                              phu: 'Tổng kết nói về tuần vừa khép lại.',
                              trailing: Text(
                                tenThuThongBao(_prefs.thuTongKet),
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
                            HangBam(
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

  /// Hai biến thể của Stitch: *Chưa cấp quyền — Mở Cài đặt* và *Đã cấp quyền — đang đọc N
  /// nguồn*. N và tên nguồn suy từ [nguonDangDoc] (người dùng chốt: không hứa nguồn chưa đo).
  Widget _dongQuyenBienDong() => DongQuyen(
        co: _coQuyenBienDong,
        chuCo: 'Đã cấp quyền — đang đọc ${nguonDangDoc.length} nguồn',
        chuChua: 'Chưa cấp quyền truy cập thông báo',
        moCaiDat: _kenh.moCaiDat,
      );

  /// Dòng quyền *Truy cập dữ liệu sử dụng* của nhắc ghi — cùng bố cục với D1, nút mở ĐÚNG trang của nó.
  Widget _dongQuyenPhien() => DongQuyen(
        co: _coQuyenPhien,
        chuCo: 'Đã cấp quyền — đang theo dõi ${nguonDangDoc.length} app',
        chuChua: 'Chưa cấp quyền truy cập dữ liệu sử dụng',
        moCaiDat: _kenhPhien.moCaiDat,
        khoaNut: NotificationSettingsPage.khoaMoCaiDatSuDung,
      );
}
