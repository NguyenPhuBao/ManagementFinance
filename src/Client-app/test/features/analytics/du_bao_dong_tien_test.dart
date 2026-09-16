/// Dự báo dòng tiền 30 ngày tới — tầng thuần (2026-09-16).
///
/// Spec: docs/superpowers/specs/2026-09-16-du-bao-dong-tien-design.md.
///
/// Canh chừng điều gì: mọi lỗi ở đây đều là một CON SỐ KHÁC trên màn hình,
/// không exception. Mười một bẫy ở §6 của spec, và luật chuyển ví §4.5: hoá
/// đơn trừ ví trả, trích tự động trừ ví nguồn và cộng ví đích — nên tác động
/// lên TỔNG của một khoản trích thường bằng 0, trừ khi ví đích không tính vào
/// tổng.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/bill/bill_recurrence.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/analytics/domain/du_bao_dong_tien.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/goal/data/models/goal_entity.dart';

/// Hôm nay 08/09/2026 trưa. Tầm nhìn tới hết 08/10.
final now = DateTime(2026, 9, 8, 12);

Wallet vi(
  String id,
  String ten, {
  double soDu = 10000000,
  bool tinhVaoTong = true,
  String status = 'active',
  bool daXoa = false,
}) =>
    Wallet(
      id: id,
      idaccount: 1,
      name: ten,
      type: 'cash',
      balance: soDu,
      currency: 'VND',
      icon: 'wallet',
      colour: '#4CAF50',
      isDefault: false,
      isDeleted: daXoa,
      includeInTotal: tinhVaoTong,
      status: status,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 1, 1),
    );

Bill hoaDon(
  String id, {
  required DateTime han,
  DateTime? ketThucKy,
  int? anchorDay,
  double soTien = 800000,
  String? vi = 'w1',
  String? danhMuc = 'c_dien',
  bool lap = true,
  String chuKy = kBillCycleMonth,
  String payStatus = 'Pending',
  bool isPaid = false,
  String? sinhTu,
  String ten = 'Tiền điện',
}) =>
    Bill(
      id: id,
      idaccount: 1,
      walletId: vi,
      categoryId: danhMuc,
      name: ten,
      amount: soTien,
      startDate: DateTime(han.year, han.month - 1, han.day),
      periodEnd: ketThucKy,
      dueDate: han,
      anchorDay: anchorDay,
      payStatus: payStatus,
      isPaid: isPaid,
      autoPayEnabled: false,
      timeNotification: '3',
      isRecurrence: lap,
      timeRecurrence: chuKy,
      recurrence: 'monthly',
      generatedFromBillId: sinhTu,
      icon: 'receipt',
      colour: '#4CAF50',
      note: '',
      isDeleted: false,
      syncStatus: 'synced',
      syncRetryCount: 0,
      updatedAt: DateTime(2026, 1, 1),
    );

