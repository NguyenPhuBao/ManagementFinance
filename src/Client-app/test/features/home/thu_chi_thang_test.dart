/// Thu/chi tháng của Trang chủ phải là CÙNG con số với trang Phân tích.
///
/// Trước 2026-09-23, `thuChiThangCua` cộng **thô** theo `type`, nên đếm cả
/// khoản điều chỉnh số dư lẫn khoản "Số dư ban đầu" — hai thứ
/// `khoanVaoThongKe` cố ý loại khỏi mọi thống kê. Đo trên dữ liệu thật: Trang
/// chủ nói thu **15.145.000 đ**, trang Phân tích nói **15.135.000 đ**. Từ lát
/// 4b chỗ lệch ấy lộ ngay trên một màn: trợ lý AI trả lời bằng tool
/// `tong_ket_thu_chi_ky` (đọc `tongThuChi`), nên nó nói một số còn thẻ ngay trên
/// Trang chủ nói số kia. Người dùng chốt con số của Phân tích là con số đúng.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/home/domain/thu_chi_thang.dart';
import 'package:flowmoney/features/wallet/domain/dieu_chinh_so_du.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _gd(
  String id, {
  required String loai,
  required double soTien,
  required DateTime ngay,
  String? danhMuc,
  String ghiChu = '',
}) =>
    Transaction(
      id: id,
      walletId: 'w1',
      idaccount: 10,
      categoryId: danhMuc,
      amount: soTien,
      type: loai,
      status: 'completed',
      provider: 'Manual',
      note: ghiChu,
      date: ngay,
      images: '',
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: ngay,
      isDeleted: false,
    );

