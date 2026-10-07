/// Tool `tim_giao_dich` — phần của `ai_edge`: CHÉP kết quả của `timGiaoDich`
/// (transaction/domain) thành hàng (spec bước 2 mục 3.8). Không lọc, không so
/// chiều tiền (test quét 14): chiều đi bằng enum `ChieuTim`.
///
/// ⚠️ Tên hàng là ghi chú (luật tiêu đề dòng sổ), nên ghi chú hệ thống dài như
/// "Tích lũy mục tiêu: MuaXe" là tên, và `kiemNhan` đòi câu nêu ĐỦ mọi âm tiết
/// của nó. Mô hình rút gọn thì câu rơi về mẫu câu — an toàn, cố ý không nới.
///
/// Bước 2c: kết quả mang **bộ lọc dội lại** (`boLoc` — bảy điều kiện thứ tự
/// cố định, tên là tên THẬT đã khớp; `soLieuBoLoc` — Từ/Đến rời `tongHop`) và
/// cờ `rongTheoBoLoc` khi 0 khoản khớp (spec 2c mục 2.2, bẫy 4.44).
library;

import '../../analytics/domain/thong_ke_thang.dart';
import '../../transaction/domain/tim_giao_dich.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';
import 'ma_ky.dart';

/// Mã tham số `chieu` của mô hình → chiều. ⚠️ Không dùng chữ trần của cột
/// `type` làm mã — test quét 14 cấm chúng trong `ai_edge/`.
const Map<String, ChieuTim> kChieuTim = {
  'khoan_chi': ChieuTim.chi,
  'khoan_thu': ChieuTim.thu,
  'chuyen_vi': ChieuTim.chuyen,
  'tat_ca': ChieuTim.tatCa,
};

const Map<String, SapXepTim> kSapXepTim = {
  'so_tien': SapXepTim.soTien,
  'moi_nhat': SapXepTim.moiNhat,
};

/// Trạng thái của phép chọn ở `gop = khong` (spec tool truy vấn, mục 2.2).
const String kTrangThaiKhoanLonNhat = 'khoản lớn nhất';
const String kTrangThaiKhoanNhoNhat = 'khoản nhỏ nhất';

/// Chữ trạng thái của phép chọn — `null` khi không chọn; chuỗi lạ → `null`
/// (tool đã kiểm enum trước khi tới đây).
String? chuChonKhoan(String? chon) => switch (chon) {
      'nhieu_nhat' => kTrangThaiKhoanLonNhat,
      'it_nhat' => kTrangThaiKhoanNhoNhat,
      _ => null,
    };

/// Bảy điều kiện chữ của bộ lọc — MỘT nguồn cho hàng lẻ (`hangGiaoDich`) và hàng
/// nhóm (`hangNhomGiaoDich`), spec 2c mục 2.2. Thứ tự cố định.
List<String> boLocTimGiaoDich(KetQuaTimGiaoDich kq, TieuChiTim tieuChi) {
  final chieu = tieuChi.chieu;
  final kt = tieuChi.khoangTien;
  final tuKhoa = tieuChi.tuKhoa.trim();
  return [
    if (chieu != ChieuTim.tatCa) _chuChieu(chieu),
    if (kq.tenDanhMucKhop != null) 'danh mục "${kq.tenDanhMucKhop}"',
    if (kq.tenViKhop != null) 'ví "${kq.tenViKhop}"',
    if (tuKhoa.isNotEmpty) 'ghi chú chứa "$tuKhoa"',
    // C4: mốc loại trừ nói đúng chữ của câu — "đến 100.000 đ" cho câu "dưới
    // 100 nghìn" là nói sai bộ lọc vừa áp.
    if (kt?.tu != null) '${tieuChi.tuLoaiTru ? 'trên' : 'từ'} ${soTien('Từ', kt!.tu!).chuoi}',
    if (kt?.den != null) '${tieuChi.denLoaiTru ? 'dưới' : 'đến'} ${soTien('Đến', kt!.den!).chuoi}',
    if (tieuChi.sapXep == SapXepTim.moiNhat) 'mới nhất trước',
  ];
}

