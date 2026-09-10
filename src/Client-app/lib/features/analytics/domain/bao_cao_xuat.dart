/// Tầng thuần của trang **Xuất báo cáo**: từ bộ lọc người dùng chọn ra một
/// [BaoCao] đầy đủ cho màn Xem trước.
///
/// Tách khỏi widget vì cùng lý do với `thong_ke_thang.dart`: trang này từng là
/// **số cứng** (ví "Techcombank" bịa, lịch sử xuất bịa), và lớp lỗi thay thế nó
/// hỏng **im lặng** — một khoản rơi khỏi khoảng vì biên đóng/mở, một khoản
/// chuyển ví bị đếm thành chi tiêu, một quý bị cắt còn hai tháng.
///
/// Mọi luật **đếm tiền** ở đây mượn nguyên `thong_ke_thang.dart` (biên
/// `[from, to)`, `'transfer'` không phải thu cũng không phải chi, cách gom và
/// sắp danh mục). Đừng viết lại biến thể khác: hai trang cùng nói về một tháng
/// mà ra hai con số là lỗi khó thấy nhất trong app này.
library;

import 'thong_ke_thang.dart';
import 'khoan_vao_thong_ke.dart';

export 'thong_ke_thang.dart' show TongThuChi, rutGon;

/// Phạm vi thời gian trên trang Xuất báo cáo — đúng bốn nút của màn Stitch.
enum PhamViThoiGian { thangNay, thangTruoc, quyNay, tuyChinh }

/// Biên `[from, to)` ứng với [pv].
///
/// [tuyChon] là khoảng người dùng chọn từ bộ chọn ngày, **cả hai đầu là ngày**
/// (00:00). Biên `to` trả về đã cộng thêm một ngày để ngày cuối cùng người dùng
/// chọn nằm TRONG báo cáo — lấy thẳng `tuyChon.to` là mất trọn ngày ấy.
///
/// [tuyChon] `null` khi người dùng bấm "Tuỳ chỉnh" rồi thoát bộ chọn; khi ấy
/// lùi về tháng này thay vì nổ.
({DateTime from, DateTime to}) khoangCuaPhamVi(
  PhamViThoiGian pv, {
  required DateTime now,
  ({DateTime from, DateTime to})? tuyChon,
}) {
  switch (pv) {
    case PhamViThoiGian.thangNay:
      return bienThang(now.year, now.month);
    case PhamViThoiGian.thangTruoc:
      // `month - 1` bằng 0 tự cuộn về tháng 12 năm trước nhờ `DateTime`.
      return bienThang(now.year, now.month - 1);
    case PhamViThoiGian.quyNay:
      final thangDauQuy = ((now.month - 1) ~/ 3) * 3 + 1;
      return (
        from: DateTime(now.year, thangDauQuy, 1),
        to: DateTime(now.year, thangDauQuy + 3, 1),
      );
    case PhamViThoiGian.tuyChinh:
      if (tuyChon == null) return bienThang(now.year, now.month);
      final t = tuyChon.to;
      return (
        from: DateTime(tuyChon.from.year, tuyChon.from.month, tuyChon.from.day),
        // `day + 1` tự cuộn qua cuối tháng, cuối năm và 29/02 năm nhuận.
        to: DateTime(t.year, t.month, t.day + 1),
      );
  }
}

/// Kỳ liền trước của `[from, to)`, để so sánh "so với kỳ trước".
///
/// Khoảng trùng khít một số **tháng dương lịch** thì lùi theo tháng, không phải
/// trừ số ngày: tháng 9 dài 30 ngày, trừ 30 ngày ra `02/08–01/09` — lệch một
/// ngày, và con số phần trăm sai mà không ai thấy. Khoảng tuỳ chỉnh thì lùi
/// đúng bằng độ dài của nó, kết thúc ngay lúc kỳ này bắt đầu.
({DateTime from, DateTime to}) khoangKyTruoc({
  required DateTime from,
  required DateTime to,
}) {
  final tronThang = from.day == 1 &&
      to.day == 1 &&
      from.hour == 0 &&
      to.hour == 0 &&
      from.minute == 0 &&
      to.minute == 0;
  if (tronThang) {
    final soThang =
        (to.year * 12 + to.month) - (from.year * 12 + from.month);
    if (soThang > 0) {
      // `month - soThang` bằng 0 hay âm tự cuộn về năm trước nhờ `DateTime`.
      return (from: DateTime(from.year, from.month - soThang, 1), to: from);
    }
  }
  return (from: from.subtract(to.difference(from)), to: from);
}