GoalEntity mucTieu(
  String id, {
  required double soTienTrich,
  String? viNguon = 'w1',
  String? viDich = 'w_tk',
  DateTime? mocNeo,
  DateTime? lanChay,
  String chuKy = 'Month',
  double target = 50000000,
  double current = 0,
  String ten = 'Mua xe',
}) =>
    GoalEntity(
      id: id,
      idaccount: 1,
      name: ten,
      targetAmount: target,
      currentAmount: current,
      targetDate: DateTime(2028, 1, 1),
      walletId: viDich,
      cycleTakeMoney: chuKy,
      timeCycleTakeMoney: mocNeo,
      autoDepositAmount: soTienTrich,
      autoDepositWalletId: viNguon,
      autoDepositLastRun: lanChay ?? DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

BudgetView nganSach(
  String id, {
  required double hanMuc,
  required double daChi,
  String? danhMuc = 'c_dien',
  DateTime? batDau,
  String? chuKy = BudgetRecurrence.month,
  DateTime? ketThuc,
}) =>
    BudgetView(
      budget: BudgetEntity(
        id: id,
        idaccount: 1,
        categoryId: danhMuc,
        amount: hanMuc,
        spent: daChi,
        startDate: batDau ?? DateTime(2026, 9, 1),
        endDate: ketThuc,
        recurrence: true,
        timeRecurrence: chuKy,
        updatedAt: DateTime(2026, 1, 1),
      ),
      categoryName: 'Điện nước',
    );

/// Tên khác `vi` để không đụng tham số cùng tên của [duBao].
Wallet vi_(String id, String ten, {double soDu = 10000000}) =>
    vi(id, ten, soDu: soDu);

DuBaoDongTien duBao({
  List<Bill> hoaDon = const [],
  List<GoalEntity> mucTieu = const [],
  List<BudgetView> nganSach = const [],
  List<Wallet>? vi,
  DateTime? luc,
}) =>
    duBaoCua(
      now: luc ?? now,
      hoaDon: hoaDon,
      mucTieu: mucTieu,
      nganSach: nganSach,
      vi: vi ?? [vi_('w1', 'Tiền mặt')],
    )!;

void main() {
  group('không có gì', () {
    test('không có ví thì null — không có thang đo', () {
      expect(
        duBaoCua(
            now: now,
            hoaDon: const [],
            mucTieu: const [],
            nganSach: const [],
            vi: const []),
        isNull,
      );
    });

    test('ví toàn hàng đã xoá mềm cũng là không có ví', () {
      expect(
        duBaoCua(
            now: now,
            hoaDon: const [],
            mucTieu: const [],
            nganSach: const [],
            vi: [vi('w1', 'Cũ', daXoa: true)]),
        isNull,
      );
    });

    test('có ví, không cam kết: ba con số bằng số dư, chuỗi phẳng 31 điểm', () {
      final d = duBao();
      expect(d.tu, DateTime(2026, 9, 8), reason: 'đầu ngày, không phải 12:00');
      expect(d.soDuHienTai, 10000000);
      expect(d.camKet, isEmpty);
      expect(d.tongCamKet, 0);
      expect(d.conTieuDuoc, 10000000);
      expect(d.nganSachConLai, 0);
      expect(d.coNganSach, isFalse);
      expect(d.conTieuDuocTheoNganSach, 10000000);
      expect(d.viThieu, isEmpty);
      expect(d.chuoi.length, 31, reason: 'hôm nay + 30 ngày = 31 điểm');
      expect(d.chuoi.first.ngay, DateTime(2026, 9, 8));
      expect(d.chuoi.last.ngay, DateTime(2026, 10, 8));
      expect(d.chuoi.every((p) => p.chacChan == 10000000), isTrue);
    });
  });

  group('số dư hiện tại', () {
    test(
        'cộng qua viTinhVaoTong: bỏ ví không tính vào tổng, bỏ ví lưu trữ, bỏ ví đã xoá mềm',
        () {
      final d = duBao(vi: [
        vi_('w1', 'Tiền mặt', soDu: 1000000),
        vi('w2', 'Quỹ đen', soDu: 5000000, tinhVaoTong: false),
        vi('w3', 'Ví cũ', soDu: 3000000, status: 'inactive'),
        vi('w4', 'Đã xoá', soDu: 7000000, daXoa: true),
      ]);
      expect(d.soDuHienTai, 1000000,
          reason: 'Cùng luật Trang chủ. Ví đã xoá mềm còn balance thì '
              'không phải tiền của người dùng nữa.');
    });
  });

  group('hoá đơn → cam kết', () {
    test('hoá đơn tới hạn trong 30 ngày là một cam kết, trừ đúng số tiền', () {
      final d =
          duBao(hoaDon: [hoaDon('b1', han: DateTime(2026, 9, 20), lap: false)]);
      expect(d.camKet.length, 1);
      final c = d.camKet.single;
      expect(c.ngay, DateTime(2026, 9, 20));
      expect(c.ten, 'Tiền điện');
      expect(c.loai, LoaiCamKet.hoaDon);
      expect(c.walletId, 'w1');
      expect(c.tenVi, 'Tiền mặt');
      expect(c.soTien, 800000);
      expect(c.categoryId, 'c_dien');
      expect(c.quaHan, isFalse);
      expect(c.laKyChieu, isFalse);
      expect(c.tacDongTong, -800000);
      expect(d.tongCamKet, 800000);
      expect(d.conTieuDuoc, 9200000);
    });

    test(
        'hoá đơn quá hạn chưa trả DỒN VỀ HÔM NAY, cờ quaHan, và nằm ở ĐIỂM 0 của chuỗi',
        () {
      final d =
          duBao(hoaDon: [hoaDon('b1', han: DateTime(2026, 8, 20), lap: false)]);
      final c = d.camKet.single;
      expect(c.ngay, DateTime(2026, 9, 8));
      expect(c.quaHan, isTrue);
      expect(d.chuoi.first.chacChan, 9200000,
          reason: 'Bẫy 7: lệch một ô ở điểm 0 là cam kết hôm nay bị bỏ khỏi '
              'điểm đầu — "!isAfter", không phải "isBefore".');
    });

    test('hạn NGOÀI 30 ngày thì không phải cam kết', () {
      final d =
          duBao(hoaDon: [hoaDon('b1', han: DateTime(2026, 10, 9), lap: false)]);
      expect(d.camKet, isEmpty, reason: '08/10 là ngày cuối, 09/10 ngoài');
    });

    test('hạn ĐÚNG ngày cuối vẫn tính, kể cả khi giờ trên hạn là 23:00', () {
      final d = duBao(
          hoaDon: [hoaDon('b1', han: DateTime(2026, 10, 8, 23), lap: false)]);
      expect(d.camKet.length, 1,
          reason: 'Bẫy 6: so theo NGÀY, không theo thời điểm.');
    });

    test('đã trả, đã bỏ qua, không ví, số tiền 0 — đều không phải cam kết', () {
      final d = duBao(hoaDon: [
        hoaDon('b1',
            han: DateTime(2026, 9, 20), isPaid: true, payStatus: 'Payed'),
        hoaDon('b2', han: DateTime(2026, 9, 21), payStatus: 'Skipped'),
        hoaDon('b3', han: DateTime(2026, 9, 22), vi: null),
        hoaDon('b4', han: DateTime(2026, 9, 23), soTien: 0),
      ]);
      expect(d.camKet, isEmpty);
    });

    test('hoá đơn LẶP chiếu tiếp các kỳ tương lai trong 30 ngày, cờ laKyChieu',
        () {
      // Hạn 10/09, chu kỳ tuần → 10/09 (thật), 17, 24, 01/10, 08/10 (chiếu).
      final d = duBao(hoaDon: [
        hoaDon('b1',
            han: DateTime(2026, 9, 10),
            ketThucKy: DateTime(2026, 9, 10),
            chuKy: kBillCycleWeek),
      ]);
      expect(d.camKet.map((c) => c.ngay).toList(), [
        DateTime(2026, 9, 10),
        DateTime(2026, 9, 17),
        DateTime(2026, 9, 24),
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 8),
      ]);
      expect(d.camKet.first.laKyChieu, isFalse);
      expect(d.camKet.skip(1).every((c) => c.laKyChieu), isTrue);
      expect(d.tongCamKet, 5 * 800000);
    });

    test('⚠️ kỳ chiếu nối từ KẾT THÚC KỲ, giữ ân hạn — không nối từ hạn trả',
        () {
      // Kỳ 01/08–01/09, hạn 06/09 (ân hạn 5, đã quá hạn). Kỳ sau: kết thúc
      // 01/10, hạn 06/10 — trong 30 ngày. Bản sai nối từ hạn trả 06/09 →
      // kết thúc 06/10, hạn 11/10 → NGOÀI, kỳ ấy biến mất.
      final d = duBao(hoaDon: [
        hoaDon('b1',
            han: DateTime(2026, 9, 6),
            ketThucKy: DateTime(2026, 9, 1),
            anchorDay: 1),
      ]);
      expect(d.camKet.map((c) => c.ngay).toList(), [
        DateTime(2026, 9, 8), // kỳ quá hạn dồn về hôm nay
        DateTime(2026, 10, 6),
      ],
          reason:
              'Bẫy 2: nối từ hạn trả là hở đúng số ngày ân hạn, kỳ 06/10 biến mất.');
    });

    test('⚠️ anchorDay 31 đi theo chuỗi chiếu, không cộng dồn', () {
      // Hôm nay 31/01/2028 (năm nhuận). Hạn 31/01 tới hạn hôm nay; kỳ chiếu
      // 29/02 (kẹp). Kỳ sau nữa 31/03 — ngoài 30 ngày.
      final d = duBaoCua(
        now: DateTime(2028, 1, 31, 12),
        hoaDon: [
          hoaDon('b1',
              han: DateTime(2028, 1, 31),
              ketThucKy: DateTime(2028, 1, 31),
              anchorDay: 31),
        ],
        mucTieu: const [],
        nganSach: const [],
        vi: [vi_('w1', 'Tiền mặt')],
      )!;
      expect(d.camKet.map((c) => c.ngay).toList(), [
        DateTime(2028, 1, 31),
        DateTime(2028, 2, 29),
      ]);
    });

    test(
        'chỉ chiếu từ HÀNG CUỐI CHUỖI — hàng đã sinh kỳ sau thì kỳ sau tự có mặt',
        () {
      // b1 (hạn 10/09, chưa trả) đã sinh b2 (hạn 10/10, ngoài tầm nhìn).
      final d = duBao(hoaDon: [
        hoaDon('b1',
            han: DateTime(2026, 9, 10),
            ketThucKy: DateTime(2026, 9, 10),
            anchorDay: 10),
        hoaDon('b2',
            han: DateTime(2026, 10, 10),
            ketThucKy: DateTime(2026, 10, 10),
            anchorDay: 10,
            sinhTu: 'b1'),
      ]);
      expect(d.camKet.map((c) => c.ngay).toList(), [DateTime(2026, 9, 10)],
          reason: 'b1 đã có con nên không chiếu tiếp; b2 ngoài 30 ngày nên '
              'không hiện. Không kỳ chiếu nào được chen vào.');
    });

    test('hoá đơn không lặp thì không chiếu gì', () {
      final d = duBao(hoaDon: [
        hoaDon('b1',
            han: DateTime(2026, 9, 10), chuKy: kBillCycleWeek, lap: false)
      ]);
      expect(d.camKet.length, 1);
    });

    test('chu kỳ lạ (backend thêm giá trị mới) thì dừng chiếu, không lặp vô hạn',
        () {
      final d = duBao(
          hoaDon: [hoaDon('b1', han: DateTime(2026, 9, 10), chuKy: 'Fortnight')]);
      expect(d.camKet.length, 1,
          reason:
              'nextBillDueDate trả nguyên mốc → hạn không tiến → dừng vòng lặp');
    });

    test(
        'hoá đơn trỏ ví lưu trữ: vẫn là cam kết, nhưng tác động lên tổng bằng 0',
        () {
      final d = duBao(
        vi: [vi_('w1', 'Tiền mặt'), vi('w_cu', 'Ví cũ', status: 'inactive')],
        hoaDon: [
          hoaDon('b1', han: DateTime(2026, 9, 20), vi: 'w_cu', lap: false)
        ],
      );
      expect(d.camKet.single.tacDongTong, 0, reason: 'Bẫy 9');
      expect(d.conTieuDuoc, 10000000);
    });

    test('sắp theo ngày rồi theo tên', () {
      final d = duBao(hoaDon: [
        hoaDon('b1', han: DateTime(2026, 9, 25), lap: false, ten: 'Nước'),
        hoaDon('b2', han: DateTime(2026, 9, 20), lap: false, ten: 'Điện'),
        hoaDon('b3', han: DateTime(2026, 9, 25), lap: false, ten: 'Internet'),
      ]);
      expect(d.camKet.map((c) => c.ten).toList(), ['Điện', 'Internet', 'Nước']);
    });
  });

  group('ví thiếu', () {
    test(
        'ví không đủ trả cam kết của chính nó: ngày đầu tiên âm và số thiếu lớn nhất',
        () {
      final d = duBao(
        vi: [
          vi_('w1', 'Tiền mặt', soDu: 1000000),
          vi_('w2', 'Ngân hàng', soDu: 20000000)
        ],
        hoaDon: [
          hoaDon('b1',
              han: DateTime(2026, 9, 15), soTien: 700000, lap: false),
          hoaDon('b2',
              han: DateTime(2026, 9, 25), soTien: 800000, lap: false),
        ],
      );
      expect(d.conTieuDuoc, 19500000, reason: 'tổng thì vẫn dư');
      expect(d.viThieu.length, 1);
      expect(d.viThieu.single.walletId, 'w1');
      expect(d.viThieu.single.ten, 'Tiền mặt');
      expect(d.viThieu.single.ngay, DateTime(2026, 9, 25),
          reason: 'sau b1 còn 300k, sau b2 mới âm');
      expect(d.viThieu.single.thieu, 500000);
    });

    test('đuôi lẻ double dưới nửa đồng KHÔNG báo thiếu', () {
      final d = duBao(
        vi: [vi_('w1', 'Tiền mặt', soDu: 0.3)],
        hoaDon: [
          hoaDon('b1', han: DateTime(2026, 9, 15), soTien: 0.6, lap: false)
        ],
      );
      expect(d.viThieu, isEmpty);
    });

    test('ví lưu trữ không báo thiếu — người dùng đã cất nó đi', () {
      final d = duBao(
        vi: [
          vi_('w1', 'Tiền mặt'),
          vi('w_cu', 'Ví cũ', soDu: 0, status: 'inactive')
        ],
        hoaDon: [
          hoaDon('b1', han: DateTime(2026, 9, 20), vi: 'w_cu', lap: false)
        ],
      );
      expect(d.viThieu, isEmpty, reason: 'Bẫy 9');
    });
  });

  group('chuỗi 31 điểm', () {
    test('bậc thang: trừ mỗi cam kết ĐÚNG MỘT LẦN tại ngày của nó', () {
      final d = duBao(hoaDon: [
        hoaDon('b1', han: DateTime(2026, 9, 10), soTien: 1000000, lap: false),
        hoaDon('b2', han: DateTime(2026, 9, 20), soTien: 2000000, lap: false),
      ]);
      double tai(int i) => d.chuoi[i].chacChan;
      expect(tai(0), 10000000);
      expect(tai(1), 10000000, reason: '09/09 chưa có gì');
      expect(tai(2), 9000000, reason: '10/09 trừ b1');
      expect(tai(11), 9000000, reason: '19/09');
      expect(tai(12), 7000000, reason: '20/09 trừ b2');
      expect(tai(30), 7000000);
    });

    test('được phép ÂM, không kẹp về 0', () {
      final d = duBao(
        vi: [vi_('w1', 'Tiền mặt', soDu: 500000)],
        hoaDon: [
          hoaDon('b1', han: DateTime(2026, 9, 10), soTien: 800000, lap: false)
        ],
      );
      expect(d.conTieuDuoc, -300000);
      expect(d.chuoi.last.chacChan, -300000);
    });

    test('chuoiDuBao công khai cho widget test dựng dữ liệu', () {
      final ds = chuoiDuBao(
        homNay: DateTime(2026, 9, 8),
        soDu: 100,
        camKet: const [],
        nganSachConLai: 30,
      );
      expect(ds.length, 31);
      expect(ds[0].theoNganSach, 100);
      expect(ds[15].theoNganSach, closeTo(85, 1e-9),
          reason: 'ngân sách rải đều: 30 × 15/30');
      expect(ds[30].theoNganSach, 70);
    });
  });
}