void main() {
  final now = DateTime(2026, 9, 23, 15);

  group('thuChiThangCua — Trang chủ nói cùng số với trang Phân tích', () {
    test('khoản ĐIỀU CHỈNH SỐ DƯ không phải thu nhập', () {
      final ds = [
        _gd('luong', loai: 'thu', soTien: 15135000, ngay: now, danhMuc: 'c-luong'),
        _gd('bu',
            loai: 'thu',
            soTien: 10000,
            ngay: now,
            ghiChu: ghiChuDieuChinh('đối soát ví')),
      ];

      expect(thuChiThangCua(ds, now).thu, 15135000,
          reason: 'Khoản bù đối soát là phép SỬA SỔ, không phải thu nhập. Đúng '
              'một khoản 10.000 như thế làm Trang chủ nói 15.145.000 trong khi '
              'trang Phân tích và trợ lý AI nói 15.135.000 (đo 2026-09-23).');
    });

    test('khoản SỐ DƯ BAN ĐẦU của ví mới không phải thu nhập', () {
      final ds = [
        _gd('neo',
            loai: 'thu', soTien: 5000000, ngay: now, ghiChu: ghiChuMoSo()),
      ];

      expect(thuChiThangCua(ds, now).thu, 0,
          reason: 'Tạo một ví có sẵn 5 triệu không phải có thêm 5 triệu thu '
              'nhập. Cộng thô thì mỗi ví người dùng tạo làm thẻ "Thu nhập" '
              'tháng ấy vọt lên đúng bằng số dư ban đầu.');
    });

    test('khoản điều chỉnh chiều CHI không phải chi tiêu', () {
      final ds = [
        _gd('an', loai: 'chi', soTien: 45000, ngay: now, danhMuc: 'c-an'),
        _gd('bu',
            loai: 'chi', soTien: 20000, ngay: now, ghiChu: ghiChuDieuChinh('')),
      ];

      expect(thuChiThangCua(ds, now).chi, 45000,
          reason: 'Đối soát ví xuống 20.000 không phải vừa tiêu 20.000.');
    });

    test('khoản CHƯA PHÂN LOẠI thật vẫn được tính', () {
      final ds = [
        _gd('cafe', loai: 'chi', soTien: 50000, ngay: now, ghiChu: 'Cà phê'),
      ];

      expect(thuChiThangCua(ds, now).chi, 50000,
          reason: 'Giao dịch kéo về từ server có thể trống danh mục thật (17 '
              'hàng, đo 2026-09-10). Loại theo MỖI cột danh mục là giấu chi '
              'tiêu thật — luật loại đòi CẶP điều kiện, không chỉ danh mục.');
    });

    test('cùng dữ liệu, Trang chủ và trang Phân tích cho CÙNG một cặp số', () {
      final ds = [
        _gd('luong', loai: 'thu', soTien: 15135000, ngay: now, danhMuc: 'c-luong'),
        _gd('an', loai: 'chi', soTien: 2141000, ngay: now, danhMuc: 'c-an'),
        _gd('cafe', loai: 'chi', soTien: 50000, ngay: now, ghiChu: 'Cà phê'),
        _gd('bu',
            loai: 'thu', soTien: 10000, ngay: now, ghiChu: ghiChuDieuChinh('')),
        _gd('neo',
            loai: 'thu', soTien: 5000000, ngay: now, ghiChu: ghiChuMoSo()),
        _gd('chuyen', loai: 'transfer', soTien: 300000, ngay: now),
        _gd('thang-truoc',
            loai: 'thu',
            soTien: 900000,
            ngay: DateTime(2026, 8, 31, 23, 59),
            danhMuc: 'c-luong'),
      ];

      final trangChu = thuChiThangCua(ds, now);
      final phanTich = tongThuChi(
        [
          for (final t in ds)
            KhoanThuChi(
              ngay: t.date,
              soTien: t.amount,
              loai: t.type,
              categoryId: t.categoryId,
              ghiChu: t.note,
            ),
        ],
        from: DateTime(2026, 9),
        to: DateTime(2026, 10),
      );

      expect(trangChu.thu, 15135000);
      expect(trangChu.chi, 2191000);
      expect((trangChu.thu, trangChu.chi), (phanTich.thu, phanTich.chi),
          reason: 'Cam kết của trợ lý AI là nói CÙNG số với màn hình. Tool '
              'tong_ket_thu_chi_ky đọc tongThuChi, thẻ Trang chủ đọc '
              'thuChiThangCua — trên cùng dữ liệu, hai hàm phải cho một đáp án.');
    });
  });

  group('thuChiThangCua — biên tháng', () {
    test('tháng 12: 31/12 23:59 được tính, 01/01 năm sau thì không', () {
      final thang12 = DateTime(2026, 12, 15);
      final ds = [
        _gd('cuoi-nam',
            loai: 'chi',
            soTien: 100000,
            ngay: DateTime(2026, 12, 31, 23, 59),
            danhMuc: 'c-an'),
        _gd('dau-nam-sau',
            loai: 'chi',
            soTien: 700000,
            ngay: DateTime(2027, 1, 1),
            danhMuc: 'c-an'),
      ];

      expect(thuChiThangCua(ds, thang12).chi, 100000,
          reason: 'Biên sau của tháng 12 là 01/01 của NĂM SAU — cắt sai biên là '
              'khoản giao thừa rơi khỏi tháng, hoặc khoản đầu năm lọt vào.');
    });

    test('tháng 2 năm nhuận: 29/02 được tính, 01/03 thì không', () {
      final thang2 = DateTime(2028, 2, 10);
      final ds = [
        _gd('nhuan',
            loai: 'thu',
            soTien: 250000,
            ngay: DateTime(2028, 2, 29, 20),
            danhMuc: 'c-luong'),
        _gd('dau-thang-3',
            loai: 'thu',
            soTien: 800000,
            ngay: DateTime(2028, 3, 1),
            danhMuc: 'c-luong'),
      ];

      expect(thuChiThangCua(ds, thang2).thu, 250000,
          reason: 'Tháng 2 năm 2028 có 29 ngày. Biên cố định "ngày 28" hay '
              '"tháng + 30 ngày" đều làm khoản 29/02 rơi khỏi tháng.');
    });
  });
}
