/// Dự án C, việc đầu — gợi ý danh mục theo SỐ TIỀN khi ghi chú không giúp được (spec
/// `2026-10-02-du-an-c-goi-y-danh-muc-theo-so-tien-design.md`). Hàm thuần: không Drift, không Flutter, không đồng hồ.
///
/// Naive Bayes phân loại trên ba đặc trưng — bậc tiền (thang 1·2·5), nhóm thứ (ngày thường / cuối tuần), ví — chỉ
/// trên mẫu CÙNG CHIỀU với đoạn đang chọn: số tiền không mang nghĩa chiều, nên 9.000.000 dưới đoạn Thu là *Lương*,
/// dưới đoạn Chi là *Nhà cửa*.
///
/// ⚠️ KHÔNG có giờ: giờ lưu trong giao dịch là giờ NHẬP (màn Thêm giao dịch khởi tạo ngày bằng `DateTime.now()`, và
/// `showDatePicker` trả 00:00), không phải giờ chi.
///
/// Đặt ở `category/domain/`, không ở `ai_edge/`: nó đọc sổ giao dịch và so chiều tiền — thứ test quét 14 cấm ở đó.
/// Cùng chỗ với `phan_loai_ghi_chu.dart` (B1); dùng lại `kToiThieuMauTong` và hai hằng của luật thôi gợi ý, nhưng
/// ngưỡng xác suất và số khoản ở bậc thì CHẶT hơn B1 — xem [kNguongXacSuatSoTien].
library;

import 'dart:math' as math;

import '../../../core/utils/currency_formatter.dart';
import '../../transaction/domain/khoang_tien.dart';
import 'phan_loai_ghi_chu.dart';

/// Giá trị cột `nguon` của bảng phản hồi cho thẻ gợi ý theo số tiền.
const String kNguonGoiYSoTien = 'so_tien';

const String kNhomNgayThuong = 'ngay_thuong';
const String kNhomCuoiTuan = 'cuoi_tuan';

/// Dưới mốc này là MỘT bậc: khoản vài nghìn không đáng chia nhỏ hơn.
const int kSanBacTien = 10000;

/// Hậu nghiệm tối thiểu để thẻ lên tiếng — **0,8**, chặt hơn 0,6 của B1.
///
/// Người dùng chốt 2026-10-02 sau phép đo trên CSDL thật (Realme, tài khoản 10, 67 giao dịch, phát lại theo thời
/// gian): ở ngưỡng 0,6 thẻ lên tiếng 9 lần, đúng 4; trong 5 lần thẻ thật sự hiện trên màn chỉ đúng 1. Các lần sai có
/// hậu nghiệm 0,65–0,77, các lần đúng 0,64–0,72 — không ngưỡng nào tách được, chỉ 0,8 làm im cả chín. Số tiền là tín
/// hiệu YẾU hơn chữ của ghi chú: hai danh mục khác nhau trùng số tiền (cà phê 10.000 và gửi xe 10.000) là chuyện
/// thường. ⚠️ Con số 0,8 chọn trên chính bộ đo ấy — chưa có số đo nào chứng minh thẻ đúng khi nó lên tiếng; đo lại
/// bằng `test/tool/do_goi_y_so_tien_test.dart` khi sổ có vài tháng dữ liệu dùng thật.
const double kNguongXacSuatSoTien = 0.8;

/// Danh mục gợi ý phải có ít nhất chừng này khoản ở ĐÚNG bậc tiền đang nhập — 5, chặt hơn 3 mẫu của B1 (cùng quyết
/// định 2026-10-02): ba khoản trùng bậc tiền chưa phải thói quen.
const int kToiThieuKhoanCungBac = 5;

/// Bậc tiền `[duoi, tren)`.
typedef BacTien = ({int duoi, int tren});

/// Bậc của [soTien] trên thang 1·2·5 × 10^k. Biên dưới thuộc bậc trên (50.000 → 50–100k); so biên bằng ngưỡng nửa
/// đồng vì `amount` là `double` (khoản điều chỉnh số dư mang đuôi lẻ).
BacTien bacTienCua(double soTien) {
  final x = soTien + kDungSaiTien;
  if (x < kSanBacTien) return (duoi: 0, tren: kSanBacTien);
  var muoi = kSanBacTien;
  while (muoi * 10 <= x) {
    muoi *= 10;
  }
  if (x < muoi * 2) return (duoi: muoi, tren: muoi * 2);
  if (x < muoi * 5) return (duoi: muoi * 2, tren: muoi * 5);
  return (duoi: muoi * 5, tren: muoi * 10);
}

/// Mã bậc — khoá của luật thôi gợi ý, và là `amTietChinh` trong bảng phản hồi.
String maBacCua(BacTien b) => '${b.duoi}-${b.tren}';

/// Hai nhóm chứ không bảy thứ: với vài chục mẫu, mỗi thứ riêng quá ít dữ liệu để nói gì (người dùng chốt 2026-10-02).
String nhomThuCua(DateTime ngay) => ngay.weekday >= DateTime.saturday ? kNhomCuoiTuan : kNhomNgayThuong;

