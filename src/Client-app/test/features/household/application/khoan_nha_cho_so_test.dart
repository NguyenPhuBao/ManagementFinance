/// Bảng tra tên + quyền cho khoản nhà hiện ở Sổ / Trang chủ (spec 2026-11-16 mục 3).
library;

import 'dart:async';

import 'package:flowmoney/features/household/application/khoan_nha_cho_so.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/transaction/data/khoan_nha_cho_so_nguon.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/household_api_gia.dart';
import '../../../helpers/nha_gia.dart';
import '../../category/presentation/category_test_fakes.dart';

Future<NhaCuaToi> nhaThu({int id = 12, String myRole = 'Owner', String status = 'Active'}) async =>
    (await repoNhaThu(HouseholdApiGia()..cuaToiJson = nhaJson(id: id, myRole: myRole, status: status))).hienTai;

TransactionEntity khoan({int? nha = 12, int idaccount = 18}) => TransactionEntity(
      id: 'k',
      walletId: 'nha-v',
      idaccount: idaccount,
      idhousehold: nha,
      amount: 1000,
      type: 'chi',
      date: DateTime(2026, 11, 16),
      updatedAt: DateTime(2026, 11, 16),
    );

void main() {
  test('không ở nhà → phát bảng rỗng', () async {
    final s = theoDoiTraTenNha(
      nha: Stream.value(NhaCuaToi.khongCo(DateTime(2026))),
      viChung: (_) => const Stream.empty(),
      danhMuc: (_) => const Stream.empty(),
      idaccount: 18,
    );
    final t = await s.first;
    expect(t.idNha, isNull);
    expect(t.tenTheoId, isEmpty);
  });

  test('có nhà → tên nhà, ví chung của nhà ấy, bảng tra danh mục của tôi', () async {
    final n = await nhaThu();
    final viNha = makeWallet(id: 'nha-v', name: 'Tiền chợ');
    final dm = makeCategory(id: 'nha-food', name: 'Ăn uống');
    final goiVi = <int>[];
    final s = theoDoiTraTenNha(
      nha: Stream.value(n),
      viChung: (id) {
        goiVi.add(id);
        return Stream.value([viNha]);
      },
      danhMuc: (_) => Stream.value([dm]),
      idaccount: 18,
    );
    final cuoi = await s.firstWhere((t) => t.vi.isNotEmpty && t.danhMuc.isNotEmpty);
    expect(cuoi.idNha, 12);
    expect(cuoi.tenTheoId, {12: 'Nhà An – Bình'});
    expect(cuoi.vi.single.id, 'nha-v');
    expect(cuoi.danhMuc.single.id, 'nha-food');
    expect(goiVi, [12]);
  });

  test('nhà đổi 12 → 13: huỷ stream ví nhà cũ, stream nhà MỚI vẫn sống', () async {
    final a = await nhaThu();
    final b = await nhaThu(id: 13);
    final nha = StreamController<NhaCuaToi>();
    final viCu = StreamController<List<WalletEntity>>();
    final viMoi = StreamController<List<WalletEntity>>();
    var huyCu = 0;
    var huyMoi = 0;
    viCu.onCancel = () => huyCu++;
    viMoi.onCancel = () => huyMoi++;
    final ra = <TraTenNha>[];
    final sub = theoDoiTraTenNha(
      nha: nha.stream,
      viChung: (id) => id == 12 ? viCu.stream : viMoi.stream,
      danhMuc: (_) => const Stream.empty(),
      idaccount: 18,
    ).listen(ra.add);
    nha.add(a);
    await pumpEventQueue();
    nha.add(b);
    await pumpEventQueue();
    expect(huyCu, 1);
    expect(huyMoi, 0, reason: 'huỷ sau một await là huỷ nhầm stream của nhà mới vừa gán');
    viMoi.add([makeWallet(id: 'v13', name: 'Quỹ 13')]);
    await pumpEventQueue();
    expect(ra.last.idNha, 13);
    expect(ra.last.vi.single.id, 'v13');
    await sub.cancel();
    expect(huyMoi, 1, reason: 'huỷ người nghe ngoài → huỷ cả stream trong');
  });

  test('quyền: Chủ nhà sửa / xoá khoản của mình; Chỉ xem không gì; khoản của nhà khác không gì', () async {
    expect(quyenKhoanNhaTuSo(khoan(), nha: await nhaThu(), idToi: 18), (sua: true, xoa: true));
    expect(quyenKhoanNhaTuSo(khoan(), nha: await nhaThu(myRole: 'Viewer'), idToi: 18), (sua: false, xoa: false));
    expect(quyenKhoanNhaTuSo(khoan(nha: 99), nha: await nhaThu(), idToi: 18), (sua: false, xoa: false));
  });

  test('cổng: lỗi đọc quyền → không sửa / xoá', () async {
    final c = KhoanNhaChoSoNguon(
      traTen: (_) => const Stream.empty(),
      quyen: (_) async => throw StateError('hỏng'),
      xoa: (_) async {},
    );
    expect(await c.quyen(khoan()), (sua: false, xoa: false));
  });

  test('cổng: lỗi stream tra tên bị nuốt, không đỏ màn', () async {
    final c = KhoanNhaChoSoNguon(
      traTen: (_) => Stream<TraTenNha>.error(StateError('hỏng')),
      quyen: (_) async => (sua: false, xoa: false),
      xoa: (_) async {},
    );
    expect(await c.traTen(18).toList(), isEmpty);
  });
}
