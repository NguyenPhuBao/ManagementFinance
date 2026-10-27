/// Mọi câu khoá theo gói — MỘT chỗ (spec B1 2026-10-27 mục 4), từng ký tự.
library;

import 'package:flowmoney/features/premium/data/models/tran_goi.dart';
import 'package:flowmoney/features/premium/domain/cau_quyen.dart';
import 'package:flowmoney/features/premium/domain/hang_goi.dart';
import 'package:flowmoney/features/premium/domain/quyen_tinh_nang.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cauMoDau — Basic giữ câu 3ec874aa', () {
    expect(cauMoDau(LoaiTran.vi, const TranGoi(vi: 3)), 'Bạn đã dùng 3/3 ví của gói Basic.');
    expect(cauMoDau(LoaiTran.vi, const TranGoi(vi: 0)), 'Gói Basic hiện không cho tạo thêm ví.');
    expect(cauMoDau(LoaiTran.danhMucRieng, const TranGoi(danhMucRieng: 0)),
        'Gói Basic hiện không cho tạo thêm danh mục riêng.');
  });

  test('⭐ cauMoDau — Premium chạm trần cột Premium (B1)', () {
    expect(cauMoDau(LoaiTran.vi, const TranGoi(vi: 10), laPremium: true), 'Gói Premium hiện cho tạo tối đa 10 ví.');
    expect(cauMoDau(LoaiTran.vi, const TranGoi(vi: 0), laPremium: true), 'Gói Premium hiện không cho tạo thêm ví.');
  });

  test('⭐ cauMoDau — trần null (deeplink tay) → không câu, không "null/null"', () {
    expect(cauMoDau(LoaiTran.hoaDon, TranGoi.khongGioiHan), isNull);
  });

  test('cauMoDauQuyen — hai trạng thái', () {
    expect(cauMoDauQuyen(MaQuyen.exportReports), 'Xuất báo cáo là tính năng Premium.');
    expect(cauMoDauQuyen(MaQuyen.exportReports, tamNgung: true), 'Xuất báo cáo hiện đang tạm ngừng.');
  });

  test('câu widget khoá — từng ký tự', () {
    expect(kTheKhoaCanPremium, 'Dành cho Premium');
    expect(kTheKhoaTamNgung, 'Đang tạm ngừng');
    expect(kCongTacTamDungCanPremium, 'Tạm dừng — cần Premium');
    expect(kCongTacCanPremium, 'Cần Premium');
    expect(kCongTacTamNgung, 'Tạm ngừng');
    expect(cauDongKhoa(MaQuyen.quickActionShortcuts), 'Nút ghi nhanh — dành cho Premium');
    expect(cauDongKhoaTamNgung(MaQuyen.anomalySpendingInsights), 'Cảnh báo chi bất thường đang tạm ngừng');
  });
}
