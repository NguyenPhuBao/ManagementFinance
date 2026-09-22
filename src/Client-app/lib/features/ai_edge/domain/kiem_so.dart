/// Bộ kiểm số — điều kiện 10 của mục 13 bản đánh giá: **mọi** con số trong câu
/// phải có trong gói số; sai thì người gọi rơi về mẫu câu.
///
/// Dùng cho cả hai bản diễn giải: mẫu câu (mọi mẫu phải tự qua được bộ kiểm,
/// nếu không P3 sẽ rơi về một câu mà bộ kiểm cũng chặn — có ca test canh ở từng
/// gói số) và SLM (P3). Đây là lớp chắn **duy nhất** giữa mô hình và người
/// dùng, nên nó không được nới vì mô hình lớn hơn (spec mục 4.4).
///
/// Giới hạn cố ý: ngày tháng (`12/09`) cũng là số. Mẫu câu của app không in
/// ngày; nếu sau này gói số cần ngày thì thêm `LoaiSo.ngayThang` chứ đừng nới
/// regex.
library;

import 'goi_so.dart';

class SoTrich {
  final double giaTri;
  final bool laPhanTram;
  const SoTrich(this.giaTri, {required this.laPhanTram});
}

/// Nhóm 1: dấu âm (`-` hoặc `−`); nhóm 2: phần nguyên có chấm nghìn
/// (`2.100.000`) hoặc số trần; nhóm 3: phần thập phân sau **phẩy**; nhóm 4: hậu
/// tố `%`. Dấu âm phải bắt được vì `soPhanTram` giữ dấu (`-8,3%`): mất dấu là
/// đảo nghĩa tăng/giảm mà bộ kiểm vẫn cho qua. Không bắt `đ` — có hay không thì
/// cũng là một con số, và `9 đ` với `9 ngày` khác nhau ở **loại** của số liệu
/// chứ không ở cách trích.
final RegExp _mau =
    RegExp(r'(-|−)?(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d+))?\s*(%)?');

/// Mọi chuỗi số trong [cau], đã chuẩn hoá về `double`.
List<SoTrich> trichSo(String cau) => [
      for (final m in _mau.allMatches(cau))
        SoTrich(
          (m.group(1) == null ? 1 : -1) *
              double.parse(
                '${m.group(2)!.replaceAll('.', '')}.${m.group(3) ?? '0'}',
              ),
          laPhanTram: m.group(4) != null,
        ),
    ];

bool _khop(SoTrich x, SoLieu s) {
  final lech = (x.giaTri - s.soTho).abs();
  return switch (s.loai) {
    // Nửa đồng: đuôi lẻ của double, cùng ngưỡng với đối soát số dư.
    LoaiSo.tien => !x.laPhanTram && lech <= 0.5,
    // Một chữ số thập phân (G2) → sai số làm tròn tối đa 0,05.
    LoaiSo.phanTram => x.laPhanTram && lech <= 0.05,
    LoaiSo.soNgay || LoaiSo.soDem => !x.laPhanTram && lech == 0,
  };
}

/// `true` khi MỌI số trong [cau] khớp một [SoLieu] của [goi]. Câu không có số
/// nào thì lọt — không có gì để bịa.
bool kiemSo(String cau, GoiSo goi) =>
    trichSo(cau).every((x) => goi.soLieu.any((s) => _khop(x, s)));

/// Bản cho **hỏi đáp tự do** (P3 Task 8), nơi câu trả lời được phép rút số từ
/// nhiều màn cùng lúc: mỗi số phải khớp một [SoLieu] của **một gói bất kỳ**.
///
/// ⚠️ Đây **không** phải `goi.any(kiemSo)`. Viết như thế là đòi cả câu nằm gọn
/// trong một gói, nên một câu hoàn toàn đúng kiểu *"tháng này chi 1.200.000 đ,
/// mục tiêu còn thiếu 3.000.000 đ"* sẽ bị chặn — im lặng, vì người gọi chỉ
/// thấy câu rơi về mẫu.
bool kiemSoNhieuGoi(String cau, List<GoiSo> goi) => trichSo(cau).every(
      (x) => goi.any((g) => g.soLieu.any((s) => _khop(x, s))),
    );
