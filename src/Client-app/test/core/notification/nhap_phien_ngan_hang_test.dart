/// Nhắc ghi sau khi dùng app ngân hàng — lượt nhập lúc mở app (spec §4.3–4.4, §5.1).
///
/// Bốn điều đáng canh, cả bốn hỏng im lặng:
/// 1. **Cờ máy ghi lại theo tài khoản ĐANG đăng nhập ở MỌI lượt** (bẫy 3 D1).
/// 2. **Mốc**: lần đầu / thiếu quyền → mốc = bây giờ (không đổ phiên cũ); sau lượt xét → giờ rời lớn nhất (không xét lại).
/// 3. **Bằng chứng** đọc từ hàng loại 20 đang có (trừ chính dòng nhắc) và từ sổ giao dịch.
/// 4. **Không bao giờ ném** — đường này nằm trên lối đăng nhập và lối quay lại từ nền.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/kenh_phien_ngan_hang.dart';
import 'package:flowmoney/core/notification/moc_phien_store.dart';
import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/core/notification/nhap_phien_ngan_hang.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/phien_ngan_hang.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

class _KenhGia implements KenhPhienNganHang {
  bool quyen = true;
  bool nem = false;
  List<SuKienSuDung> suKienTra = const [];
  DateTime? boDenTra;
  final List<(bool, DateTime?)> datBatGoi = [];
  final List<DateTime> tuDaHoi = [];
  int soLanHuy = 0;

  @override
  Future<bool> coQuyen() async => quyen;
  @override
  Future<void> moCaiDat() async {}
  @override
  Future<List<SuKienSuDung>> suKien(DateTime tu) async {
    if (nem) throw StateError('kênh hỏng');
    tuDaHoi.add(tu);
    return suKienTra;
  }

  @override
  Future<DateTime?> boDen() async => boDenTra;
  @override
  Future<void> datBat(bool bat, {DateTime? daXetDen}) async => datBatGoi.add((bat, daXetDen));
  @override
  Future<void> huyNhac() async => soLanHuy++;
}

DateTime _t(int h, int m, [int s = 0]) => DateTime(2026, 10, 3, h, m, s);
SuKienSuDung _vao(DateTime t) => SuKienSuDung(goi: 'com.mbmobile', lop: 'Main', vao: true, luc: t);
SuKienSuDung _ra(DateTime t) => SuKienSuDung(goi: 'com.mbmobile', lop: 'Main', vao: false, luc: t);