class MauSoTien {
  final String categoryId;

  /// `'thu'` | `'chi'`.
  final String chieu;
  final String maBac;
  final String nhomThu;
  final String walletId;
  final DateTime ngay;
  const MauSoTien({
    required this.categoryId,
    required this.chieu,
    required this.maBac,
    required this.nhomThu,
    required this.walletId,
    required this.ngay,
  });
}

/// Mẫu có nhãn: khoản thu / chi có danh mục, chưa xoá, số tiền dương, không do máy sinh (`laGhiChuMay` của B1 — trả
/// hoá đơn, nạp / rút mục tiêu, điều chỉnh số dư, số dư ban đầu). Có hay không có ghi chú đều tính — khác `mauHocTu`
/// của B1 ở đúng chỗ ấy: tín hiệu ở đây là số tiền, không phải chữ.
List<MauSoTien> mauSoTienTu(
        Iterable<
                ({
                  String loai,
                  String? categoryId,
                  String? ghiChu,
                  double soTien,
                  String walletId,
                  DateTime ngay,
                  bool daXoa
                })>
            giaoDich) =>
    [
      for (final t in giaoDich)
        if (!t.daXoa &&
            t.categoryId != null &&
            (t.loai == 'thu' || t.loai == 'chi') &&
            t.soTien > 0 &&
            !laGhiChuMay(loai: t.loai, categoryId: t.categoryId, ghiChu: t.ghiChu))
          MauSoTien(
            categoryId: t.categoryId!,
            chieu: t.loai,
            maBac: maBacCua(bacTienCua(t.soTien)),
            nhomThu: nhomThuCua(t.ngay),
            walletId: t.walletId,
            ngay: t.ngay,
          ),
    ];

class DoanSoTien {
  final String categoryId;
  final double xacSuat;
  final String maBac;
  final BacTien bac;

  /// Số mẫu của danh mục đoán ở bậc này, cùng chiều.
  final int soLanCung;

  /// Số mẫu của bậc này, cùng chiều, mọi danh mục.
  final int soLanTong;
  const DoanSoTien({
    required this.categoryId,
    required this.xacSuat,
    required this.maBac,
    required this.bac,
    required this.soLanCung,
    required this.soLanTong,
  });
}

class BoPhanLoaiSoTien {
  BoPhanLoaiSoTien._(this._mau);

  factory BoPhanLoaiSoTien.hoc(List<MauSoTien> mau) => BoPhanLoaiSoTien._(List.unmodifiable(mau));

  final List<MauSoTien> _mau;

  /// Mẫu đã học — luật mở lại gợi ý (`tatCapSoTienTu`) đếm mẫu MỚI trên chính danh sách này.
  List<MauSoTien> get mau => _mau;

