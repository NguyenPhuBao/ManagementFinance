/// Adapter tool `tim_giao_dich`: tham số kiểm TRƯỚC khi đọc dữ liệu (spec mục
/// 3.9); "500k" từ chối kèm ví dụ — quy đổi là việc của mô hình và là thứ phép
/// đo cổng D chấm; tham số lạ bỏ qua.
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_giao_dich.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
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

  test('khai báo: tám tham số tuỳ chọn, enum đúng, mô tả có "Gọi khi" và ví dụ số đồng', () {
    final k = cc.khaiBao;
    expect(k.ten, kTenCongCuGiaoDich);
    expect(k.moTa, contains('Gọi khi'));
    expect(k.moTa, contains('500000'));
    final p = k.thamSo['properties'] as Map;
    expect(p.keys.toSet(),
        {'ky', 'so_tien_tu', 'so_tien_den', 'chieu', 'danh_muc', 'vi', 'tu_khoa', 'sap_xep'});
    expect(p['chieu']['enum'], ['khoan_chi', 'khoan_thu', 'chuyen_vi', 'tat_ca']);
    expect(p['sap_xep']['enum'], ['so_tien', 'moi_nhat']);
    expect(p['so_tien_tu']['type'], 'number');
    expect(k.thamSo['required'], isNull);
  });

  test('mặc định: tháng này, tất cả chiều, xếp theo số tiền', () async {
    final kq = await cc.chay({}, idaccount: 10, now: now);
    expect(giaoDich.khoangDaHoi.single, (DateTime(2026, 9, 1), DateTime(2026, 10, 1)));
    expect(kq.chuThem, {'ky': 'tháng này', 'sap_xep': 'lớn nhất trước'});
    expect(kq.hang.map((h) => h.ten).toList(), ['Chuyển khoản', 'Cho vay']);
  });

  test('⭐ "500k" từ chối kèm ví dụ, KHÔNG đọc dữ liệu', () async {
    final kq = await cc.chay({'so_tien_tu': '500k'}, idaccount: 10, now: now);
    expect(kq.loi, contains('500000'));
    expect(giaoDich.khoangDaHoi, isEmpty);
  });

  test('chuỗi toàn chữ số được nhận; số âm từ chối', () async {
    final kq = await cc.chay({'so_tien_tu': '500000', 'chieu': 'khoan_chi'}, idaccount: 10, now: now);
    expect(kq.loi, isNull);
    expect(kq.hang.single.ten, 'Cho vay');
    expect((await cc.chay({'so_tien_den': -1}, idaccount: 10, now: now)).loi, isNotNull);
  });

  test('so_tien_tu > so_tien_den từ chối, nêu hai số — không tự hoán đổi', () async {
    final kq = await cc.chay({'so_tien_tu': 1000000, 'so_tien_den': 200000}, idaccount: 10, now: now);
    expect(kq.loi, contains('1000000'));
    expect(kq.loi, contains('200000'));
    expect(giaoDich.khoangDaHoi, isEmpty);
  });

  test('enum lạ (ky, chieu, sap_xep) từ chối, liệt kê giá trị đúng', () async {
    expect((await cc.chay({'ky': 'hom_kia'}, idaccount: 10, now: now)).loi, contains('hom_qua'));
    expect((await cc.chay({'chieu': 'chi'}, idaccount: 10, now: now)).loi, contains('khoan_chi'));
    expect((await cc.chay({'sap_xep': 'cu_nhat'}, idaccount: 10, now: now)).loi, contains('moi_nhat'));
    expect(giaoDich.khoangDaHoi, isEmpty);
  });

  test('⭐ ví "tiet kiem" khớp Tiết kiệm (không Tiết kiệm mua nhà), gồm khoản chuyển VÀO nó', () async {
    final kq = await cc.chay({'vi': 'tiet kiem', 'chieu': 'chuyen_vi'}, idaccount: 10, now: now);
    expect(kq.hang.single.trangThai, 'chuyển ví · Tiền mặt → Tiết kiệm');
  });

  test('tên ví sai → từ chối kèm tên thật (vào tenLienQuan)', () async {
    final kq = await cc.chay({'vi': 'vi gia'}, idaccount: 10, now: now);
    expect(kq.loi, contains('Tiết kiệm mua nhà'));
    expect(kq.tenLienQuan, ['Tiền mặt', 'Tiết kiệm', 'Tiết kiệm mua nhà']);
  });

  test('tham số lạ bỏ qua', () async {
    expect((await cc.chay({'la': true}, idaccount: 10, now: now)).loi, isNull);
  });
}