void main() {
  const id = 7;
  late AppDatabase db;
  late _KenhGia kenh;
  late InMemoryMocPhienStore moc;
  late bool bat;
  late List<BangChungGiaoDich> gd;
  String? viMb;
  var soId = 0;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    kenh = _KenhGia()..suKienTra = [_vao(_t(11, 19)), _ra(_t(11, 20, 35))]; // 95 giây
    moc = InMemoryMocPhienStore()..values[id] = _t(11, 0);
    bat = true;
    gd = [];
    viMb = null;
  });
  tearDown(() => db.close());

  NhapPhienNganHang dung({DateTime? bayGio}) => NhapPhienNganHang(
        kenh: kenh,
        dao: db.notificationDao,
        moc: moc,
        batNhac: (_) async => bat,
        nguonCuaGoi: (g) => g == 'com.mbmobile' ? kNguonMb : null,
        giaoDichTrongKhoang: (_, __, ___) async => gd,
        viCuaNguon: (_, __) async => viMb,
        clock: () => bayGio ?? _t(12, 0),
        idGenerator: () => 'id-${soId++}',
      );

  Future<List<AppNotification>> dongNhac() async =>
      [for (final h in await db.notificationDao.getAll(id)) if (laKhoaPhien(h.dedupeKey)) h];

  Future<void> themHang(String khoa, DateTime luc, {String nguon = kNguonMb}) =>
      db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
        id: 'co-$khoa',
        idaccount: id,
        kind: NotificationKind.bienDongSoDu.name,
        dedupeKey: khoa,
        title: 't',
        body: 'b',
        severity: NotificationSeverity.info.name,
        deeplink: Value(deeplinkBienDong(
            TinBienDong(soTien: 50000, chieu: 'chi', thoiGian: luc, noiDung: 'x', nguon: nguon),
            dedupeKey: khoa)),
        createdAt: luc,
      ));

  test('⭐ cờ tắt → không dòng, không hỏi sự kiện, ghi cờ máy TẮT (máy dùng chung)', () async {
    bat = false;
    expect(await dung().nhap(id), 0);
    expect(kenh.tuDaHoi, isEmpty);
    expect(kenh.datBatGoi, [(false, _t(11, 0))]);
  });

  test('⭐ lần đầu (chưa có mốc) → mốc = bây giờ, KHÔNG đổ phiên cũ', () async {
    moc.values.clear();
    expect(await dung().nhap(id), 0);
    expect(moc.values[id], _t(12, 0));
    expect(kenh.tuDaHoi, isEmpty);
    expect(kenh.datBatGoi.single, (true, _t(12, 0)));
  });

  test('⭐ thiếu quyền → mốc = bây giờ: phiên lúc không có quyền không bao giờ được nhắc', () async {
    kenh.quyen = false;
    expect(await dung().nhap(id), 0);
    expect(moc.values[id], _t(12, 0));
    expect(kenh.tuDaHoi, isEmpty);
    expect(await dongNhac(), isEmpty);
  });

  test('⭐ phiên 95 giây không bằng chứng → một dòng loại 20 đúng hình dạng; mốc tiến; báo Kotlin; gỡ thông báo',
      () async {
    expect(await dung().nhap(id), 1);
    final h = (await dongNhac()).single;
    expect(h.kind, NotificationKind.bienDongSoDu.name);
    expect(h.dedupeKey, 'bienDong:phien|MB Bank|2026-10-03T11:19');
    expect(h.title, 'MB Bank · 11:19 – 11:20');
    expect(h.body, kThanPhien);
    expect(h.subjectType, 'bienDong');
    expect(h.createdAt, _t(11, 19), reason: 'mốc của SỰ KIỆN — trung tâm sắp theo nó');
    expect(Uri.parse(h.deeplink!).queryParameters,
        {'date': '2026-10-03T11:19:00.000', 'nguon': 'MB Bank', 'phien': '2026-10-03T11:20:35.000', 'khoa': h.dedupeKey});
    expect(moc.values[id], _t(11, 20, 35));
    expect(kenh.datBatGoi.last, (true, _t(11, 20, 35)));
    expect(kenh.soLanHuy, 1);
  });

  test('hỏi sự kiện từ mốc lớn nhất trong (mốc, mốc bỏ qua, bây giờ − 7 ngày)', () async {
    kenh.boDenTra = _t(11, 10);
    await dung().nhap(id);
    expect(kenh.tuDaHoi.single, _t(11, 10));
    moc.values[id] = DateTime(2026, 9, 1);
    kenh
      ..boDenTra = null
      ..tuDaHoi.clear();
    await dung().nhap(id);
    expect(kenh.tuDaHoi.single, _t(12, 0).subtract(kLuiToiDa));
  });

  test('⭐ tin cùng nguồn trong cửa sổ (hàng loại 20 đang có) → không dòng; mốc vẫn tiến', () async {
    await themHang('bienDong:M1', _t(11, 19, 30));
    expect(await dung().nhap(id), 0);
    expect(await dongNhac(), isEmpty);
    expect(moc.values[id], _t(11, 20, 35), reason: 'đã xét — không xét lại ở lượt sau');
  });

  test('dòng nhắc (khoá bienDong:phien|) KHÔNG bao giờ là bằng chứng', () async {
    await themHang(dedupeKeyPhien(kNguonMb, _t(11, 18)), _t(11, 18));
    expect(await dung().nhap(id), 1);
  });

  test('⭐ giao dịch trong cửa sổ → không dòng; biết ví của nguồn thì giao dịch ví khác không tính', () async {
    gd = [(ngay: _t(11, 25), walletId: 'w-tm', walletTransfer: null)];
    expect(await dung().nhap(id), 0);

    moc.values[id] = _t(11, 0);
    viMb = 'w-mb';
    expect(await dung().nhap(id), 1, reason: 'mua bằng tiền mặt lúc ấy không phải giao dịch của MB');
  });

  test('gọi hai lần → không trùng (mốc đã tiến)', () async {
    expect(await dung().nhap(id), 1);
    expect(await dung().nhap(id), 0);
    expect(await dongNhac(), hasLength(1));
  });

  test('⭐ nút "Không có giao dịch" (mốc bỏ qua) che phiên rời trước nó', () async {
    kenh.boDenTra = _t(11, 20, 35);
    expect(await dung().nhap(id), 0);
  });

  test('phiên chưa kết thúc (rời < 3 phút) → chưa xét, mốc giữ nguyên', () async {
    expect(await dung(bayGio: _t(11, 22)).nhap(id), 0);
    expect(moc.values[id], _t(11, 0));
  });

  test('kênh ném → 0, không ném ra ngoài', () async {
    kenh.nem = true;
    expect(await dung().nhap(id), 0);
  });

  test('⭐ đăng xuất → mốc = bây giờ, cờ máy TẮT', () async {
    await dung().dongKhiDangXuat(id);
    expect(moc.values[id], _t(12, 0));
    expect(kenh.datBatGoi.last.$1, isFalse);
  });
}