/// Số dư ví ở hai đầu của kỳ báo cáo.
///
/// **Chỉ tính được khi báo cáo gộp TẤT CẢ ví.** App không lưu lịch sử số dư,
/// nên hai con số này suy ngược từ số dư hiện tại; phép suy ấy chỉ khớp khi
/// khoản `transfer` triệt tiêu nhau, tức khi nhìn toàn bộ ví. Với một ví riêng,
/// chuyển ví có ảnh hưởng thật nhưng **chiều tiền không suy được** từ vị trí ví
/// (xem `TRANSACTION_NOTE_ENCODING.md` và mục 3.2 `GOAL_FEATURE.md`) — nên khi
/// lọc theo ví, [BaoCao.dongTien] là `null` chứ không phải một con số đoán.
class DongTien {
  final double dauKy;
  final double cuoiKy;

  const DongTien({required this.dauKy, required this.cuoiKy});

  /// Chênh lệch trong kỳ. Bằng đúng `thu − chi` — đây là phép cân của tờ báo
  /// cáo, lệch là người đọc bắt được ngay.
  double get thayDoi => cuoiKy - dauKy;
}

/// Vài con số người đọc báo cáo hỏi ngay, kiểu Money Lover / MISA.
class SoLieuNhanh {
  /// Tổng chi chia cho **số ngày của kỳ**, không phải số ngày có giao dịch.
  final double chiMoiNgay;

  /// Ngày cộng dồn chi nhiều nhất, và số tiền của ngày ấy. `null` khi kỳ không
  /// có khoản chi nào.
  final DateTime? ngayChiNhieuNhat;
  final double chiNgayNhieuNhat;

  final DongGiaoDich? khoanChiLonNhat;

  const SoLieuNhanh({
    required this.chiMoiNgay,
    required this.ngayChiNhieuNhat,
    required this.chiNgayNhieuNhat,
    required this.khoanChiLonNhat,
  });
}

/// Một ví trong bảng "Phân bổ theo ví".
class DongVi {
  final String walletId;
  final String ten;
  final double thu;
  final double chi;
  final int soGiaoDich;

  const DongVi({
    required this.walletId,
    required this.ten,
    required this.thu,
    required this.chi,
    required this.soGiaoDich,
  });
}

/// Một cột của biểu đồ thu/chi trong kỳ.
class DiemBaoCao {
  /// Mốc đầu của khoảng mà cột này gom.
  final DateTime moc;

  /// Nhãn trục hoành, đã dựng sẵn ở tầng thuần để widget không tự định dạng.
  final String nhan;

  final double thu;
  final double chi;

  const DiemBaoCao({
    required this.moc,
    required this.nhan,
    required this.thu,
    required this.chi,
  });
}

/// Một dòng ngân sách của kỳ, tra từ `BudgetRepository` ở tầng repository.
class DongNganSach {
  final String categoryId;
  final String ten;
  final double hanMuc;
  final double daChi;

  const DongNganSach({
    required this.categoryId,
    required this.ten,
    required this.hanMuc,
    required this.daChi,
  });

  double get conLai => hanMuc - daChi;
  bool get vuot => daChi > hanMuc;

  /// `daChi / hanMuc`, chưa cắt trần — giao diện tự kẹp về 1.0 cho thanh.
  double get tiLe => hanMuc <= 0 ? 0 : daChi / hanMuc;
}

/// Bộ lọc của một báo cáo. [walletId]/[categoryId] `null` nghĩa là **tất cả**.
class LocBaoCao {
  final DateTime from;
  final DateTime to;
  final String? walletId;
  final String? categoryId;

  const LocBaoCao({
    required this.from,
    required this.to,
    this.walletId,
    this.categoryId,
  });
}

