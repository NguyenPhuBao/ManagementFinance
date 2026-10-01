/// Adapter tool `du_bao_dong_tien`: đọc MỘT nguồn — `AnalyticsRepository.watchKy`
/// của tháng chứa `now` — rồi giao `ThongKeKy.duBao` cho `hangDuBao`. Dự báo luôn
/// tính từ hôm nay, nên tool không có tham số và bỏ qua mọi tham số mô hình điền.
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_du_bao.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/du_bao_dong_tien.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flutter_test/flutter_test.dart';

class _PhanTich implements AnalyticsRepository {
  _PhanTich(this.duBao);
  final DuBaoDongTien? duBao;
  final daHoi = <(int, Ky, DateTime?)>[];

  @override
  Stream<ThongKeKy> watchKy(int idaccount, {required Ky ky, DateTime? now}) {
    daHoi.add((idaccount, ky, now));
    return Stream.value(ThongKeKy(
      ky: ky,
      tong: const TongThuChi(thu: 0, chi: 0),
      tongTruoc: const TongThuChi(thu: 0, chi: 0),
      chiTheoDanhMuc: const [],
      danhMuc: const [],
      chuoi: const [],
      duBao: duBao,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);
  final duBao = DuBaoDongTien(
    tu: DateTime(2026, 9, 23),
    soDuHienTai: 300000,
    camKet: const [],
    tongCamKet: 0,
    nganSachConLai: 0,
    viThieu: const [],
    chuoi: const [],
  );

  test('khai báo: tên, mô tả "Gọi khi", KHÔNG tham số', () {
    final k = CongCuDuBao(_PhanTich(duBao)).khaiBao;
    expect(k.ten, kTenCongCuDuBao);
    expect(k.moTa, contains('Gọi khi'));
    expect(k.moTa, contains('còn tiêu được'));
    expect(k.thamSo['type'], 'object');
    expect(k.thamSo['properties'], isEmpty);
  });

  test('⭐ đọc watchKy của THÁNG CHỨA now, đúng tài khoản, truyền now', () async {
    final pt = _PhanTich(duBao);
    final kq = await CongCuDuBao(pt).chay({}, idaccount: 10, now: now);
    expect(pt.daHoi.single, (10, Ky.thang(2026, 9), now));
    expect(kq.json['Số dư hiện tại'], '300.000 đ');
  });

  test('tham số lạ của mô hình bị bỏ qua — không từ chối', () async {
    final kq = await CongCuDuBao(_PhanTich(duBao))
        .chay({'ky': 'thang_truoc', 'vi': 'abc'}, idaccount: 10, now: now);
    expect(kq.loi, isNull);
  });

  test('không có ví (duBao null) → chữ "chưa có ví", không ném', () async {
    final kq = await CongCuDuBao(_PhanTich(null)).chay({}, idaccount: 10, now: now);
    expect(kq.chuThem['tinh_trang'], 'chưa có ví');
  });
}
