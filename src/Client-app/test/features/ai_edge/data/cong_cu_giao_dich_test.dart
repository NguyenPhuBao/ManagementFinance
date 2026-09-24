/// Adapter tool `tim_giao_dich`: tham số kiểm TRƯỚC khi đọc dữ liệu (spec mục
/// 3.9); "500k" từ chối kèm ví dụ — quy đổi là việc của mô hình và là thứ phép
/// đo cổng D chấm; tham số lạ bỏ qua.
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_giao_dich.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_chi_tieu.dart';
import 'package:flowmoney/features/analytics/data/bao_cao_repository.dart';
import 'package:flowmoney/features/budget/data/repositories/budget_repository.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/data/repositories/transaction_repository.dart';
import 'package:flowmoney/features/transaction/domain/transaction_lookup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

class _GiaoDich implements TransactionRepository {
  final khoangDaHoi = <(DateTime, DateTime)>[];
  @override
  Stream<List<TransactionEntity>> watchKhoang(int idaccount, DateTime from, DateTime to) {
    khoangDaHoi.add((from, to));
    return Stream.value([
      TransactionEntity(
        id: 'cho', walletId: 'w-cash', idaccount: 10, categoryId: 'c-dc', amount: 800000,
        type: 'chi', note: 'Cho vay', date: DateTime(2026, 9, 19), updatedAt: DateTime(2026, 9, 19),
      ),
      TransactionEntity(
        id: 'ck', walletId: 'w-cash', idaccount: 10, walletTransfer: 'w-save', amount: 900000,
        type: 'transfer', date: DateTime(2026, 9, 8), updatedAt: DateTime(2026, 9, 8),
      ),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _NganSach implements BudgetRepository {
  @override
  Future<TransactionLookup> lookupFor(int idaccount) async => TransactionLookup(
        wallets: [makeWallet(id: 'w-cash', name: 'Tiền mặt'), makeWallet(id: 'w-save', name: 'Tiết kiệm')],
        categories: [makeCategory(id: 'c-dc', name: 'Di chuyển')],
      );

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _BaoCao implements BaoCaoRepository {
  @override
  Stream<List<LuaChonLoc>> watchVi(int idaccount) => Stream.value(const [
        LuaChonLoc(id: 'w-cash', ten: 'Tiền mặt'),
        LuaChonLoc(id: 'w-save', ten: 'Tiết kiệm'),
        LuaChonLoc(id: 'w-nha', ten: 'Tiết kiệm mua nhà'),
      ]);
  @override
  Stream<List<LuaChonLoc>> watchDanhMuc(int idaccount) =>
      Stream.value(const [LuaChonLoc(id: 'c-dc', ten: 'Di chuyển')]);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);
  late _GiaoDich giaoDich;
  late CongCuGiaoDich cc;
  setUp(() {
    giaoDich = _GiaoDich();
    cc = CongCuGiaoDich(giaoDich: giaoDich, nganSach: _NganSach(), baoCao: _BaoCao());
  });

  test('khai báo: tám tham số (ky bắt buộc — bước 2b), enum đúng, mô tả có "Gọi khi" và ví dụ số đồng', () {
    final k = cc.khaiBao;
    expect(k.ten, kTenCongCuGiaoDich);
    expect(k.moTa, contains('Gọi khi'));
    final p = k.thamSo['properties'] as Map;
    expect((p['so_tien_tu'] as Map)['description'], contains('500000'));
    expect(p.keys.toSet(),
        {'ky', 'so_tien_tu', 'so_tien_den', 'chieu', 'danh_muc', 'vi', 'tu_khoa', 'sap_xep'});
    expect(p['chieu']['enum'], ['khoan_chi', 'khoan_thu', 'chuyen_vi', 'tat_ca']);
    expect(p['sap_xep']['enum'], ['so_tien', 'moi_nhat']);
    expect(p['so_tien_tu']['type'], 'number');
    expect(k.thamSo['required'], ['ky'],
        reason: 'C4, C8 của cổng D lần 1: câu có nêu kỳ mà mô hình bỏ trống ky');
    expect(p['ky']['enum'], [...kMaKy.keys, 'moi_luc']);
  });

  test('⭐ thiếu ky → từ chối, KHÔNG tự mặc định tháng này (spec 2b mục 2.5)', () async {
    final kq = await cc.chay({}, idaccount: 10, now: now);
    expect(kq.loi, contains('moi_luc'));
    expect(kq.choNguoiDung, 'chưa hiểu khoảng thời gian trong câu hỏi');
    expect(kq.thamSoGo, ['ky']);
    expect(giaoDich.khoangDaHoi, isEmpty,
        reason: 'C4: câu hỏi "tuần này" mà tìm tháng này — câu trả lời sai kỳ');
  });

  test('ky thang_nay: tất cả chiều, xếp theo số tiền', () async {
    final kq = await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now);
    expect(giaoDich.khoangDaHoi.single, (DateTime(2026, 9, 1), DateTime(2026, 10, 1)));
    expect(kq.chuThem, {'ky': 'tháng này', 'sap_xep': 'lớn nhất trước'});
    expect(kq.hang.map((h) => h.ten).toList(), ['Chuyển khoản', 'Cho vay']);
  });

  test('⭐ moi_luc → đọc từ 1970 tới đầu ngày mai; chữ kỳ "mọi thời gian"', () async {
    final kq = await cc.chay({'ky': 'moi_luc'}, idaccount: 10, now: now);
    expect(giaoDich.khoangDaHoi.single, (DateTime(1970), DateTime(2026, 9, 24)),
        reason: '"lần gần nhất" sang tháng mới từng chỉ tìm trong tháng này');
    expect(kq.chuThem['ky'], 'mọi thời gian');
    expect(kq.loi, isNull);
  });

  test('⭐ "500k" từ chối kèm ví dụ, KHÔNG đọc dữ liệu', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'so_tien_tu': '500k'}, idaccount: 10, now: now);
    expect(kq.loi, contains('500000'));
    expect(giaoDich.khoangDaHoi, isEmpty);
  });

