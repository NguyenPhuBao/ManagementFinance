/// Tool `danh_sach_muc_tieu` — mục tiêu đang theo đuổi theo TÊN, đủ số kèm
/// NHỊP (spec bước 2 mục 3.6). Không tính gì: thứ tự từ `chiaMucTieu` (thứ tự
/// trang Mục tiêu), số từ `GoalEntity` và `goal_forecast.dart`.
///
/// ⚠️ KHÁC `GoiSoMucTieu` có chủ ý: khối Nhận xét chỉ in "cần thêm N ngày" khi
/// chậm (lúc đúng kế hoạch nó là tiếng ồn); tool trả lời câu hỏi THẲNG "bao giờ
/// đạt", nên luôn mang số ấy khi tính được. Số `null` là *chưa đủ căn cứ* và
/// bị bỏ hẳn — `?? 0` là bịa một lời hứa.
///
/// [chon] (cổng E lần 1, E11 — mục 9.32): lọc theo trạng thái — `cham_ke_hoach` ·
/// `qua_han` · `dung_ke_hoach`. Hỏi *"mục tiêu nào chậm"* khi cả hai đều đúng kế
/// hoạch thì mô hình vẫn chỉ một tên (số thật nên lọt chắn); nay phép lọc về hàm
/// domain, 0 khớp là `rongTheoBoLoc` → mẫu câu *"không có mục tiêu nào khớp"*.
///
/// **Trích tự động** (lát 3 Task 10, spec mở rộng tool §5.2): hàng của mục tiêu
/// bật trích mang *Kỳ trích tiếp* (`kyKeTiep`) và *Trích mỗi <kỳ>*; với [viNguon]
/// thì kết luận ĐÚNG như `GoalAutoDepositRunner`: ví nguồn không còn / đã lưu trữ
/// / trùng ví tích luỹ → bộ trích **không chạy** (không hứa kỳ tiếp); còn lại hỏi
/// `quyetDinhTrich` — kẹp ở phần còn thiếu, nên so số dư với số CÀI là sai.
/// ⚠️ Khác spec: *"ví không đủ để trích"* là HẬU TỐ của trạng thái (như
/// *" · tự trả"* của hoá đơn), không thay trạng thái — mục tiêu vừa chậm vừa
/// thiếu tiền phải khớp cả `chon=cham_ke_hoach` lẫn `chon=vi_khong_du`.
///
/// Vòng sửa cổng F (mục 9.36): **G1** [noiTrich] `false` (câu hỏi không nói về
/// trích — `cauHoiVeTrich`) → không một chữ trích nào; **G4** [ten] — mục tiêu
/// câu hỏi nêu (`tenNeuTrongCau`) → chỉ mục tiêu ấy, và hỏi trích của mục tiêu
/// không bật trích thì kết luận *"<tên> không bật trích tự động"*.
library;

import '../../goal/data/models/goal_entity.dart';
import '../../goal/domain/goal_auto_deposit.dart';
import '../../goal/domain/goal_forecast.dart';
import '../../goal/domain/goal_grouping.dart';
import '../../goal/domain/goal_stats.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

/// Mã `chon` của tool mục tiêu — trạng thái, không phải tỉ lệ như ngân sách.
/// `vi_khong_du` là CỜ trích tự động, không phải mã trạng thái (xem đầu tệp).
const List<String> kChonMucTieu = [
  'cham_ke_hoach',
  'qua_han',
  'dung_ke_hoach',
  'vi_khong_du',
];

/// Chữ trạng thái — cũng là `trangThai` của hàng (ba mã đầu), một định nghĩa.
const Map<String, String> kChuChonMucTieu = {
  'cham_ke_hoach': 'chậm kế hoạch',
  'qua_han': 'đã quá hạn',
  'dung_ke_hoach': 'đúng kế hoạch',
  'vi_khong_du': 'ví không đủ để trích',
};

/// Nhóm số theo CÂU HỎI (H1 cổng F lần 2): hàng chỉ mang số của câu đang hỏi và
/// lượt là `chiMauCau`. Realme 2026-09-28: hàng đủ mười số thì mô hình đáp B1
/// *"khi nào đạt"* bằng *"Bạn có thể đặt mục tiêu MuaXe khi…"* — không số nào
/// sai nên sáu lớp chắn im. Mã do `nhomMucTieuTheoCauHoi` đọc từ câu hỏi.
const String kNhomMucTieuKhiNao = 'khi_nao';
const String kNhomMucTieuMoiKy = 'moi_ky';

