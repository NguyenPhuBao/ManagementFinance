// test/features/ai_edge/domain/slm_prompt_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/ai_edge/domain/slm_prompt.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';

class _GoiGia implements GoiSo {
  @override
  final String man;
  @override
  final List<SoLieu> soLieu;

  /// Mức của hệ luật — prompt phải chở nó xuống (dòng MỨC), nên lớp giả phải
  /// đặt được. Mặc định `binhThuong` để mọi ca cũ dựng không đổi.
  final MucNhanXet muc;
  _GoiGia(this.man, this.soLieu, [this.muc = MucNhanXet.binhThuong]);
  @override
  bool get thieuDuLieu => false;
  @override
  NhanXet mauCau() => NhanXet(cau: 'mẫu', theSoLieu: soLieu, muc: muc);
  @override
  String get dauVan => 'gia';
}

void main() {
  final goi = _GoiGia('ngan_sach', [
    soTien('Đã chi', 45000),
    soPhanTram('Tỉ lệ', 90),
    soNgay('Còn', 11),
  ]);

  test('prompt chở ĐÚNG chuỗi đã định dạng của gói, không phải số thô', () {
    // `SoLieu.chuoi` là ba thứ cùng lúc: thẻ người dùng thấy, tập cho phép của
    // bộ kiểm số, và phần bơm vào prompt. Bơm `soTho` (45000.0) thì mô hình sẽ
    // chép lại "45000" — một chuỗi mà `kiemSo` vẫn cho qua nhưng người dùng
    // đọc là sai định dạng tiền của app.
    final p = promptCauTheoMan(goi);
    expect(p, contains('Đã chi: 45.000 đ'));
    expect(p, contains('Tỉ lệ: 90,0%'));
    expect(p, contains('Còn: 11 ngày'));
    expect(p, isNot(contains('45000')));
  });

  test('có prompt hệ thống và HAI ví dụ few-shot', () {
    final p = promptCauTheoMan(goi);
    expect(p, contains(kPromptHeThong));
    expect('Ví dụ'.allMatches(p).length, 2,
        reason: 'Spec mục 4.3 chốt hai ví dụ. Một ví dụ thì mô hình hay bịa '
            'thêm câu dẫn; ba thì tốn token vô ích ở trần 1024.');
  });

  test('⚠️ ví dụ few-shot KHÔNG được chứa số ngoài gói của chính nó', () {
    // Bẫy 4.1: bộ kiểm số không phân biệt số trang trí với số bịa. Nếu ví dụ
    // dạy mô hình nói một con số không có trong gói thật, mọi câu sinh ra đều
    // bị `kiemSo` chặn và P3 rơi về mẫu câu — im lặng, trông như mô hình kém.
    final p = promptCauTheoMan(goi);
    // ⚠️ Mốc cắt phải là `lastIndexOf` — chuỗi 'Số liệu:' xuất hiện TRONG chính
    // hai ví dụ, nên `indexOf` cắt ngay giữa ví dụ 1 và khối còn lại chỉ là cái
    // nhãn "Ví dụ 1.". Và bỏ dòng nhãn: số thứ tự của ví dụ không phải số liệu.
    final khoiViDu = p
        .substring(p.indexOf('Ví dụ 1'), p.lastIndexOf('Số liệu:'))
        .split('\n')
        .where((l) => !l.startsWith('Ví dụ '))
        .join('\n');
    for (final m in RegExp(r'\d[\d.,]*').allMatches(khoiViDu)) {
      expect(khoiViDu.split(m.group(0)!).length - 1, greaterThanOrEqualTo(2),
          reason: 'Số "${m.group(0)}" trong ví dụ phải xuất hiện ở CẢ phần số '
              'liệu lẫn phần câu của chính ví dụ ấy — nếu không, ví dụ đang '
              'dạy mô hình bịa.');
    }
  });

  test('prompt mang dòng MỨC đúng với mức của hệ luật', () {
    final canh = _GoiGia('ngan_sach', [soPhanTram('Tỉ lệ', 90)], MucNhanXet.canhBao);
    expect(promptCauTheoMan(canh), contains('MỨC: CẢNH BÁO'));
    expect(promptCauTheoMan(goi), contains('MỨC: BÌNH THƯỜNG'));
  });

  test('hỏi đáp: chở câu hỏi và gói của MỌI màn', () {
    final p = promptHoiDap('Tháng này tôi tiêu nhiều không?', [
      goi,
      _GoiGia('muc_tieu', [soPhanTram('Tiến độ', 55)]),
    ]);
    expect(p, contains('Tháng này tôi tiêu nhiều không?'));
    expect(p, contains('Đã chi: 45.000 đ'));
    expect(p, contains('Tiến độ: 55,0%'));
  });

  test('gói rỗng vẫn cho prompt hợp lệ, không ném', () {
    expect(() => promptCauTheoMan(_GoiGia('trang_chu', const [])),
        returnsNormally);
  });
}