  test('chuỗi toàn chữ số được nhận; số âm từ chối', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'so_tien_tu': '500000', 'chieu': 'khoan_chi'}, idaccount: 10, now: now);
    expect(kq.loi, isNull);
    expect(kq.hang.single.ten, 'Cho vay');
    expect((await cc.chay({'ky': 'thang_nay', 'so_tien_den': -1}, idaccount: 10, now: now)).loi, isNotNull);
  });

  test('so_tien_tu > so_tien_den từ chối, nêu hai số — không tự hoán đổi', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'so_tien_tu': 1000000, 'so_tien_den': 200000}, idaccount: 10, now: now);
    expect(kq.loi, contains('1000000'));
    expect(kq.loi, contains('200000'));
    expect(giaoDich.khoangDaHoi, isEmpty);
  });

  test('enum lạ (ky, chieu, sap_xep) từ chối, liệt kê giá trị đúng', () async {
    expect((await cc.chay({'ky': 'hom_kia'}, idaccount: 10, now: now)).loi, contains('hom_qua'));
    expect((await cc.chay({'ky': 'thang_nay', 'chieu': 'chi'}, idaccount: 10, now: now)).loi, contains('khoan_chi'));
    expect((await cc.chay({'ky': 'thang_nay', 'sap_xep': 'cu_nhat'}, idaccount: 10, now: now)).loi, contains('moi_nhat'));
    expect(giaoDich.khoangDaHoi, isEmpty);
  });

  test('⭐ ví "tiet kiem" khớp Tiết kiệm (không Tiết kiệm mua nhà), gồm khoản chuyển VÀO nó', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'vi': 'tiet kiem', 'chieu': 'chuyen_vi'}, idaccount: 10, now: now);
    expect(kq.hang.single.trangThai, 'chuyển ví · Tiền mặt → Tiết kiệm');
  });

  test('⭐ ví "tiet_kiem" (E2B gõ snake_case) vẫn khớp Tiết kiệm — không từ chối (bẫy 4.45)', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'vi': 'tiet_kiem', 'chieu': 'chuyen_vi'}, idaccount: 10, now: now);
    expect(kq.loi, isNull, reason: 'C11 cổng D lần 2 rơi về L1b vì tên có gạch dưới');
    expect(kq.hang.single.trangThai, 'chuyển ví · Tiền mặt → Tiết kiệm');
  });

  test('tên ví sai → từ chối kèm tên thật (vào tenLienQuan)', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'vi': 'vi gia'}, idaccount: 10, now: now);
    expect(kq.loi, contains('Tiết kiệm mua nhà'));
    expect(kq.tenLienQuan, ['Tiền mặt', 'Tiết kiệm', 'Tiết kiệm mua nhà', 'vi gia']);
    expect(kq.choNguoiDung, 'không có ví nào tên "vi gia"');
  });

  test('tham số lạ bỏ qua', () async {
    expect((await cc.chay({'ky': 'thang_nay', 'la': true}, idaccount: 10, now: now)).loi, isNull);
  });

  test('⭐ giá trị giữ chỗ ở danh_muc / vi / tu_khoa → kết quả GIỐNG HỆT không truyền (bẫy 4.43)', () async {
    final goc = await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now);
    for (final args in <Map<String, dynamic>>[
      {'ky': 'thang_nay', 'danh_muc': 'tat_ca'},
      {'ky': 'thang_nay', 'vi': 'tất_cả'},
      {'ky': 'thang_nay', 'tu_khoa': 'tất cả'},
      {'ky': 'thang_nay', 'danh_muc': 'ALL', 'vi': 'tat ca'},
    ]) {
      final kq = await cc.chay(args, idaccount: 10, now: now);
      expect(kq.loi, isNull, reason: 'C8 ($args): tool từ chối oan, mô hình đọc thành "không có"');
      expect(kq.json, goc.json, reason: '$args');
    }
  });

  test('⭐ tu_khoa là số tiền → từ chối TRƯỚC khi đọc dữ liệu', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'tu_khoa': '500k'}, idaccount: 10, now: now);
    expect(kq.loi, contains('so_tien_tu'));
    expect(kq.choNguoiDung, 'chưa hiểu số tiền trong câu hỏi');
    expect(giaoDich.khoangDaHoi, isEmpty,
        reason: 'để nguyên thì tìm "500k" trong ghi chú ra 0 khoản — một lượt THÀNH CÔNG, '
            'và câu "không có khoản nào" được phép hiện');
  });

  test('tu_khoa là chữ có chữ số (tên hoá đơn "T9") vẫn tìm bình thường', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'tu_khoa': 'T9'}, idaccount: 10, now: now);
    expect(kq.loi, isNull);
    expect(giaoDich.khoangDaHoi, hasLength(1));
  });
}
