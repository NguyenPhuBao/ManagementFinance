/// A5 mục 5.4 — lưới kiểm cho ô AI lấp trên ảnh quét: luật thắng mọi ô đã điền; AI chỉ lấp ô trong `oThieu`, và mỗi
/// ô phải có căn cứ TRONG chữ của ảnh (AI chọn, không viết).
library;

import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 8, 10);
  const van = 'Pho Hung\n45.000\n90.000\nNgay 05/10/2026';
  KetQuaAnhQuet luat({double? tien, Set<OAnhQuet>? thieu}) => KetQuaAnhQuet(
        loai: LoaiAnhQuet.hoaDon,
        soTien: tien,
        chieu: 'chi',
        thoiGian: now,
        ghiChu: '',
        mon: const [],
        oThieu: thieu ?? {OAnhQuet.soTien, OAnhQuet.thoiGian, OAnhQuet.ghiChu},
      );

  test('⭐ AI chọn số CÓ trong chữ → lấp; số không có trong chữ → loại', () {
    final r = lapTuAi(luat(), const KetQuaAiAnh(soTien: 90000), vanBan: van, now: now);
    expect(r.soTien, 90000);
    expect(r.aiLap, isTrue);
    expect(r.oThieu.contains(OAnhQuet.soTien), isFalse);
    expect(lapTuAi(luat(), const KetQuaAiAnh(soTien: 95000), vanBan: van, now: now).soTien, isNull,
        reason: 'mô hình không được đưa ra chữ số không có trên ảnh');
  });

  test('ô luật đã điền KHÔNG bị ghi đè', () {
    final r = lapTuAi(luat(tien: 45000, thieu: {OAnhQuet.thoiGian}), const KetQuaAiAnh(soTien: 90000),
        vanBan: van, now: now);
    expect(r.soTien, 45000);
    expect(r.aiLap, isFalse);
  });

  test('ngày phải có trong chữ và không ở tương lai', () {
    expect(lapTuAi(luat(), const KetQuaAiAnh(ngay: '05/10/2026'), vanBan: van, now: now).thoiGian,
        DateTime(2026, 10, 5));
    expect(lapTuAi(luat(), const KetQuaAiAnh(ngay: '06/10/2026'), vanBan: van, now: now).aiLap, isFalse,
        reason: 'ngày không có trên ảnh');
    expect(lapTuAi(luat(), const KetQuaAiAnh(ngay: '05/10/2026'), vanBan: van, now: DateTime(2026, 10, 4)).aiLap,
        isFalse,
        reason: 'ngày tương lai');
    expect(lapTuAi(luat(), const KetQuaAiAnh(ngay: 'hôm qua'), vanBan: van, now: now).aiLap, isFalse);
  });

  test('nội dung phải là chuỗi con của chữ (chuẩn hoá); ô đã lấp rời oThieu', () {
    final r = lapTuAi(luat(), const KetQuaAiAnh(noiDung: 'PHO  hung'), vanBan: van, now: now);
    expect(r.ghiChu, 'PHO  hung');
    expect(r.aiLap, isTrue);
    expect(r.oThieu.contains(OAnhQuet.ghiChu), isFalse);
    expect(lapTuAi(luat(), const KetQuaAiAnh(noiDung: 'Bún bò'), vanBan: van, now: now).ghiChu, '');
  });

  test('KetQuaAiAnh.tuThamSo: 0 / rỗng / sai kiểu → null', () {
    final a = KetQuaAiAnh.tuThamSo({'so_tien': 0, 'ngay': ' ', 'noi_dung': 5});
    expect(a.soTien, isNull);
    expect(a.ngay, isNull);
    expect(a.noiDung, isNull);
    expect(KetQuaAiAnh.tuThamSo({'so_tien': 90000.0}).soTien, 90000);
  });

  test('chuGuiMoHinh: 3 dòng đầu + dòng có chữ số + dòng nhãn tổng; trần 1.200 ký tự', () {
    final dai = List.generate(300, (i) => 'Mon $i 10.000').join('\n');
    expect(chuGuiMoHinh(dai).length, lessThanOrEqualTo(1200));
    expect(chuGuiMoHinh('A\nB\nC\nkhong so\n12.000'), 'A\nB\nC\n12.000');
    expect(chuGuiMoHinh('A\nB\nC\nTong thanh toan\n90.000'), 'A\nB\nC\nTong thanh toan\n90.000',
        reason: 'nhãn tổng đứng riêng một dòng phải đi cùng số ở dòng kế');
  });
}