/// Từ / Đến rời `tongHop` (bước 2c) — cùng nguồn cho hai loại hàng.
List<SoLieu> soLieuBoLocTimGiaoDich(TieuChiTim tieuChi) {
  final kt = tieuChi.khoangTien;
  return [
    if (kt?.tu != null) soTien(tieuChi.tuLoaiTru ? 'Trên' : 'Từ', kt!.tu!),
    if (kt?.den != null) soTien(tieuChi.denLoaiTru ? 'Dưới' : 'Đến', kt!.den!),
  ];
}

KetQuaCongCu hangGiaoDich(
  KetQuaTimGiaoDich kq, {
  required TieuChiTim tieuChi,
  required String chuKy,
  required DateTime now,
  String? chon,
}) {
  final loi = kq.loi;
  if (loi != null) {
    final (thamSo, loai) = switch (loi.truong) {
      TruongTen.danhMuc => ('danh_muc', 'danh mục'),
      TruongTen.vi => ('vi', 'ví'),
    };
    return loi.nhieu
        ? tuChoiKhopNhieu(thamSo, loi.hoi, loi.tenGoiY, loai: loai)
        : tuChoiKhongKhop(thamSo, loi.hoi, loi.tenGoiY, loai: loai);
  }
  final chieu = tieuChi.chieu;
  final tatCa = chieu == ChieuTim.tatCa;
  final tuKhoa = tieuChi.tuKhoa.trim();
  final chuChon = chuChonKhoan(chon);
  return KetQuaCongCu(
    hang: [
      for (final d in kq.dong)
        HangSoLieu(
          ten: d.tieuDe,
          trangThai: chuChon == null ? _trangThai(d) : '$chuChon · ${_trangThai(d)}',
          canhBao: false,
          soLieu: [
            soTien('Số tiền', d.soTien,
                ten: d.tieuDe,
                nhanKhac: _nhanChieu(d.chieu),
                nhanXungDot: _nhanChieu(_nguoc(d.chieu))),
            soNgayThang('Ngày', d.ngay, ten: d.tieuDe, now: now),
          ],
        ),
    ],
    tongHop: [
      // Nhãn chính "Số giao dịch" + nhãn thay thế "Số khoản" (bẫy 4.47): mô
      // hình nói "6 giao dịch" (C5) lẫn "2 khoản thu" (C8) cho cùng con số —
      // một nhãn duy nhất chặn một trong hai câu đúng (cổng D lần 4 và 5).
      soDem('Số giao dịch', kq.soKhop, nhanKhac: const ['Số khoản']),
      if (tatCa || chieu == ChieuTim.chi) soTien('Tổng chi', kq.tongChi),
      if (tatCa || chieu == ChieuTim.thu) soTien('Tổng thu', kq.tongThu),
      if (tatCa || chieu == ChieuTim.chuyen)
        soTien('Tổng chuyển', kq.tongChuyen),
    ],
    // Bộ lọc dội lại (bước 2c, spec mục 2.2): Từ/Đến rời tongHop để mẫu câu
    // không in chúng thành vế dữ liệu; tiền tố nêu chúng cùng bộ lọc chữ.
    soLieuBoLoc: soLieuBoLocTimGiaoDich(tieuChi),
    boLoc: [...boLocTimGiaoDich(kq, tieuChi), if (chuChon != null) chuChon],
    // 0 khoản với bộ lọc chữ tự do không phải câu trả lời (bẫy 4.44): C9 cổng D
    // lần 2 — tu_khoa "chi" → 0 khoản → mẫu câu "Số khoản: 0" (nhãn khi ấy) trong khi có 2.
    rongTheoBoLoc: kq.soKhop == 0,
    chuThem: {
      'ky': chuKy,
      'sap_xep': tieuChi.sapXep == SapXepTim.soTien
          ? 'lớn nhất trước'
          : 'mới nhất trước',
    },
    tenLienQuan: {
      for (final d in kq.dong) ...[
        if (d.tenDanhMuc != null) d.tenDanhMuc!,
        d.tenVi,
        if (d.tenViDich != null) d.tenViDich!,
      ],
      ...kq.tenKhop,
      // Tiền tố in `ghi chú chứa "T9"` — chữ số trong từ khoá là tên (bước 1c).
      if (tuKhoa.isNotEmpty) tuKhoa,
    }.toList(),
  );
}