/// Một giao dịch đã tra sẵn tên ví và tên danh mục.
///
/// Việc tra tên nằm ở repository chứ không ở đây, để tầng này kiểm được bằng
/// danh sách thuần, không cần CSDL.
class DongGiaoDich {
  final String id;
  final DateTime ngay;
  final double soTien;

  /// `'thu'`, `'chi'` hoặc `'transfer'` — giá trị cuối bị loại khỏi báo cáo.
  final String loai;

  /// `null` là khoản chưa phân loại; [tenDanhMuc] khi ấy là nhãn thay thế.
  final String? categoryId;
  final String tenDanhMuc;

  /// Mã màu `#RRGGBB` và tên biểu tượng như lưu ở cột `colour`/`icon`. Giữ
  /// chuỗi để tầng này không kéo `material.dart` vào.
  final String? mauHex;
  final String? icon;

  final String walletId;
  final String tenVi;

  /// Dòng chữ chính của giao dịch: ghi chú, hoặc tên danh mục khi không ghi chú.
  final String tieuDe;

  /// Ghi chú **thô** của hàng, chưa qua phép thay thế của [tieuDe].
  ///
  /// Cần riêng vì phép nhận dạng khoản điều chỉnh số dư đọc đúng chuỗi này;
  /// [tieuDe] rơi về tên danh mục khi ghi chú rỗng, nên nó không nói lên được
  /// hàng có ghi chú hay không. Để `null` là "nơi gọi chưa điền" — mặc định
  /// an toàn, vì khi ấy hàng được TÍNH vào thống kê.
  final String? ghiChu;

  const DongGiaoDich({
    required this.id,
    required this.ngay,
    required this.soTien,
    required this.loai,
    required this.categoryId,
    required this.tenDanhMuc,
    required this.mauHex,
    required this.icon,
    required this.walletId,
    required this.tenVi,
    required this.tieuDe,
    this.ghiChu,
  });
}

/// Một dòng của bảng "Chi theo danh mục" trên màn Xem trước.
class DongDanhMucBaoCao {
  final String? categoryId;
  final String ten;
  final String? mauHex;
  final String? icon;
  final double soTien;

  /// Tỉ lệ trên **tổng chi** của báo cáo, trong `[0, 1]`.
  final double tiLe;

  const DongDanhMucBaoCao({
    required this.categoryId,
    required this.ten,
    required this.mauHex,
    required this.icon,
    required this.soTien,
    required this.tiLe,
  });
}

/// Các giao dịch của cùng một ngày, dưới một tiêu đề ngày.
class NhomNgay {
  /// Ngày đã cắt về 00:00 — khoá gom nhóm.
  final DateTime ngay;
  final List<DongGiaoDich> dong;

  const NhomNgay({required this.ngay, required this.dong});
}

/// Toàn bộ nội dung màn Xem trước báo cáo.
class BaoCao {
  final DateTime from;
  final DateTime to;
  final TongThuChi tong;
  final List<DongDanhMucBaoCao> theoDanhMuc;

  /// Giao dịch gom theo ngày, **mới nhất trước**.
  final List<NhomNgay> nhom;

  final int soGiaoDich;

  /// Tổng của **kỳ liền trước** cùng độ dài và cùng bộ lọc — xem [khoangKyTruoc].
  final TongThuChi tongTruoc;

  /// Thu gom theo danh mục, đối xứng với [theoDanhMuc]. Không có nó thì tờ báo
  /// cáo mù một nửa dòng tiền: biết tiêu vào đâu mà không biết tiền từ đâu tới.
  final List<DongDanhMucBaoCao> thuTheoDanhMuc;

  /// Phân bổ theo ví — **rỗng** khi báo cáo đã lọc sẵn một ví.
  final List<DongVi> theoVi;

  /// Năm khoản chi lớn nhất, giảm dần.
  final List<DongGiaoDich> topChi;

  /// Cột thu/chi theo thời gian; độ chia đổi theo độ dài kỳ.
  final List<DiemBaoCao> chuoi;

  final SoLieuNhanh soLieu;

  /// `null` khi lọc theo một ví, hoặc khi không biết số dư hiện tại.
  final DongTien? dongTien;

  /// Ngân sách **đang chạy** của kỳ. Rỗng khi tài khoản không đặt ngân sách nào.
  final List<DongNganSach> nganSach;

