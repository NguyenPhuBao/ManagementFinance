/// Adapter tool `truy_van_giao_dich` (thay `tim_giao_dich` + `tong_ket_thu_chi_ky`,
/// spec 2026-09-27): tham số kiểm TRƯỚC khi đọc dữ liệu; "500k" từ chối kèm ví dụ;
/// tham số lạ bỏ qua; `gop` / `chon` rẽ luồng; tổng hợp luôn đếm trọn tập.
/// 19 ca đầu chép nguyên từ `cong_cu_giao_dich_test.dart` (đã xoá cùng ngày).
library;

import 'package:flowmoney/features/ai_edge/data/cong_cu_truy_van.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/ma_ky.dart';
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
        id: 'cho', walletId: 'w-cash', idaccount: 10, categoryId: 'c-cv', amount: 800000,
        type: 'chi', note: 'Cho vay', date: DateTime(2026, 9, 19), updatedAt: DateTime(2026, 9, 19),
      ),
      TransactionEntity(
        id: 'ck', walletId: 'w-cash', idaccount: 10, walletTransfer: 'w-save', amount: 900000,
        type: 'transfer', date: DateTime(2026, 9, 8), updatedAt: DateTime(2026, 9, 8),
      ),
      TransactionEntity(
        id: 'an', walletId: 'w-cash', idaccount: 10, categoryId: 'c-au', amount: 50000,
        type: 'chi', note: 'Cơm', date: DateTime(2026, 9, 4), updatedAt: DateTime(2026, 9, 4),
      ),
      TransactionEntity(
        id: 'gt', walletId: 'w-cash', idaccount: 10, categoryId: 'c-gt', amount: 30000,
        type: 'chi', note: 'Phim', date: DateTime(2026, 9, 6), updatedAt: DateTime(2026, 9, 6),
      ),
      TransactionEntity(
        id: 'dc', walletId: 'w-cash', idaccount: 10, categoryId: 'c-dc', amount: 20000,
        type: 'chi', note: 'Xe', date: DateTime(2026, 9, 3), updatedAt: DateTime(2026, 9, 3),
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
        categories: [
          makeCategory(id: 'c-dc', name: 'Di chuyển'),
          makeCategory(id: 'c-cv', name: 'Cho vay'),
          makeCategory(id: 'c-au', name: 'Ăn uống'),
          makeCategory(id: 'c-gt', name: 'Giải trí'),
        ],
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
  Stream<List<LuaChonLoc>> watchDanhMuc(int idaccount) => Stream.value(const [
        LuaChonLoc(id: 'c-dc', ten: 'Di chuyển'),
        LuaChonLoc(id: 'c-cv', ten: 'Cho vay'),
        LuaChonLoc(id: 'c-au', ten: 'Ăn uống'),
        LuaChonLoc(id: 'c-gt', ten: 'Giải trí'),
      ]);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  final now = DateTime(2026, 9, 23, 10);
  late _GiaoDich giaoDich;
  late CongCuTruyVan cc;

  setUp(() {
    giaoDich = _GiaoDich();
    cc = CongCuTruyVan(giaoDich: giaoDich, nganSach: _NganSach(), baoCao: _BaoCao());
  });

  test('khai báo: mười tham số (ky bắt buộc — bước 2b), enum đúng, mô tả "Gọi cho MỌI câu" và ví dụ số đồng', () {
    final k = cc.khaiBao;
    expect(k.ten, kTenCongCuTruyVan);
    expect(k.moTa, startsWith('Gọi cho MỌI câu'));
    final p = k.thamSo['properties'] as Map;
    expect((p['so_tien_tu'] as Map)['description'], contains('500000'));
    expect(p.keys.toSet(), {
      'ky', 'so_tien_tu', 'so_tien_den', 'chieu', 'danh_muc', 'vi', 'tu_khoa', 'sap_xep', 'gop', 'chon',
    });
    expect(p['chieu']['enum'], ['khoan_chi', 'khoan_thu', 'chuyen_vi', 'tat_ca']);
    expect(p['sap_xep']['enum'], ['so_tien', 'moi_nhat']);
    expect(p['gop']['enum'], ['khong', 'danh_muc', 'vi']);
    expect(p['chon']['enum'], ['nhieu_nhat', 'it_nhat']);
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

  test('ky thang_nay: tất cả chiều, xếp theo số tiền, trần bốn hàng nhưng Số giao dịch đủ', () async {
    final kq = await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now);
    expect(giaoDich.khoangDaHoi.single, (DateTime(2026, 9, 1), DateTime(2026, 10, 1)));
    expect(kq.chuThem, {'ky': 'tháng này', 'sap_xep': 'lớn nhất trước'});
    expect(kq.hang.map((h) => h.ten).toList(), ['Chuyển khoản', 'Cho vay', 'Cơm', 'Phim']);
    expect(kq.json['Số giao dịch'], '5');
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

  test('enum lạ (ky, chieu, sap_xep, gop, chon) từ chối, liệt kê giá trị đúng, KHÔNG đọc dữ liệu', () async {
    expect((await cc.chay({'ky': 'hom_kia'}, idaccount: 10, now: now)).loi, contains('hom_qua'));
    expect((await cc.chay({'ky': 'thang_nay', 'chieu': 'chi'}, idaccount: 10, now: now)).loi, contains('khoan_chi'));
    expect((await cc.chay({'ky': 'thang_nay', 'sap_xep': 'cu_nhat'}, idaccount: 10, now: now)).loi, contains('moi_nhat'));
    expect((await cc.chay({'ky': 'thang_nay', 'gop': 'thang'}, idaccount: 10, now: now)).loi, contains('danh_muc'));
    expect((await cc.chay({'ky': 'thang_nay', 'chon': 'duoi_nua'}, idaccount: 10, now: now)).loi, contains('nhieu_nhat'));
    expect(giaoDich.khoangDaHoi, isEmpty);
  });

  test('⭐ C15 lần 11: câu hỏi "chi cho di chuyen" chỉnh chieu chuyen_vi → khoan_chi, danh_muc Di chuyển, ky moi_luc', () async {
    final kq = await cc.chay(
      {'ky': 'hom_nay', 'chieu': 'chuyen_vi', 'sap_xep': 'moi_nhat'},
      idaccount: 10,
      now: now,
      cauHoi: 'lan gan nhat toi chi cho di chuyen la ngay nao',
    );
    expect(kq.loi, isNull);
    expect(kq.hang.single.trangThai, 'khoản chi · Di chuyển · Tiền mặt',
        reason: 'mô hình đọc "di chuyển" thành chuyển ví — câu hỏi nói chi cho một danh mục có thật');
    expect(kq.boLoc, containsAll(<String>['khoản chi', 'danh mục "Di chuyển"', 'mới nhất trước']));
    expect(giaoDich.khoangDaHoi.single.$1.year, 1970, reason: 'câu không nêu kỳ → mọi thời gian');
  });

  test('không truyền cauHoi (mặc định rỗng) thì args giữ nguyên như trước', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'chieu': 'chuyen_vi'}, idaccount: 10, now: now);
    expect(kq.hang.single.trangThai, 'chuyển ví · Tiền mặt → Tiết kiệm');
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

  test('⭐ đầu-cuối bước 2c: tu_khoa không khớp ghi chú nào → lượt THÀNH CÔNG rỗng theo bộ lọc, boLoc đúng, JSON có Đến', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'tu_khoa': 'khong co', 'so_tien_den': 1000000},
        idaccount: 10, now: now);
    expect(kq.loi, isNull);
    expect(kq.rongTheoBoLoc, isTrue, reason: 'C9: 0 hàng không phải "không có giao dịch"');
    expect(kq.boLoc, ['ghi chú chứa "khong co"', 'đến 1.000.000 đ']);
    expect(kq.json['Đến'], '1.000.000 đ');
    expect(kq.json['Số giao dịch'], '0');
    expect(kq.tongHop.map((s) => s.nhan), isNot(contains('Đến')));
    expect(kq.tenLienQuan, contains('khong co'));
  });

  test('boLoc dùng TÊN THẬT: vi "tiet_kiem" + chuyen_vi → "chuyển ví", "ví "Tiết kiệm""', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'chieu': 'chuyen_vi', 'vi': 'tiet_kiem'}, idaccount: 10, now: now);
    expect(kq.boLoc, ['chuyển ví', 'ví "Tiết kiệm"']);
    expect(kq.rongTheoBoLoc, isFalse);
  });

  test('tu_khoa là chữ có chữ số (tên hoá đơn "T9") vẫn tìm bình thường', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'tu_khoa': 'T9'}, idaccount: 10, now: now);
    expect(kq.loi, isNull);
    expect(giaoDich.khoangDaHoi, hasLength(1));
  });

  // ── gop / chon (spec tool truy vấn, mục 1–2) ─────────────────────────────

  test('⭐ gop=danh_muc: hàng nhóm, hai đầu mang trạng thái, Số danh mục; Tổng chi BẰNG gop=khong cùng kỳ', () async {
    final nhom = await cc.chay({'ky': 'thang_nay', 'chieu': 'khoan_chi', 'gop': 'danh_muc'}, idaccount: 10, now: now);
    final le = await cc.chay({'ky': 'thang_nay', 'chieu': 'khoan_chi'}, idaccount: 10, now: now);
    expect(nhom.hang.map((h) => h.ten).toList(), ['Cho vay', 'Ăn uống', 'Giải trí', 'Di chuyển']);
    expect(nhom.hang.first.trangThai, 'chi nhiều nhất');
    expect(nhom.hang.last.trangThai, 'chi ít nhất');
    expect(nhom.json['Số danh mục'], '4');
    expect(nhom.json['Tổng chi'], le.json['Tổng chi'], reason: 'gộp và liệt kê cùng một tập');
    expect(nhom.json['Tổng chi'], '900.000 đ');
    expect(nhom.boLoc, contains('gộp theo danh mục'));
  });

  test('⭐ E3: gop=danh_muc + chon=it_nhat → đúng một hàng Di chuyển; tổng hợp trên trọn tập', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'chieu': 'khoan_chi', 'gop': 'danh_muc', 'chon': 'it_nhat'},
        idaccount: 10, now: now);
    expect(kq.hang.single.ten, 'Di chuyển');
    expect(kq.hang.single.trangThai, 'chi ít nhất');
    expect(kq.json['Tổng chi'], '900.000 đ');
    expect(kq.json['Số giao dịch'], '4');
  });

  test('⭐ gop=khong + chon=nhieu_nhat → một hàng lớn nhất, trạng thái "khoản lớn nhất", Số giao dịch đủ', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'chieu': 'khoan_chi', 'chon': 'nhieu_nhat'}, idaccount: 10, now: now);
    expect(kq.hang.single.ten, 'Cho vay');
    expect(kq.hang.single.trangThai, startsWith('khoản lớn nhất'));
    expect(kq.json['Số giao dịch'], '4');
  });

  test('chon it_nhat ở gop=khong → hàng nhỏ nhất (Xe)', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'chieu': 'khoan_chi', 'chon': 'it_nhat'}, idaccount: 10, now: now);
    expect(kq.hang.single.ten, 'Xe');
    expect(kq.hang.single.trangThai, startsWith('khoản nhỏ nhất'));
  });

  test('gop=vi: nhóm theo ví nguồn, Số ví', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'gop': 'vi'}, idaccount: 10, now: now);
    expect(kq.hang.single.ten, 'Tiền mặt');
    expect(kq.json['Số ví'], '1');
    expect(kq.json['Số giao dịch'], '5');
  });

  test('⭐ đầu-cuối E3 qua bộ chỉnh: "danh muc nao toi it tieu nhat trong thang" với args chỉ có ky', () async {
    final kq = await cc.chay({'ky': 'thang_nay'}, idaccount: 10, now: now,
        cauHoi: 'danh muc nao toi it tieu nhat trong thang');
    expect(kq.hang.single.ten, 'Di chuyển');
    expect(kq.hang.single.trangThai, 'chi ít nhất');
  });

  test('⭐ đầu-cuối E15: "cho vay bao nhieu va thu ve duoc bao nhieu" → chieu tat_ca + danh mục Cho vay', () async {
    final kq = await cc.chay({'ky': 'thang_nay', 'chieu': 'khoan_thu'}, idaccount: 10, now: now,
        cauHoi: 'toi da cho vay bao nhieu va thu ve duoc bao nhieu');
    expect(kq.loi, isNull);
    expect(kq.boLoc, ['danh mục "Cho vay"'], reason: 'chiều đã lật sang tat_ca nên không còn "khoản thu"');
    expect(kq.hang.single.ten, 'Cho vay');
  });
}