/// Tổng của KỲ ĐEM RA SO (spec mở rộng tool §3.2) — cùng bộ lọc với kỳ gốc.
/// [chuKy] KHÔNG chữ số (*"tháng trước"*, *"cùng kỳ năm trước"*): nó vào nhãn
/// và vào `chuThem`.
class SoSanhKy {
  final String chuKy;
  final double chi;
  final double thu;
  const SoSanhKy({required this.chuKy, required this.chi, required this.thu});
}

/// Gắn phép so hai kỳ vào một kết quả đã dựng (hàng lẻ, hàng nhóm hay hàng đã
/// chọn): tổng kỳ so sánh, chênh lệch, tỉ lệ đổi — theo chiều đã hỏi.
///
/// ⚠️ Chênh lệch và tỉ lệ in số DƯƠNG, hướng đi bằng CHỮ (`chuThem`, nhãn thay
/// thế): mô hình nói *"ít hơn 500.000 đ"*, và một số âm trong gói không khớp
/// con số dương của câu ấy. Nền bằng 0 thì không có tỉ lệ lẫn chênh lệch —
/// *"tăng 100%"* là số bịa (cùng luật `phanTramSoVoi`).
///
/// Lượt bị từ chối, lượt rỗng theo bộ lọc và chiều chuyển ví: trả NGUYÊN [kq].
KetQuaCongCu themSoSanh(
  KetQuaCongCu kq, {
  required SoSanhKy soSanh,
  required ChieuTim chieu,
  required double tongChi,
  required double tongThu,
}) {
  if (kq.loi != null || kq.rongTheoBoLoc || chieu == ChieuTim.chuyen) return kq;
  final tatCa = chieu == ChieuTim.tatCa;
  final tongHop = <SoLieu>[];
  final chu = <String, String>{};
  void them(String nhan, double nay, double nen) {
    final thuong = nhan.toLowerCase();
    tongHop.add(soTien('Tổng $thuong ${soSanh.chuKy}', nen));
    if (nen == 0) {
      chu['so_sanh_$thuong'] = 'không có dữ liệu ${soSanh.chuKy}';
      return;
    }
    final lech = chenhLechSoVoi(nay, nen);
    final (huong, nhanKhac) = lech > 0
        ? ('nhiều hơn', ['$nhan nhiều hơn', '$nhan tăng', '$nhan hơn'])
        : lech < 0
            ? ('ít hơn', ['$nhan ít hơn', '$nhan giảm', '$nhan kém'])
            : ('bằng', ['$nhan bằng']);
    tongHop.add(soTien('Chênh lệch $thuong', lech.abs(), nhanKhac: nhanKhac));
    final tiLe = phanTramSoVoi(nay, nen);
    if (tiLe != null) {
      tongHop.add(
        soPhanTram('Tỉ lệ đổi $thuong', tiLe.abs(), nhanKhac: nhanKhac),
      );
    }
    chu['so_sanh_$thuong'] = '$thuong $huong ${soSanh.chuKy}';
  }

  if (tatCa || chieu == ChieuTim.chi) them('Chi', tongChi, soSanh.chi);
  if (tatCa || chieu == ChieuTim.thu) them('Thu', tongThu, soSanh.thu);
  return kq.boSung(
    tongHopThem: tongHop,
    chuThemMoi: chu,
    boLocCuoi: ['so với ${soSanh.chuKy}'],
  );
}