/// Ví nguồn của trích tự động — ví CÒN SỐNG (chưa xoá mềm); [trangThai] là khoá
/// `WalletStatus` thô, để `viNguonChoTrich` tự đọc như bộ trích.
typedef ViNguon = ({String ten, double soDu, String trangThai});

enum _Trich { du, khongDu, khongChay }

ViNguon? _viNguonCua(GoalEntity g, Map<String, ViNguon>? viNguon) =>
    g.autoDepositEnabled && viNguon != null ? viNguon[g.autoDepositWalletId] : null;

/// Tình trạng trích của [g]; `null` khi không bật trích hoặc không biết ví.
_Trich? _trichCua(GoalEntity g, Map<String, ViNguon>? viNguon) {
  if (!g.autoDepositEnabled || viNguon == null) return null;
  final vi = viNguon[g.autoDepositWalletId];
  // Ba ca `khongChayDuoc` của bộ trích — cùng một hàm với bộ trích và dự báo.
  if (!viNguonChoTrich(g,
      viNguonConSong: vi != null, trangThaiViNguon: vi?.trangThai)) {
    return _Trich.khongChay;
  }
  final qd = quyetDinhTrich(
    soTienCai: g.autoDepositAmount!,
    conThieu: g.remainingAmount,
    soDuViNguon: vi!.soDu,
  );
  return qd.loai == LoaiTrich.viKhongDu ? _Trich.khongDu : _Trich.du;
}

KetQuaCongCu hangMucTieu(
  List<GoalEntity> goals, {
  required DateTime now,
  String? chon,
  Map<String, ViNguon>? viNguon,
  bool noiTrich = true,
  String? ten,
  String? nhomSo,
}) {
  if (chon != null && !kChonMucTieu.contains(chon)) {
    return tuChoiGiaTri('chon', chon, kChonMucTieu);
  }
  // G1 cổng F: câu hỏi không nói về trích → không một chữ trích nào — như thể
  // không biết ví nguồn, và không in lịch trích. `vi_khong_du` là câu về trích.
  final hienTrich = noiTrich || chon == 'vi_khong_du';
  final vn = hienTrich ? viNguon : null;
  final nhom = chiaMucTieu(goals);
  // G4 cổng F (F14): câu nêu tên một mục tiêu → chỉ mục tiêu ấy (kể cả đã xong),
  // và mọi phép đếm / kết luận trích cũng chỉ trên nó — hàng MuaXe đứng cạnh
  // từng cho mô hình gán kỳ trích của MuaXe cho MuaDT.
  final phamVi = ten == null
      ? nhom.dangTheoDuoi
      : [for (final g in [...nhom.dangTheoDuoi, ...nhom.daHoanThanh]) if (g.name == ten) g];
  bool khopChon(GoalEntity g) => chon == 'vi_khong_du'
      ? _trichCua(g, vn) == _Trich.khongDu
      : _maTrangThai(g, now) == chon;
  final khop = chon == null ? phamVi : [for (final g in phamVi) if (khopChon(g)) g];

  // Đếm và kết luận trích chỉ khi câu hỏi chung hoặc hỏi đúng về trích — hỏi
  // "mục tiêu nào chậm" mà mẫu câu nói chuyện ví là tiếng ồn.
  final trich = [
    for (final g in phamVi)
      if (_trichCua(g, vn) case final t?) t,
  ];
  final ketLuanTrich = trich.isNotEmpty && (chon == null || chon == 'vi_khong_du');
  final khongDu = trich.where((t) => t == _Trich.khongDu).length;
  final ketQua = khongDu > 0
      ? 'có ví nguồn không đủ tiền để trích'
      : trich.contains(_Trich.khongChay)
          ? 'có trích tự động không chạy được'
          : 'ví nguồn đủ tiền cho kỳ trích tới';
  // Hỏi về trích của một mục tiêu KHÔNG bật trích: nói thẳng, đừng để mẫu câu
  // kể đủ số mà không trả lời (F14 lần 1: ◐).
  final khongBatTrich = hienTrich &&
      noiTrich &&
      ten != null &&
      phamVi.isNotEmpty &&
      phamVi.every((g) => !g.autoDepositEnabled);

  return KetQuaCongCu(
    hang: [
      for (final g in khop.take(kToiDaMucMoiGoi))
        _hang(g, now, vn, hienTrich: hienTrich, nhomSo: nhomSo),
    ],
    tongHop: [
      soDem('Đang theo đuổi', nhom.dangTheoDuoi.length),
      soDem('Đã hoàn thành', nhom.daHoanThanh.length),
      if (chon != null) soDem('Số mục tiêu khớp', khop.length),
      // Nhãn KHÔNG mở đầu bằng "Ví": `kiemTen` đọc chữ sau "ví" là tên ví, và
      // "Ví thiếu để trích: 1" của kế hoạch làm chính mẫu câu bị chặn.
      if (ketLuanTrich) soDem('Không đủ tiền trích', khongDu),
    ],
    chuThem: {
      if (ketLuanTrich) 'ket_qua': ketQua,
      if (khongBatTrich) 'ket_qua': '$ten không bật trích tự động',
    },
    tenLienQuan: [
      for (final g in phamVi)
        if (_viNguonCua(g, vn) case final vi?) vi.ten,
    ],
    boLoc: [if (chon != null) kChuChonMucTieu[chon]!],
    rongTheoBoLoc: chon != null && khop.isEmpty,
    doiTuongRong: 'mục tiêu',
    // Câu trả lời nằm ở MỘT số đích (nhóm) hay ở chữ kết luận (không bật trích):
    // mẫu câu nói đúng thứ ấy, chữ mô hình thì không đáng tin (B1, F14 lần 2).
    chiMauCau: khop.isNotEmpty && (nhomSo != null || khongBatTrich),
  );
}

