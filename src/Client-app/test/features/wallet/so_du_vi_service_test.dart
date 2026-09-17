/// `SoDuViService` — nơi **DUY NHẤT** ghi `wallets.balance`.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/services/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';

void main() {
  const acc = 7;
  const idVi = 'wallet-a';
  late AppDatabase db;
  late SoDuViService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = SoDuViService(db: db);
  });

  tearDown(() => db.close());

  Future<void> themVi({
    double soDu = 1000000,
    String loai = 'cash',
    String id = idVi,
  }) =>
      db.walletDao.insert(WalletsCompanion.insert(
        id: id,
        idaccount: acc,
        name: 'Ví',
        type: Value(loai),
        balance: Value(soDu),
        updatedAt: DateTime(2026, 9, 1),
      ));

  Future<void> themChi(String id, double soTien) =>
      db.transactionDao.insert(TransactionsCompanion.insert(
        id: id,
        walletId: idVi,
        idaccount: acc,
        amount: soTien,
        type: 'chi',
        date: DateTime(2026, 9, 10),
        updatedAt: DateTime(2026, 9, 10),
      ));

  Future<double> soDu([String id = idVi]) async =>
      (await db.walletDao.getById(id))!.balance;

  test('đặt neo rồi tính lại thì số dư KHÔNG đổi', () async {
    await themVi(soDu: 1000000);
    await service.datNeoNhieuVi({idVi});
    await service.tinhLaiSoDu(idVi);

    expect(await soDu(), 1000000,
        reason: 'Đặt neo rồi tính lại phải ra đúng con số đang có. Không có '
            'bước đặt neo thì công thức thiếu đúng phần neo và trả về 0 — mà '
            'MỌI ví trong bộ test đều dựng thẳng qua DAO nên không ví nào có '
            'neo sẵn.');

    final neo = await db.transactionDao.getById(idKhoanMoSo(idVi));
    expect(neo, isNotNull);
    expect(neo!.amount, 1000000);
    expect(neo.type, 'thu');
    expect(neo.categoryId, isNull);
    expect(
        laKhoanMoSo(
            loai: neo.type, categoryId: neo.categoryId, ghiChu: neo.note),
        isTrue,
        reason: 'Hàng sinh ra phải nhận lại được bằng chính phép hỏi duy nhất, '
            'nếu không nó sẽ lọt vào thống kê như một khoản thu thật.');
  });

  test('đặt neo LUỸ ĐẲNG — chạy hai lần chỉ một neo, số dư không nhân đôi',
      () async {
    await themVi(soDu: 1000000);
    await service.datNeoNhieuVi({idVi});
    await service.datNeoNhieuVi({idVi});
    await service.tinhLaiSoDu(idVi);

    expect(await soDu(), 1000000,
        reason: 'Hàm này chạy sau MỌI lần pull, nên tính luỹ đẳng là thứ tuyệt '
            'đối không được làm hỏng — cùng cảnh báo đã ghi cho '
            '`DefaultCategorySeeder`.');
  });

  test('sau khi có neo, số dư = neo + giao dịch', () async {
    await themVi(soDu: 1000000);
    await service.datNeoNhieuVi({idVi});
    await themChi('t1', 350000);
    await service.tinhLaiSoDu(idVi);

    expect(await soDu(), 650000);
  });

  test('số dư ban đầu ÂM thì neo là khoản CHI', () async {
    await themVi(soDu: -50000);
    await service.datNeoNhieuVi({idVi});
    await service.tinhLaiSoDu(idVi);

    final neo = await db.transactionDao.getById(idKhoanMoSo(idVi));
    expect(neo!.type, 'chi');
    expect(neo.amount, 50000,
        reason: 'Số tiền luôn DƯƠNG, chiều nằm ở `type` — đúng quy ước của '
            'bảng `transactions` và của `_applyBalances`.');
    expect(await soDu(), -50000);
  });

  test('số dư ban đầu 0 thì KHÔNG sinh neo', () async {
    await themVi(soDu: 0);
    await service.datNeoNhieuVi({idVi});
    await service.tinhLaiSoDu(idVi);

    expect(await db.transactionDao.getById(idKhoanMoSo(idVi)), isNull,
        reason: '`chk_transaction_nonzero_amount` của PostgreSQL bắt '
            '`Amount <> 0`, nên một khoản 0đ là bản ghi vỡ ở tầng CSDL rồi kẹt '
            'hàng đợi đẩy, im lặng.');
    expect(await soDu(), 0);
  });

  test('chênh dưới NỬA ĐỒNG thì không ghi lại', () async {
    await themVi(soDu: 1000000);
    await service.datNeoNhieuVi({idVi});
    await service.tinhLaiSoDu(idVi);
    final truoc = (await db.walletDao.getById(idVi))!.updatedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    await service.tinhLaiSoDu(idVi);
    final sau = (await db.walletDao.getById(idVi))!.updatedAt;

    expect(sau, truoc,
        reason: '`double` cộng dồn để lại đuôi lẻ. Ghi lại vô điều kiện là hàng '
            'ví luôn ở `pending` — đẩy lên rồi lại `pending` — một vòng lặp đẩy '
            'vô tận mà không có lỗi nào báo ra.');
  });

  test('ví BANKING bị BỎ QUA hoàn toàn', () async {
    await themVi(soDu: 1000000, loai: 'banking', id: 'w-bank');
    await service.datNeoNhieuVi({'w-bank'});
    await service.tinhLaiSoDu('w-bank');

    expect(await soDu('w-bank'), 1000000);
    expect(await db.transactionDao.getById(idKhoanMoSo('w-bank')), isNull,
        reason: 'Server tự ghi số dư ví ngân hàng từ SePay '
            '(`bank.worker.js:213`), và số dư ngân hàng thật có thể khác tổng '
            'sổ (phí, lãi, giao dịch chưa về). Tính lại và ghi đè là xoá đúng '
            'con số server vừa ghi.');
  });

  test('ví không tồn tại thì im lặng bỏ qua', () async {
    await service.tinhLaiSoDu('khong-co');
  });

  test('tinhLaiNhieuVi chạy mỗi ví đúng một lần, id trùng không sao', () async {
    await themVi(soDu: 1000000);
    await service.datNeoNhieuVi({idVi});
    await service.tinhLaiNhieuVi([idVi, idVi, idVi]);

    expect(await soDu(), 1000000);
  });

  test('tinhLaiSoDu KHÔNG được tự đặt neo — nếu không nó triệt tiêu khoản vừa ghi',
      () async {
    // Ví tiết kiệm số dư 0, chưa có neo (đúng: 0 thì không sinh neo nào).
    await themVi(soDu: 0);
    await service.datNeoNhieuVi({idVi});

    // Nhận 1.000.000 vào sổ.
    await db.transactionDao.insert(TransactionsCompanion.insert(
      id: 'nhan-1',
      walletId: idVi,
      idaccount: acc,
      amount: 1000000,
      type: 'thu',
      categoryId: const Value('cat-1'),
      date: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 10),
    ));
    await service.tinhLaiSoDu(idVi);

    expect(await soDu(), 1000000,
        reason: 'ĐÃ VẤP THẬT khi chạy bộ test: bản đầu cho `tinhLaiSoDu` tự đặt '
            'neo như một "lưới đỡ". Ví này chưa có neo (số dư 0 nên không sinh), '
            'nên sau khi nhận tiền, lưới đỡ ấy tính neo = balance(0) − Σ '
            'sổ(1.000.000) = −1.000.000 và sinh một khoản CHI triệt tiêu đúng '
            'khoản vừa nhận. Ví đứng im ở 0 và tiền biến mất.');
  });
}