  const BaoCao({
    required this.from,
    required this.to,
    required this.tong,
    required this.theoDanhMuc,
    required this.nhom,
    required this.soGiaoDich,
    required this.tongTruoc,
    required this.thuTheoDanhMuc,
    required this.theoVi,
    required this.topChi,
    required this.chuoi,
    required this.soLieu,
    required this.dongTien,
    required this.nganSach,
  });

  /// Không giao dịch nào lọt bộ lọc. Màn hình nói rỗng thay vì vẽ toàn số 0.
  bool get rong => soGiaoDich == 0;

  double? get thuSoVoiTruoc => phanTramSoVoi(tong.thu, tongTruoc.thu);
  double? get chiSoVoiTruoc => phanTramSoVoi(tong.chi, tongTruoc.chi);
}

/// Dựng báo cáo từ [ds] theo [loc].
///
/// [ds] là **toàn bộ** giao dịch của tài khoản, không phải danh sách đã lọc
/// sẵn: kỳ trước và dòng tiền nhìn ra ngoài khoảng đang xem. Cùng lý do với
/// `chuoi` của `ThongKeThang` — ai "tối ưu" bằng cách lọc trước khi gọi sẽ làm
/// hai khối ấy sai mà không lỗi nào báo.
///
/// `'transfer'` bị loại **khỏi cả danh sách**, không chỉ khỏi tổng: để nó lại
/// thì ba thẻ tổng ở đầu trang không cộng ra được các dòng bên dưới. Riêng
/// [soDuHienTai] thì ngược lại — xem [DongTien].
///
/// [soDuHienTai] là tổng số dư **mọi ví** lúc này. `null` (hoặc có lọc ví) thì
/// không có khối dòng tiền.
BaoCao dungBaoCao(
  List<DongGiaoDich> ds, {
  required LocBaoCao loc,
  double? soDuHienTai,
  List<DongNganSach> nganSach = const [],
}) {
  bool hopLoc(DongGiaoDich d) =>
      (loc.walletId == null || d.walletId == loc.walletId) &&
      (loc.categoryId == null || d.categoryId == loc.categoryId);

  final loc0 = <DongGiaoDich>[
    for (final d in ds)
      if (khoanVaoThongKe(
            loai: d.loai,
            categoryId: d.categoryId,
            ghiChu: d.ghiChu,
          ) &&
          !d.ngay.isBefore(loc.from) &&
          d.ngay.isBefore(loc.to) &&
          hopLoc(d))
        d,
  ];

  final khoan = [
    for (final d in loc0)
      KhoanThuChi(
        ngay: d.ngay,
        soTien: d.soTien,
        loai: d.loai,
        categoryId: d.categoryId,
      ),
  ];

  // Tên/màu/biểu tượng của một danh mục lấy từ dòng đầu gặp được: mọi dòng
  // cùng `categoryId` đều mang cùng bộ ấy, do repository tra một lần.
  final nhan = <String?, DongGiaoDich>{};
  for (final d in loc0) {
    nhan.putIfAbsent(d.categoryId, () => d);
  }

  final theoDanhMuc = [
    for (final c in chiTheoDanhMuc(khoan, from: loc.from, to: loc.to))
      DongDanhMucBaoCao(
        categoryId: c.categoryId,
        ten: nhan[c.categoryId]?.tenDanhMuc ?? 'Chưa phân loại',
        mauHex: nhan[c.categoryId]?.mauHex,
        icon: nhan[c.categoryId]?.icon,
        soTien: c.soTien,
        tiLe: c.tiLe,
      ),
  ];

  final gom = <DateTime, List<DongGiaoDich>>{};
  for (final d in loc0) {
    final ngay = DateTime(d.ngay.year, d.ngay.month, d.ngay.day);
    (gom[ngay] ??= []).add(d);
  }
  final nhom = [
    for (final ngay in gom.keys.toList()..sort((a, b) => b.compareTo(a)))
      NhomNgay(
        ngay: ngay,
        dong: gom[ngay]!..sort((a, b) => b.ngay.compareTo(a.ngay)),
      ),
  ];

  final thuTheoDanhMuc = [
    for (final c
        in chiTheoDanhMuc(khoan, from: loc.from, to: loc.to, loai: 'thu'))
      DongDanhMucBaoCao(
        categoryId: c.categoryId,
        ten: nhan[c.categoryId]?.tenDanhMuc ?? 'Chưa phân loại',
        mauHex: nhan[c.categoryId]?.mauHex,
        icon: nhan[c.categoryId]?.icon,
        soTien: c.soTien,
        tiLe: c.tiLe,
      ),
  ];

  // ── Kỳ trước: cùng bộ lọc, khoảng lấy từ `khoangKyTruoc` ────────────────
  final kt = khoangKyTruoc(from: loc.from, to: loc.to);
  final khoanTruoc = [
    for (final d in ds)
      if (khoanVaoThongKe(
            loai: d.loai,
            categoryId: d.categoryId,
            ghiChu: d.ghiChu,
          ) &&
          !d.ngay.isBefore(kt.from) &&
          d.ngay.isBefore(kt.to) &&
          hopLoc(d))
        KhoanThuChi(
          ngay: d.ngay,
          soTien: d.soTien,
          loai: d.loai,
          categoryId: d.categoryId,
        ),
  ];
  final tongTruoc = tongThuChi(khoanTruoc, from: kt.from, to: kt.to);

  // ── Phân bổ theo ví ─────────────────────────────────────────────────────
  final theoVi = <DongVi>[];
  if (loc.walletId == null) {
    final gomVi = <String, DongVi>{};
    for (final d in loc0) {
      final cu = gomVi[d.walletId];
      gomVi[d.walletId] = DongVi(
        walletId: d.walletId,
        ten: d.tenVi,
        thu: (cu?.thu ?? 0) + (d.loai == 'thu' ? d.soTien : 0),
        chi: (cu?.chi ?? 0) + (d.loai == 'chi' ? d.soTien : 0),
        soGiaoDich: (cu?.soGiaoDich ?? 0) + 1,
      );
    }
    theoVi.addAll(gomVi.values);
    // Hoà thì sắp theo id để hai lần dựng không đảo chỗ nhau.
    theoVi.sort((a, b) {
      final c = b.chi.compareTo(a.chi);
      return c != 0 ? c : a.walletId.compareTo(b.walletId);
    });
  }

  // ── Số liệu nhanh ───────────────────────────────────────────────────────
  final soNgay = loc.to.difference(loc.from).inDays;
  final chiTheoNgay = <DateTime, double>{};
  DongGiaoDich? lonNhat;
  for (final d in loc0) {
    if (d.loai != 'chi') continue;
    final ngay = DateTime(d.ngay.year, d.ngay.month, d.ngay.day);
    chiTheoNgay[ngay] = (chiTheoNgay[ngay] ?? 0) + d.soTien;
    if (lonNhat == null || d.soTien > lonNhat.soTien) lonNhat = d;
  }
  DateTime? ngayDinh;
  var chiDinh = 0.0;
  for (final e in chiTheoNgay.entries) {
    if (e.value > chiDinh) {
      chiDinh = e.value;
      ngayDinh = e.key;
    }
  }
  final tong = tongThuChi(khoan, from: loc.from, to: loc.to);
  final soLieu = SoLieuNhanh(
    // Chia cho số ngày CỦA KỲ, không phải số ngày có giao dịch: "chi trung
    // bình mỗi ngày" của tháng 9 phải chia cho 30.
    chiMoiNgay: soNgay <= 0 ? 0 : tong.chi / soNgay,
    ngayChiNhieuNhat: ngayDinh,
    chiNgayNhieuNhat: chiDinh,
    khoanChiLonNhat: lonNhat,
  );

  // ── Top khoản chi ───────────────────────────────────────────────────────
  final topChi = [
    for (final d in loc0)
      if (d.loai == 'chi') d,
  ]..sort((a, b) => b.soTien.compareTo(a.soTien));

  // ── Dòng tiền ───────────────────────────────────────────────────────────
  DongTien? dongTien;
  if (soDuHienTai != null && loc.walletId == null) {
    // Phần phát sinh SAU kỳ, trên toàn bộ ví (bộ lọc danh mục KHÔNG áp ở đây:
    // số dư ví chịu ảnh hưởng của mọi khoản, không riêng danh mục đang xem).
    final sau = [
      for (final d in ds)
        if (khoanVaoThongKe(
              loai: d.loai,
              categoryId: d.categoryId,
              ghiChu: d.ghiChu,
            ) &&
            !d.ngay.isBefore(loc.to))
          KhoanThuChi(
            ngay: d.ngay,
            soTien: d.soTien,
            loai: d.loai,
            categoryId: d.categoryId,
          ),
    ];
    final tongSau =
        tongThuChi(sau, from: loc.to, to: DateTime(9999, 12, 31));
    final trongKy = [
      for (final d in ds)
        if (khoanVaoThongKe(
              loai: d.loai,
              categoryId: d.categoryId,
              ghiChu: d.ghiChu,
            ) &&
            !d.ngay.isBefore(loc.from) &&
            d.ngay.isBefore(loc.to))
          KhoanThuChi(
            ngay: d.ngay,
            soTien: d.soTien,
            loai: d.loai,
            categoryId: d.categoryId,
          ),
    ];
    final tongTrongKy = tongThuChi(trongKy, from: loc.from, to: loc.to);
    final cuoiKy = soDuHienTai - (tongSau.thu - tongSau.chi);
    dongTien = DongTien(
      dauKy: cuoiKy - (tongTrongKy.thu - tongTrongKy.chi),
      cuoiKy: cuoiKy,
    );
  }

  return BaoCao(
    from: loc.from,
    to: loc.to,
    tong: tong,
    theoDanhMuc: theoDanhMuc,
    nhom: nhom,
    soGiaoDich: loc0.length,
    tongTruoc: tongTruoc,
    thuTheoDanhMuc: thuTheoDanhMuc,
    theoVi: theoVi,
    topChi: topChi.take(5).toList(),
    chuoi: _chuoiBaoCao(loc0, from: loc.from, to: loc.to),
    soLieu: soLieu,
    dongTien: dongTien,
    nganSach: nganSach,
  );
}

