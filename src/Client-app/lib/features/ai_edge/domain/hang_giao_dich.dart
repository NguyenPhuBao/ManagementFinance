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

import '../../transaction/domain/tim_giao_dich.dart';
import 'goi_so.dart';
import 'hang_so_lieu.dart';
import 'loi_tham_so.dart';

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

KetQuaCongCu hangGiaoDich(
  KetQuaTimGiaoDich kq, {
  required TieuChiTim tieuChi,
  required String chuKy,
  required DateTime now,
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
  final kt = tieuChi.khoangTien;
  final tu = kt?.tu == null ? null : soTien('Từ', kt!.tu!);
  final den = kt?.den == null ? null : soTien('Đến', kt!.den!);
  final tuKhoa = tieuChi.tuKhoa.trim();
  return KetQuaCongCu(
    hang: [
      for (final d in kq.dong)
        HangSoLieu(
          ten: d.tieuDe,
          trangThai: _trangThai(d),
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
    soLieuBoLoc: [if (tu != null) tu, if (den != null) den],
    boLoc: [
      if (!tatCa) _chuChieu(chieu),
      if (kq.tenDanhMucKhop != null) 'danh mục "${kq.tenDanhMucKhop}"',
      if (kq.tenViKhop != null) 'ví "${kq.tenViKhop}"',
      if (tuKhoa.isNotEmpty) 'ghi chú chứa "$tuKhoa"',
      if (tu != null) 'từ ${tu.chuoi}',
      if (den != null) 'đến ${den.chuoi}',
      if (tieuChi.sapXep == SapXepTim.moiNhat) 'mới nhất trước',
    ],
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