  /// `null` = chưa đủ để nói (spec 4.3): số tiền không dương, sổ mỏng (đếm theo CHIỀU), hậu nghiệm thấp, hoà ở đỉnh,
  /// danh mục đoán không dẫn đầu bậc tiền, hoặc cặp (mã bậc, danh mục) đang bị thôi gợi ý.
  ///
  /// [walletId] `null` (form chưa có ví) → bỏ đặc trưng ví, vẫn đoán bằng hai đặc trưng kia.
  DoanSoTien? doan({
    required String chieu,
    required double soTien,
    required DateTime ngay,
    String? walletId,
    required Set<String> hopLe,
    Set<(String, String)> tatCap = const {},
  }) {
    if (soTien <= 0) return null;
    final m = [
      for (final x in _mau)
        if (x.chieu == chieu) x,
    ];
    if (m.length < kToiThieuMauTong) return null;
    final bac = bacTienCua(soTien);
    final ma = maBacCua(bac);
    final thu = nhomThuCua(ngay);

    final n = <String, int>{};
    final nBac = <String, int>{};
    final nThu = <String, int>{};
    final nVi = <String, int>{};
    final cacBac = <String>{};
    final cacThu = <String>{};
    final cacVi = <String>{};
    for (final x in m) {
      final c = x.categoryId;
      n[c] = (n[c] ?? 0) + 1;
      if (x.maBac == ma) nBac[c] = (nBac[c] ?? 0) + 1;
      if (x.nhomThu == thu) nThu[c] = (nThu[c] ?? 0) + 1;
      if (x.walletId == walletId) nVi[c] = (nVi[c] ?? 0) + 1;
      cacBac.add(x.maBac);
      cacThu.add(x.nhomThu);
      cacVi.add(x.walletId);
    }
    // Laplace: mẫu số cộng số giá trị khác nhau của đặc trưng trong các mẫu cùng chiều.
    //
    // ⚠️ Một đặc trưng chỉ góp phần khi GIÁ TRỊ đang hỏi đã từng gặp. Giá trị lạ (ví mới tạo, ví chưa chọn, nhóm thứ
    // chưa có mẫu nào) thì mọi danh mục đều đếm 0, và phép làm trơn 1/(N(c)+K) khi ấy chỉ còn một tác dụng: phạt
    // danh mục ĐÔNG mẫu — tức kéo hậu nghiệm của chính danh mục đáng tin nhất xuống, vì một lý do chẳng liên quan gì
    // tới khoản đang nhập. Bậc tiền lạ thì không cần bỏ: chốt dẫn đầu bậc bên dưới đã trả `null`.
    double hop(Map<String, int> dem, String c, Set<String> giaTri, String? dangHoi) => giaTri.contains(dangHoi)
        ? math.log(((dem[c] ?? 0) + 1) / (n[c]! + giaTri.length))
        : 0.0;
    final diem = <String, double>{
      for (final c in n.keys)
        c: math.log(n[c]! / m.length) +
            hop(nBac, c, cacBac, ma) +
            hop(nThu, c, cacThu, thu) +
            hop(nVi, c, cacVi, walletId),
    };
    // Hậu nghiệm trên MỌI danh mục đã học; `hopLe` chỉ lọc ứng viên — tính trên phần còn lại là đẩy danh mục duy nhất
    // còn sống lên 100 % (cùng lý lẽ B1).
    final lon = diem.values.reduce(math.max);
    final tong = diem.values.fold(0.0, (a, d) => a + math.exp(d - lon));
    final ungVien = [
      for (final c in diem.keys)
        if (hopLe.contains(c)) c,
    ]..sort((a, b) {
        final s = diem[b]!.compareTo(diem[a]!);
        return s != 0 ? s : a.compareTo(b);
      });
    if (ungVien.isEmpty) return null;
    final c = ungVien.first;
    if (ungVien.length > 1 && diem[ungVien[1]] == diem[c]) return null;
    final p = math.exp(diem[c]! - lon) / tong;
    if (p < kNguongXacSuatSoTien) return null;
    // Chốt DẪN ĐẦU BẬC TIỀN (spec 4.3): ít nhất `kToiThieuKhoanCungBac` khoản ở đúng bậc này, và nhiều hơn MỌI danh
    // mục khác cùng chiều (kể cả danh mục ngoài `hopLe`). Thiếu nó thì một gợi ý thắng nhờ ví + thứ in "(2/5 lần)"
    // — câu lý do nói ngược gợi ý. Chốt này bao luôn "danh mục đứng đầu phải có đủ mẫu" của B1: N khoản ở một bậc
    // thì N(c) ≥ N.
    final cung = nBac[c] ?? 0;
    if (cung < kToiThieuKhoanCungBac) return null;
    for (final e in nBac.entries) {
      if (e.key != c && e.value >= cung) return null;
    }
    if (tatCap.contains((ma, c))) return null;
    return DoanSoTien(
      categoryId: c,
      xacSuat: p,
      maBac: ma,
      bac: bac,
      soLanCung: cung,
      soLanTong: nBac.values.fold(0, (a, b) => a + b),
    );
  }
}

/// Câu lý do in trên thẻ. Số tiền qua `CurrencyFormatter.format` — test quét 11 cấm nối ký hiệu tiền bằng tay.
String cauLyDoSoTien(DoanSoTien d, {required String tenDanhMuc}) {
  final lan = '(${d.soLanCung}/${d.soLanTong} lần)';
  if (d.bac.duoi == 0) {
    return 'Khoản dưới ${CurrencyFormatter.format(d.bac.tren)} bạn thường ghi cho $tenDanhMuc $lan.';
  }
  return 'Khoản từ ${CurrencyFormatter.format(d.bac.duoi)} đến ${CurrencyFormatter.format(d.bac.tren)} '
      'bạn thường ghi cho $tenDanhMuc $lan.';
}

/// Cặp (mã bậc, danh mục) của nguồn số tiền đang bị thôi gợi ý — cùng luật `tatCapTu` của B1, đếm mẫu theo BẬC thay
/// vì theo cụm âm tiết: hai lần bỏ qua thì tắt; ba giao dịch mới (ngày SAU lần bỏ qua cuối) cùng bậc cho đúng danh
/// mục ấy thì mở lại. Tập riêng của nguồn `so_tien`: bỏ qua thẻ B1 không tắt thẻ này, và ngược lại.
Set<(String, String)> tatCapSoTienTu(List<PhanHoiGoiY> phanHoi, List<MauSoTien> mau) {
  final boQua = <(String, String), List<DateTime>>{};
  for (final p in phanHoi) {
    if (p.nguon != kNguonGoiYSoTien || p.ketQua != kKetQuaGoiYBoQua) continue;
    boQua.putIfAbsent((p.amTietChinh, p.goiYCategoryId), () => []).add(p.createdAt);
  }
  final ra = <(String, String)>{};
  for (final e in boQua.entries) {
    if (e.value.length < kSoLanBoQuaThoiGoiY) continue;
    final cuoi = e.value.reduce((a, b) => a.isAfter(b) ? a : b);
    final moi = mau.where((x) => x.maBac == e.key.$1 && x.categoryId == e.key.$2 && x.ngay.isAfter(cuoi)).length;
    if (moi < kSoMauMoLai) ra.add(e.key);
  }
  return ra;
}
