/// Adapter tool `tong_quan_tai_chinh`: đọc `watchKy` HAI lần (kỳ đang hỏi + kỳ
/// trùm mọi thời gian cho dư nợ); kỳ mặc định là THÁNG NÀY khi câu không nêu.
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_tong_quan.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/analytics/data/analytics_repository.dart';
import 'package:flowmoney/features/analytics/domain/pham_vi_ky.dart';
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
import 'package:flowmoney/features/analytics/domain/vai_vay_no.dart';
import 'package:flutter_test/flutter_test.dart';

class _PhanTich implements AnalyticsRepository {
  final daHoi = <Ky>[];

  @override
  Stream<ThongKeKy> watchKy(int idaccount, {required Ky ky, DateTime? now}) {
    daHoi.add(ky);
    final moiLuc = ky.from == DateTime(1970);
    return Stream.value(ThongKeKy(
      ky: ky,
      tong: const TongThuChi(thu: 1000000, chi: 400000),
      tongTruoc: const TongThuChi(thu: 0, chi: 0),
      chiTheoDanhMuc: const [],
      danhMuc: const [],
      chuoi: [DiemThoiGian(ky: ky, tong: const TongThuChi(thu: 1000000, chi: 400000))],
      chuoiVayNo: [
        DiemVayNo(ky: ky, choVay: moiLuc ? 900000 : 0, thuNo: moiLuc ? 200000 : 0),
      ],
    ));
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);
  late _PhanTich pt;
  late CongCuTongQuan cc;
  setUp(() {
    pt = _PhanTich();
    cc = CongCuTongQuan(pt, log: (_) {});
  });

  test('khai báo: ky bắt buộc, có tuy_chon, KHÔNG có moi_luc; mô tả nói thu nhập không gồm vay nợ', () {
    final k = cc.khaiBao;
    expect(k.ten, kTenCongCuTongQuan);
    expect(k.moTa, contains('Gọi khi'));
    expect(k.moTa, contains('không gồm tiền đi vay'));
    final p = k.thamSo['properties'] as Map;
    expect(p.keys.toSet(), {'ky', 'tu_ngay', 'den_ngay'});
    expect(p['ky']['enum'], contains('tuy_chon'));
    expect(p['ky']['enum'], isNot(contains('moi_luc')));
    expect(k.thamSo['required'], ['ky']);
  });

  test('⭐ đọc hai lần: kỳ đang hỏi rồi kỳ trùm MỌI THỜI GIAN; dư nợ lấy từ lần hai', () async {
    final kq = await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now);
    expect(pt.daHoi.first, Ky.thang(2026, 9));
    expect(pt.daHoi[1].from, DateTime(1970));
    expect(pt.daHoi[1].to, DateTime(2026, 9, 24));
    expect(kq.json['Thu nhập'], '1.000.000 đ');
    expect(kq.json['Đang cho vay chưa thu về'], '700.000 đ');
    expect(kq.chuThem['ky'], 'tháng này');
  });

  test('⭐ câu không nêu kỳ → tháng này, dù mô hình điền kỳ khác', () async {
    await cc.chay({'ky': 'nam_nay'}, idaccount: 10, now: now, cauHoi: 'thu nhap cua toi la bao nhieu');
    expect(pt.daHoi.first, Ky.thang(2026, 9));
  });

  test('câu nêu kỳ: "quy nay", "thang truoc" giữ đúng kỳ của câu', () async {
    await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now, cauHoi: 'thu nhap quy nay cua toi');
    expect(pt.daHoi.first, Ky.quy(2026, 3));
    pt.daHoi.clear();
    await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now, cauHoi: 'thang truoc toi de danh bao nhieu phan tram');
    expect(pt.daHoi.first, Ky.thang(2026, 8));
  });

  test('"thang 8" → trọn một tháng là KỲ THÁNG (lùi theo lịch), chữ kỳ có số đứng đầu boLoc', () async {
    final kq = await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now, cauHoi: 'thu nhap thang 8 cua toi');
    expect(pt.daHoi.first, Ky.thang(2026, 8));
    expect(kq.boLoc.first, 'tháng 8/2026');
    expect(kq.chuThem['ky'], 'khoảng đã chọn');
  });

  test('khoảng lẻ → kỳ tuỳ chọn', () async {
    await cc.chay({'ky': 'tuy_chon', 'tu_ngay': '05/09/2026', 'den_ngay': '20/09/2026'}, idaccount: 10, now: now);
    expect(pt.daHoi.first, Ky.tuyChon(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 21)));
  });

  test('thiếu ky / moi_luc / mốc hỏng → từ chối, KHÔNG đọc dữ liệu', () async {
    expect((await cc.chay({}, idaccount: 10, now: now)).loi, isNotNull);
    expect((await cc.chay({'ky': 'moi_luc'}, idaccount: 10, now: now)).loi, contains('thang_nay'));
    expect((await cc.chay({'ky': 'tuy_chon', 'tu_ngay': '31/06/2026', 'den_ngay': '01/07/2026'},
        idaccount: 10, now: now)).loi, contains('dd/mm/yyyy'));
    expect(pt.daHoi, isEmpty);
  });
}
