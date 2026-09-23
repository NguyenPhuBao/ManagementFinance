/// Một HÀNG đầy đủ — thứ chặng 4a đo được là còn thiếu: gói số 4a mang tên trên
/// từng `SoLieu` rời và E2B không nối được hai mục rời. Hàng gom tên + trạng
/// thái + số của một đối tượng vào MỘT object JSON cho mô hình.
library;

import 'package:flowmoney/features/ai_edge/domain/goi_so.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_so_lieu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('json của hàng: ten, trang_thai, rồi nhãn → CHUỖI đã định dạng', () {
    final h = HangSoLieu(
      ten: 'Kiem',
      trangThai: 'đã quá hạn',
      canhBao: true,
      soLieu: [soTien('Số tiền', 45000, ten: 'Kiem')],
    );
    expect(
      h.json,
      {'ten': 'Kiem', 'trang_thai': 'đã quá hạn', 'Số tiền': '45.000 đ'},
      reason: 'Mô hình chép nguyên chuỗi thì kiemSo khớp; bơm soTho (45000.0) '
          'là dạy nó viết một con số không có trong gói.',
    );
  });

  test('hàng không trạng thái (danh mục chi) không có khoá trang_thai', () {
    final h = HangSoLieu(
      ten: 'Ăn uống',
      trangThai: null,
      canhBao: false,
      soLieu: [soTien('Chi', 800000, ten: 'Ăn uống')],
    );
    expect(h.json.containsKey('trang_thai'), isFalse);
    expect(h.json, {'ten': 'Ăn uống', 'Chi': '800.000 đ'});
  });

  test('json của kết quả: hang + tổng hợp + chữ kèm không số', () {
    final kq = KetQuaCongCu(
      hang: [
        HangSoLieu(
          ten: 'Ăn uống',
          trangThai: null,
          canhBao: false,
          soLieu: [soTien('Chi', 800000, ten: 'Ăn uống')],
        ),
      ],
      tongHop: [soTien('Tổng chi', 2141000), soTien('Tổng thu', 15135000)],
      chuThem: const {'ky': 'tháng trước'},
    );
    expect(kq.json, {
      'hang': [
        {'ten': 'Ăn uống', 'Chi': '800.000 đ'}
      ],
      'Tổng chi': '2.141.000 đ',
      'Tổng thu': '15.135.000 đ',
      'ky': 'tháng trước',
    });
    expect(kq.loi, isNull);
  });

  test('từ chối tham số lạ: không hàng, không tổng hợp, chỉ lời nói vì sao', () {
    const kq = KetQuaCongCu.loi('ky "hom_qua" không hợp lệ');
    expect(kq.hang, isEmpty);
    expect(kq.tongHop, isEmpty);
    expect(kq.json, {'loi': 'ky "hom_qua" không hợp lệ'},
        reason: 'Không có khoá "hang" rỗng: mô hình đọc `{}` rỗng là "không có '
            'gì" trong khi thật ra là "tham số sai" — hai câu trả lời khác nhau.');
  });
}
