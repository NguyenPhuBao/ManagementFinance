/// Vai của một khoản vay/nợ — A8 #4 và #5 (2026-09-15).
///
/// Bốn vai *cho vay · thu nợ · đi vay · trả nợ* **không có cột nào lưu**, nhưng
/// suy ra được: **tên danh mục là QUAN HỆ nợ, `type` là VAI của lần này**. Màn
/// Thêm giao dịch hiện ô "Chiều tiền" cho đúng mục đích ấy — `Cho vay` + tiền
/// vào chính là *thu nợ*.
///
/// Luật này sai thì sai **im lặng**: tiền rơi sang nhầm biểu đồ, không exception,
/// không log, và người dùng **không sửa được bằng một cú chạm** như gợi ý lúc
/// nhập liệu.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';

void main() {
  group('vaiVayNoCua — đọc vai từ tên danh mục', () {
    test('bốn danh mục mặc định ra đúng bốn vai', () {
      expect(vaiVayNoCua(tenDanhMuc: 'Cho vay', loai: 'chi'), VaiVayNo.choVay);
      expect(vaiVayNoCua(tenDanhMuc: 'Trả nợ', loai: 'chi'), VaiVayNo.traNo);
      expect(vaiVayNoCua(tenDanhMuc: 'Thu nợ', loai: 'thu'), VaiVayNo.thuNo);
      expect(vaiVayNoCua(tenDanhMuc: 'Đi vay', loai: 'thu'), VaiVayNo.diVay);
    });

    test('hoa thường và khoảng trắng thừa không đổi kết quả', () {
      expect(
        vaiVayNoCua(tenDanhMuc: '  CHO   VAY ', loai: 'chi'),
        VaiVayNo.choVay,
        reason: 'so tên đi qua normalizeCategoryName, cùng phép với luật trùng '
            'tên danh mục',
      );
    });

    test('⚠️ CÙNG danh mục, đổi chiều tiền là đổi vai', () {
      // Đây là chốt quan trọng nhất, và bản đầu hiểu NGƯỢC: nó coi "Cho vay +
      // tiền vào" là tên nói dối và xếp vào `khac`, nên hai cột Thu nợ và Trả nợ
      // KHÔNG BAO GIỜ có số. Chạy thử trên máy ảo mới thấy ô "Chiều tiền" của
      // màn Thêm giao dịch — và thấy rằng hai danh mục mặc định đủ ghi bốn vai.
      expect(vaiVayNoCua(tenDanhMuc: 'Cho vay', loai: 'chi'), VaiVayNo.choVay);
      expect(vaiVayNoCua(tenDanhMuc: 'Cho vay', loai: 'thu'), VaiVayNo.thuNo);
      expect(vaiVayNoCua(tenDanhMuc: 'Đi vay', loai: 'thu'), VaiVayNo.diVay);
      expect(vaiVayNoCua(tenDanhMuc: 'Đi vay', loai: 'chi'), VaiVayNo.traNo);
    });

    test('tên nói vai nào cũng chỉ là quan hệ ấy', () {
      // Danh mục tên "Thu nợ" mà tiền lại đi ra: vẫn là quan hệ *cho vay*, và
      // lần này là cho vay thêm. Không có ca nào rơi vào `khac` vì chiều tiền.
      expect(vaiVayNoCua(tenDanhMuc: 'Thu nợ', loai: 'chi'), VaiVayNo.choVay);
      expect(vaiVayNoCua(tenDanhMuc: 'Trả nợ', loai: 'thu'), VaiVayNo.diVay);
    });

    test('tên tự đặt không đoán được thì là khac, KHÔNG dồn về một vai', () {
      expect(vaiVayNoCua(tenDanhMuc: 'Nợ Bảo', loai: 'chi'), VaiVayNo.khac);
      expect(vaiVayNoCua(tenDanhMuc: 'Cho mượn xe', loai: 'chi'), VaiVayNo.khac);
      expect(vaiVayNoCua(tenDanhMuc: null, loai: 'chi'), VaiVayNo.khac);
      expect(vaiVayNoCua(tenDanhMuc: '', loai: 'thu'), VaiVayNo.khac);
    });

    test('tên có chứa cụm khoá ở giữa vẫn nhận ra', () {
      expect(
        vaiVayNoCua(tenDanhMuc: 'Tiền cho vay bạn bè', loai: 'chi'),
        VaiVayNo.choVay,
      );
      expect(
        vaiVayNoCua(tenDanhMuc: 'Khoản thu nợ tháng 9', loai: 'thu'),
        VaiVayNo.thuNo,
      );
    });

    test('bỏ dấu KHÔNG được coi là khớp', () {
      // `removeVietnameseTones` là phép so MẤT THÔNG TIN, chỉ dành cho gợi ý —
      // quy tắc 7 `CLAUDE.md`. Ở đây đoán sai đẩy tiền sang nhầm biểu đồ.
      expect(vaiVayNoCua(tenDanhMuc: 'Tra no', loai: 'chi'), VaiVayNo.khac);
      expect(vaiVayNoCua(tenDanhMuc: 'Thu no', loai: 'thu'), VaiVayNo.khac);
    });

    test('khoản chuyển ví không có vai nào', () {
      expect(
        vaiVayNoCua(tenDanhMuc: 'Cho vay', loai: 'transfer'),
        VaiVayNo.khac,
      );
    });
  });

  group('chuoiVayNo — sáu kỳ, gom theo vai', () {
    KhoanThuChi k({
      required DateTime ngay,
      required double soTien,
      required String loai,
      required String ten,
      String classify = 'vay_no',
    }) =>
        KhoanThuChi(
          ngay: ngay,
          soTien: soTien,
          loai: loai,
          categoryId: 'c_$ten',
          classify: classify,
          tenDanhMuc: ten,
        );

    test('đủ sáu điểm, cũ nhất trước, điểm cuối là kỳ đang xem', () {
      final ds = chuoiVayNo(const [], ky: Ky.thang(2026, 9));
      expect(ds.length, 6);
      expect(ds.first.ky, Ky.thang(2026, 4));
      expect(ds.last.ky, Ky.thang(2026, 9));
    });

    test('bốn vai vào đúng bốn ô', () {
      final ds = chuoiVayNo(
        [
          k(ngay: DateTime(2026, 9, 2), soTien: 500000, loai: 'chi', ten: 'Cho vay'),
          k(ngay: DateTime(2026, 9, 3), soTien: 200000, loai: 'thu', ten: 'Thu nợ'),
          k(ngay: DateTime(2026, 9, 4), soTien: 900000, loai: 'thu', ten: 'Đi vay'),
          k(ngay: DateTime(2026, 9, 5), soTien: 300000, loai: 'chi', ten: 'Trả nợ'),
        ],
        ky: Ky.thang(2026, 9),
      );

      final cuoi = ds.last;
      expect(cuoi.choVay, 500000);
      expect(cuoi.thuNo, 200000);
      expect(cuoi.diVay, 900000);
      expect(cuoi.traNo, 300000);
      expect(cuoi.khacRa, 0);
      expect(cuoi.khacVao, 0);
    });

    test('khoản không đoán được vai tách theo CHIỀU TIỀN', () {
      final ds = chuoiVayNo(
        [
          k(ngay: DateTime(2026, 9, 2), soTien: 111000, loai: 'chi', ten: 'Nợ Bảo'),
          k(ngay: DateTime(2026, 9, 3), soTien: 222000, loai: 'thu', ten: 'Nợ Bảo'),
        ],
        ky: Ky.thang(2026, 9),
      );

      expect(ds.last.khacRa, 111000);
      expect(ds.last.khacVao, 222000);
      expect(ds.last.choVay, 0, reason: 'không dồn về một vai — đó là bịa');
    });

    test('CHỈ đếm khoản thuộc nhóm Vay/nợ', () {
      final ds = chuoiVayNo(
        [
          k(ngay: DateTime(2026, 9, 2), soTien: 500000, loai: 'chi', ten: 'Cho vay'),
          // Danh mục chi thường, dù tên có chữ "cho vay" cũng không tính.
          k(
            ngay: DateTime(2026, 9, 3),
            soTien: 700000,
            loai: 'chi',
            ten: 'Cho vay',
            classify: 'chi',
          ),
        ],
        ky: Ky.thang(2026, 9),
      );

      expect(ds.last.choVay, 500000,
          reason: 'nhóm Vay/nợ có một định nghĩa duy nhất — phanLoaiCua');
    });

    test('kỳ không có khoản nào vẫn giữ chỗ với số 0', () {
      final ds = chuoiVayNo(
        [k(ngay: DateTime(2026, 9, 2), soTien: 500000, loai: 'chi', ten: 'Cho vay')],
        ky: Ky.thang(2026, 9),
      );
      expect(ds.take(5).every((d) => d.rong), isTrue);
      expect(ds.last.rong, isFalse);
    });

    test('đi theo đơn vị của kỳ, không cứng theo tháng', () {
      final ds = chuoiVayNo(const [], ky: Ky.quy(2026, 3));
      expect(ds.last.ky, Ky.quy(2026, 3));
      expect(ds.first.ky, Ky.quy(2025, 2));
    });

    test('khoản 00:00 ngày đầu kỳ thuộc đúng một điểm', () {
      final ds = chuoiVayNo(
        [k(ngay: DateTime(2026, 9, 1), soTien: 400000, loai: 'chi', ten: 'Cho vay')],
        ky: Ky.thang(2026, 9),
      );
      expect(ds.last.choVay, 400000);
      expect(ds[4].choVay, 0, reason: 'biên to MỞ — không đếm ở cả hai kỳ');
    });
  });
}
