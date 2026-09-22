/// Bộ kiểm GIỌNG — lớp chắn thứ hai cạnh `kiemSo`. `kiemSo` chặn số bịa; hàm này
/// chặn *diễn giải sai một con số đúng*: câu ở mức cảnh báo mà trấn an, hoặc
/// ngược lại. Ca quan trọng nhất: một câu có **đủ số đúng** mà vẫn phải bị chặn.
///
/// ⚠️ Bẫy phủ định: "không kiểm soát tốt" chứa "kiểm soát tốt". Blocklist theo
/// CỤM và kiểm phủ định trong cửa sổ ba từ trước — có ca canh bằng bản sai.
library;

import 'package:flowmoney/features/ai_edge/domain/kiem_giong.dart';
import 'package:flowmoney/features/ai_edge/domain/nhan_xet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const canhBao = MucNhanXet.canhBao;
  const binhThuong = MucNhanXet.binhThuong;

  test('⚠️ câu ĐỦ SỐ ĐÚNG nhưng trấn an ở mức cảnh báo thì bị chặn', () {
    // Đây là câu qua được kiemSo (mọi số đều có trong gói) mà vẫn sai nghĩa.
    expect(
      kiemGiong(
        'Bạn đang kiểm soát tốt — mới dùng 45.000 đ trên hạn mức 50.000 đ '
        '(90,0%), còn 11 ngày.',
        canhBao,
      ),
      isFalse,
      reason: '90 % trong 11 ngày là sắp vượt; "kiểm soát tốt" là diễn giải '
          'ngược — kiemSo không thấy, kiemGiong phải thấy',
    );
  });

  test('câu cảnh báo đúng giọng thì lọt', () {
    expect(
      kiemGiong(
          'Giáo dục đã dùng 90,0% hạn mức, còn 11 ngày — nên chi tối đa '
          '500 đ mỗi ngày.',
          canhBao),
      isTrue,
    );
  });

  test('câu bình thường mà báo động thì bị chặn', () {
    expect(
      kiemGiong('Ăn uống đã vượt hạn mức, cần cắt ngay.', binhThuong),
      isFalse,
      reason: 'hệ luật nói bình thường; mô hình hù người dùng là sai nghĩa',
    );
  });

  test('⚠️ cụm trấn an bị PHỦ ĐỊNH thì không tính là trấn an', () {
    expect(
      kiemGiong('Bạn chưa kiểm soát tốt khoản này: đã dùng 90,0%.', canhBao),
      isTrue,
      reason: 'ĐÒI KẾT QUẢ: "chưa kiểm soát tốt" là cảnh báo, không phải trấn an. '
          'Blocklist theo từ đơn sẽ vứt nhầm câu đúng này',
    );
  });

  test('phủ định cách xa hơn ba từ thì không còn phủ định', () {
    // "không" ở đầu câu, cách cụm 5 từ: không thể coi là phủ định cụm ấy.
    expect(
      kiemGiong('Không sao, tháng này bạn vẫn kiểm soát tốt.', canhBao),
      isFalse,
    );
  });

  test('không phân biệt hoa thường', () {
    expect(kiemGiong('KIỂM SOÁT TỐT lắm.', canhBao), isFalse);
  });

  test('mức thiếu dữ liệu thì luôn lọt — không có gì để đối chiếu', () {
    expect(
        kiemGiong(
            'Bất kỳ câu nào, kể cả kiểm soát tốt.', MucNhanXet.thieuDuLieu),
        isTrue);
  });

  test('câu không chứa cụm nào trong hai danh sách thì lọt ở mọi mức', () {
    const cau = 'Kỳ này chi 1.200.000 đ trên 9.000.000 đ thu.';
    expect(kiemGiong(cau, canhBao), isTrue);
    expect(kiemGiong(cau, binhThuong), isTrue);
  });
}