/// Gắn KỲ TỰ DO vào một kết quả đã dựng với chữ kỳ giữ chỗ (spec mở rộng tool
/// §3.1): chữ kỳ có số đứng ĐẦU `boLoc`, hai mốc thành số liệu NGÀY của bộ lọc
/// (câu nêu *"từ 01/08 đến 31/08"* qua được bộ kiểm), các cách gọi kỳ vào tên
/// liên quan (câu nêu *"tháng 8"* không bị đọc là số 8 bịa). [to] là biên MỞ.
KetQuaCongCu ganKyTuyChon(
  KetQuaCongCu kq, {
  required DateTime from,
  required DateTime to,
  required String chu,
  required List<String> ten,
  required DateTime now,
}) {
  final den = DateTime(to.year, to.month, to.day - 1);
  return kq.boSung(
    // Kỳ tương đối TRÙNG KHÍT khoảng, tại `now` — cho `kiemKy` (đo Realme
    // 2026-10-02: hỏi "tháng 9" vào tháng 10, câu "tháng trước bạn chi…" đúng).
    kyTuongDuongThem: [
      for (final e in kMaKy.entries)
        if (kyTuMa(e.key, now) case final k? when k.from == from && k.to == to) e.value,
    ],
    boLocDau: [chu],
    soLieuBoLocThem: [
      soNgayThang('Từ ngày', from, now: now, nhanKhac: const ['Từ']),
      soNgayThang('Đến ngày', den, now: now, nhanKhac: const ['Đến', 'Tới']),
    ],
    tenLienQuanThem: ten,
  );
}

/// Nhãn CHIỀU của dòng (bẫy 4.42): nhãn chính "Số tiền" không bao giờ xuất
/// hiện trong câu tự nhiên, nên chiều của dòng làm **nhãn thay thế** và chiều
/// ngược làm **nhãn xung đột** — khoản chi bị gọi là "khoản thu" (hay ngược
/// lại) thì `kiemNhan` chặn, còn câu nêu đúng chiều thì không bị coi là gán
/// ngược dù có nhắc chiều kia ở chỗ khác (lần đo 7: câu đúng C12 bị chặn oan
/// vì chỉ có xung đột mà không có nhãn chiều). Khoản chuyển cố ý không khai —
/// người dùng vẫn gọi tiền chuyển đi là "chi". Chữ hoa vì test quét 14.
List<String> _nhanChieu(ChieuTim c) => switch (c) {
      ChieuTim.chi => const ['Chi'],
      ChieuTim.thu => const ['Thu'],
      ChieuTim.chuyen || ChieuTim.tatCa => const [],
    };

ChieuTim _nguoc(ChieuTim c) => switch (c) {
      ChieuTim.chi => ChieuTim.thu,
      ChieuTim.thu => ChieuTim.chi,
      ChieuTim.chuyen || ChieuTim.tatCa => c,
    };

/// Chữ chiều cho tiền tố bộ lọc — cùng từ với `_trangThai`.
String _chuChieu(ChieuTim c) => switch (c) {
      ChieuTim.chi => 'khoản chi',
      ChieuTim.thu => 'khoản thu',
      ChieuTim.chuyen => 'chuyển ví',
      ChieuTim.tatCa => '',
    };

String _trangThai(DongTimThay d) {
  final dm = d.tenDanhMuc ?? 'Chưa phân loại';
  return switch (d.chieu) {
    ChieuTim.chi => 'khoản chi · $dm · ${d.tenVi}',
    ChieuTim.thu => 'khoản thu · $dm · ${d.tenVi}',
    ChieuTim.chuyen => d.tenViDich == null
        ? 'chuyển ví · ${d.tenVi}'
        : 'chuyển ví · ${d.tenVi} → ${d.tenViDich}',
    // Hàng mang một loại lạ (không phải thu, chi, chuyển).
    ChieuTim.tatCa => 'giao dịch · $dm · ${d.tenVi}',
  };
}