/// Quá hạn thắng chậm — cùng thứ tự với `trangThai` của hàng.
String _maTrangThai(GoalEntity g, DateTime now) => g.daysLeft(now) < 0
    ? 'qua_han'
    : g.isBehindSchedule(now)
        ? 'cham_ke_hoach'
        : 'dung_ke_hoach';

HangSoLieu _hang(
  GoalEntity g,
  DateTime now,
  Map<String, ViNguon>? viNguon, {
  required bool hienTrich,
  String? nhomSo,
}) {
  final ten = g.name;
  final ngay = g.daysLeft(now);
  final quaHan = ngay < 0;
  final cham = g.isBehindSchedule(now);
  final ky = tenDonViKy(g.cycleTakeMoney);
  final duBao = duBaoHoanThanh(g, now);
  final canTich = tocDoKeHoach(g, now: now);
  final dangTich = tocDoThucTe(g, now);
  final trich = _trichCua(g, viNguon);
  final vi = _viNguonCua(g, viNguon);
  final kyTrich = hienTrich && g.autoDepositEnabled && trich != _Trich.khongChay
      ? kyKeTiep(
          mocNeo: g.timeCycleTakeMoney,
          lanChayGanNhat: g.autoDepositLastRun,
          chuKy: g.cycleTakeMoney,
          now: now,
        )
      : null;
  final hauTo = switch (trich) {
    _Trich.du => ' · trích từ ví ${vi!.ten}',
    _Trich.khongDu => ' · ví ${vi!.ten} không đủ để trích',
    _Trich.khongChay => ' · trích tự động không chạy được',
    null => '',
  };
  return HangSoLieu(
    ten: ten,
    trangThai: '${kChuChonMucTieu[_maTrangThai(g, now)]}$hauTo',
    canhBao: quaHan ||
        cham ||
        trich == _Trich.khongDu ||
        trich == _Trich.khongChay,
    soLieu: [
      if (nhomSo == null) ...[
        soPhanTram('Tiến độ', g.progress * 100, ten: ten),
        soTien('Đã tích', g.currentAmount, ten: ten),
        soTien('Mục tiêu', g.targetAmount, ten: ten),
      ],
      soTien('Còn thiếu', g.remainingAmount, ten: ten),
      // Quá hạn thì "còn -3 ngày" không ai đọc; trạng thái đã nói thay.
      if (!quaHan && nhomSo != kNhomMucTieuMoiKy) soNgay('Còn', ngay, ten: ten),
      if (duBao != null && nhomSo != kNhomMucTieuMoiKy)
        soNgay(
          'Theo nhịp hiện tại cần thêm',
          duBao.difference(now).inDays,
          ten: ten,
        ),
      if (canTich != null && nhomSo != kNhomMucTieuKhiNao)
        soTien('Cần tích mỗi $ky', canTich, ten: ten),
      if (dangTich != null && nhomSo != kNhomMucTieuKhiNao)
        soTien('Đang tích mỗi $ky', dangTich, ten: ten),
      if (kyTrich != null && nhomSo == null)
        soNgayThang('Kỳ trích tiếp', kyTrich, ten: ten, now: now),
      if (hienTrich && g.autoDepositEnabled && nhomSo == null)
        soTien('Trích mỗi $ky', g.autoDepositAmount!, ten: ten),
      if (trich == _Trich.khongDu && nhomSo == null)
        soTien('Số dư ví nguồn', vi!.soDu, ten: ten),
    ],
  );
}