/// Cột thu/chi của biểu đồ, độ chia **đổi theo độ dài kỳ**: một tháng thì mỗi
/// ngày một cột; ba tháng thì theo tuần; dài hơn thì theo tháng.
///
/// Khoảng trống vẫn là một cột mang số 0 chứ không bị bỏ — bỏ đi là trục co
/// lại, hai mốc cách nhau một tuần hiện ra như liền kề (bài học của 2b).
List<DiemBaoCao> _chuoiBaoCao(
  List<DongGiaoDich> ds, {
  required DateTime from,
  required DateTime to,
}) {
  final soNgay = to.difference(from).inDays;
  if (soNgay <= 0) return const [];

  String hai(int x) => x.toString().padLeft(2, '0');

  final moc = <DateTime>[];
  if (soNgay <= 31) {
    for (var i = 0; i < soNgay; i++) {
      moc.add(DateTime(from.year, from.month, from.day + i));
    }
  } else if (soNgay <= 120) {
    for (var i = 0; i < soNgay; i += 7) {
      moc.add(DateTime(from.year, from.month, from.day + i));
    }
  } else {
    var m = DateTime(from.year, from.month, 1);
    while (m.isBefore(to)) {
      moc.add(m);
      m = DateTime(m.year, m.month + 1, 1);
    }
  }

  final thu = List<double>.filled(moc.length, 0);
  final chi = List<double>.filled(moc.length, 0);
  for (final d in ds) {
    if (d.loai != 'thu' && d.loai != 'chi') continue;
    var i = moc.length - 1;
    while (i > 0 && d.ngay.isBefore(moc[i])) {
      i--;
    }
    if (d.loai == 'thu') {
      thu[i] += d.soTien;
    } else {
      chi[i] += d.soTien;
    }
  }

  return [
    for (var i = 0; i < moc.length; i++)
      DiemBaoCao(
        moc: moc[i],
        nhan: soNgay > 120
            ? 'T${moc[i].month}'
            : '${hai(moc[i].day)}/${hai(moc[i].month)}',
        thu: thu[i],
        chi: chi[i],
      ),
  ];
}
