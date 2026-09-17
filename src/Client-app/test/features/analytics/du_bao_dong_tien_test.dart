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
import 'package:flowmoney/features/analytics/domain/thong_ke_thang.dart';
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

  group('mục tiêu trích tự động → cam kết', () {
    // Ví đích w_tk tính vào tổng → tác động lên tổng = 0.
    final haiVi = [vi_('w1', 'Tiền mặt'), vi_('w_tk', 'Tiết kiệm', soDu: 0)];

    test(
        'kỳ tương lai trong 30 ngày là cam kết: trừ ví nguồn, cộng ví đích, tổng không đổi',
        () {
      final d = duBao(
        vi: haiVi,
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              lanChay: DateTime(2026, 9, 1))
        ],
      );
      expect(d.camKet.length, 1, reason: '15/09 trong; 15/10 ngoài 08/10');
      final c = d.camKet.single;
      expect(c.ngay, DateTime(2026, 9, 15));
      expect(c.ten, 'Mua xe');
      expect(c.loai, LoaiCamKet.trichTuDong);
      expect(c.walletId, 'w1');
      expect(c.viNhanId, 'w_tk');
      expect(c.soTien, 500000);
      expect(c.categoryId, isNull);
      expect(c.laKyChieu, isTrue);
      expect(c.quaHan, isFalse);
      expect(c.tacDongTong, 0,
          reason: 'Bẫy 5: đích tính vào tổng → 0 ròng');
      expect(d.conTieuDuoc, 10000000);
    });

    test('⚠️ ví đích KHÔNG tính vào tổng thì khoản trích trừ thật', () {
      final d = duBao(
        vi: [
          vi_('w1', 'Tiền mặt'),
          vi('w_tk', 'Tiết kiệm', soDu: 0, tinhVaoTong: false)
        ],
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              lanChay: DateTime(2026, 9, 1))
        ],
      );
      expect(d.camKet.single.tacDongTong, -500000);
      expect(d.conTieuDuoc, 9500000,
          reason: 'Bẫy 5: quên nhánh này là mọi khoản trích ra 0 ròng');
    });

    test('mục tiêu chưa gán ví đích: trừ thật ở nguồn, không ví nhận', () {
      final d = duBao(
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              viDich: null,
              mocNeo: DateTime(2026, 9, 15, 8))
        ],
      );
      expect(d.camKet.single.viNhanId, isNull);
      expect(d.camKet.single.tacDongTong, -500000);
    });

    test('kỳ đã tới hạn chưa trích dồn về HÔM NAY, kỳ tương lai giữ ngày', () {
      // Mốc neo ngày 5 08:00, sàn 01/08 → 05/08 và 05/09 đã tới hạn (hôm nay
      // 08/09), 05/10 tương lai.
      final d = duBao(
        vi: haiVi,
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 8, 5, 8),
              lanChay: DateTime(2026, 8, 1))
        ],
      );
      expect(d.camKet.map((c) => c.ngay).toList(), [
        DateTime(2026, 9, 8),
        DateTime(2026, 9, 8),
        DateTime(2026, 10, 5),
      ]);
    });

    test(
        'mốc rơi vào chiều nay (sau `now`) vẫn là hôm nay; và mốc MANG GIỜ ở ngày cuối không bị cắt',
        () {
      final d = duBao(
        vi: haiVi,
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 8, 20),
              lanChay: DateTime(2026, 9, 1))
        ],
      );
      expect(d.camKet.map((c) => c.ngay).toList(), [
        DateTime(2026, 9, 8),
        DateTime(2026, 10, 8),
      ],
          reason: 'Kỳ 08/10 20:00 nằm trong ngày cuối của tầm nhìn. So thời '
              'điểm với mốc 08/10 00:00 sẽ cắt mất nó — một kỳ biến mất, im '
              'lặng; vì thế biên là `sauCuoi` (mở, 09/10 00:00).');
    });

    test('kẹp ở phần còn thiếu và DỪNG khi mục tiêu đầy', () {
      // Còn thiếu 700k, trích 500k mỗi tuần → 500k rồi 200k rồi dừng.
      final d = duBao(
        vi: haiVi,
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              chuKy: 'Week',
              target: 1000000,
              current: 300000,
              mocNeo: DateTime(2026, 9, 10, 8),
              lanChay: DateTime(2026, 9, 1))
        ],
      );
      expect(d.camKet.map((c) => c.soTien).toList(), [500000, 200000]);
    });

    test(
        'không bật, đã xong, ví nguồn lưu trữ / không tồn tại / trùng ví đích — đều bỏ',
        () {
      final d = duBao(
        vi: [
          vi_('w1', 'Tiền mặt'),
          vi_('w_tk', 'Tiết kiệm', soDu: 0),
          vi('w_cu', 'Cũ', status: 'inactive')
        ],
        mucTieu: [
          // Chưa bật: `autoDepositLastRun` null. Dựng thẳng vì `copyWith`
          // dùng `??` nên không đặt được null.
          GoalEntity(
            id: 'g1',
            idaccount: 1,
            name: 'Chưa bật',
            targetAmount: 1000000,
            targetDate: DateTime(2028, 1, 1),
            walletId: 'w_tk',
            cycleTakeMoney: 'Month',
            timeCycleTakeMoney: DateTime(2026, 9, 15, 8),
            autoDepositAmount: 500000,
            autoDepositWalletId: 'w1',
            autoDepositLastRun: null,
            updatedAt: DateTime(2026, 1, 1),
          ),
          mucTieu('g2',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              current: 50000000),
          mucTieu('g3',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              viNguon: 'w_cu'),
          mucTieu('g4',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              viNguon: 'w_khong_co'),
          mucTieu('g5',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              viNguon: 'w_tk'),
        ],
      );
      expect(d.camKet, isEmpty);
    });

    test('không mốc neo thì nhịp bám vào lần chạy gần nhất — hành vi bản cũ',
        () {
      final d = duBao(
        vi: haiVi,
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              mocNeo: null,
              lanChay: DateTime(2026, 8, 20, 9))
        ],
      );
      expect(d.camKet.single.ngay, DateTime(2026, 9, 20));
    });

    test('mốc neo rác (năm 1990, chu kỳ ngày) không treo — bỏ mục tiêu ấy', () {
      final d = duBao(
        vi: haiVi,
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              chuKy: 'Day',
              mocNeo: DateTime(1990, 1, 1),
              lanChay: DateTime(2026, 9, 1))
        ],
      );
      expect(d.camKet, isEmpty);
    });

    test('ví thiếu tính cả tiền VÀO từ trích tự động', () {
      // w_tk có 0, nhận 500k ngày 15/09, rồi hoá đơn 400k từ w_tk ngày 20/09
      // → không thiếu.
      final d = duBao(
        vi: haiVi,
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              lanChay: DateTime(2026, 9, 1))
        ],
        hoaDon: [
          hoaDon('b1',
              han: DateTime(2026, 9, 20),
              soTien: 400000,
              vi: 'w_tk',
              lap: false)
        ],
      );
      expect(d.viThieu, isEmpty);
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

  group('ngân sách → tầng 2', () {
    // Ngân sách tháng 9 (01/09 → 01/10). Hôm nay 08/09 12:00 → daysLeft = 23
    // (< 30) → tính trọn phần còn lại.

    test('phần còn lại của ngân sách danh mục là tầng 2; tầng 1 không đổi', () {
      final d = duBao(nganSach: [nganSach('ns1', hanMuc: 3000000, daChi: 1000000)]);
      expect(d.tongCamKet, 0);
      expect(d.nganSachConLai, 2000000);
      expect(d.coNganSach, isTrue);
      expect(d.conTieuDuocTheoNganSach, 8000000);
      expect(d.chuoi.last.theoNganSach, 8000000);
      expect(d.chuoi.first.theoNganSach, 10000000,
          reason: 'rải đều: điểm 0 chưa trừ gì');
    });

    test(
        '⚠️ KHÔNG ĐẾM ĐÔI: hoá đơn cùng danh mục trừ khỏi phần còn lại của ngân sách',
        () {
      final d = duBao(
        hoaDon: [
          hoaDon('b1',
              han: DateTime(2026, 9, 20),
              soTien: 800000,
              danhMuc: 'c_dien',
              lap: false)
        ],
        nganSach: [
          nganSach('ns1', hanMuc: 3000000, daChi: 1000000, danhMuc: 'c_dien')
        ],
      );
      expect(d.tongCamKet, 800000);
      expect(d.nganSachConLai, 1200000,
          reason: 'Bẫy 4: 800k tiền điện nằm ở tầng 1 VÀ trong "còn lại" của '
              'ngân sách Điện nước.');
      expect(d.conTieuDuocTheoNganSach, 8000000);
    });

    test('hoá đơn KHÁC danh mục không trừ', () {
      final d = duBao(
        hoaDon: [
          hoaDon('b1',
              han: DateTime(2026, 9, 20),
              soTien: 800000,
              danhMuc: 'c_nuoc',
              lap: false)
        ],
        nganSach: [
          nganSach('ns1', hanMuc: 3000000, daChi: 1000000, danhMuc: 'c_dien')
        ],
      );
      expect(d.nganSachConLai, 2000000);
    });

    test('hoá đơn vượt phần còn lại thì kẹp về 0, không âm', () {
      final d = duBao(
        hoaDon: [
          hoaDon('b1',
              han: DateTime(2026, 9, 20), soTien: 5000000, lap: false)
        ],
        nganSach: [nganSach('ns1', hanMuc: 3000000, daChi: 1000000)],
      );
      expect(d.nganSachConLai, 0);
      expect(d.coNganSach, isFalse);
    });

    test('ngân sách TỔNG (categoryId null) đè ngân sách danh mục, trừ MỌI hoá đơn',
        () {
      final d = duBao(
        hoaDon: [
          hoaDon('b1',
              han: DateTime(2026, 9, 20),
              soTien: 800000,
              danhMuc: 'c_nuoc',
              lap: false)
        ],
        nganSach: [
          nganSach('tong', hanMuc: 10000000, daChi: 4000000, danhMuc: null),
          nganSach('ns1', hanMuc: 3000000, daChi: 1000000, danhMuc: 'c_dien'),
        ],
      );
      expect(d.nganSachConLai, 5200000,
          reason: '6.000.000 − 800.000; ngân sách Điện không cộng thêm');
    });

    test('ngân sách QUÝ còn 60 ngày chỉ tính nửa — giả định tiêu đều', () {
      // Quý 08/08 → 08/11; hôm nay 08/09 12:00 → còn ~60 ngày.
      final d = duBao(nganSach: [
        nganSach('q',
            hanMuc: 6000000,
            daChi: 0,
            batDau: DateTime(2026, 8, 8),
            chuKy: BudgetRecurrence.quarter),
      ]);
      expect(d.nganSachConLai, closeTo(3000000, 60000),
          reason: '6.000.000 × 30/60 — mượn suggestedPerDay của budgetPaceOf');
    });

    test('ngân sách đã tiêu vượt đóng góp 0', () {
      final d = duBao(nganSach: [nganSach('ns1', hanMuc: 1000000, daChi: 1500000)]);
      expect(d.nganSachConLai, 0);
    });

    test('ngân sách hết hạn, chưa bắt đầu, hoặc kỳ không chứa hôm nay — bỏ', () {
      final d = duBao(nganSach: [
        nganSach('het',
            hanMuc: 3000000,
            daChi: 0,
            batDau: DateTime(2026, 6, 1),
            ketThuc: DateTime(2026, 7, 1)),
        nganSach('sau',
            hanMuc: 3000000, daChi: 0, batDau: DateTime(2026, 10, 1)),
      ]);
      expect(d.nganSachConLai, 0);
    });

    test('trích tự động KHÔNG trừ khỏi ngân sách — nó là transfer', () {
      final d = duBao(
        vi: [vi_('w1', 'Tiền mặt'), vi_('w_tk', 'Tiết kiệm', soDu: 0)],
        mucTieu: [
          mucTieu('g1',
              soTienTrich: 500000,
              mocNeo: DateTime(2026, 9, 15, 8),
              lanChay: DateTime(2026, 9, 1))
        ],
        nganSach: [
          nganSach('tong', hanMuc: 3000000, daChi: 1000000, danhMuc: null)
        ],
      );
      expect(d.nganSachConLai, 2000000);
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

    test('⚠️ dải trục CO theo dữ liệu, và bốn nhãn phải ĐÔI MỘT KHÁC NHAU', () {
      // Ca thật đo trên máy ảo 2026-09-16: số dư 13.590.000, cả 30 ngày chỉ
      // trừ 388.000 (2,8%). Trục từ 0 thì đường nằm phẳng sát đỉnh, không
      // thấy bậc nào — người dùng chốt co trục.
      final (:san, :buoc) = daiTrucDuBao(const [13590000, 13202000]);

      expect(san, greaterThan(13000000),
          reason: 'co theo dải, không chạy từ 0');
      expect(san, lessThan(13202000), reason: 'đáy chuỗi phải nằm trong dải');
      expect(san + buoc * 3, greaterThan(13590000),
          reason: 'đỉnh chuỗi phải nằm trong dải');
    });

    test('⚠️ dải RẤT hẹp vẫn cho bốn nhãn khác nhau — họ G39', () {
      // Cam kết 50.000 trên số dư 13.590.000: dải 1,3× là 65.000, bước 21.667
      // → `rutGon` một chữ số lẻ in ra "13.6M" BỐN LẦN. Dải phải tự nới.
      final (:san, :buoc) = daiTrucDuBao(const [13590000, 13540000]);
      final nhan = [for (var k = 0; k < 4; k++) rutGon(san + buoc * k)];

      expect(nhan.toSet().length, 4,
          reason: 'Bốn nhãn in đè lên nhau là đúng họ G39 — chỉ khác ở chỗ '
              'lần này nguyên nhân là dải quá hẹp so với độ lớn con số.');
    });

    test('⚠️ bước là số TRÒN và sàn là bội của bước — bẫy 4.18 trên máy thật',
        () {
      // Máy ảo 2026-09-16: với bước lẻ (168.333) fl_chart vẽ nhãn ở CẢ HAI
      // biên cộng mốc theo `interval`, và biên trên lệch mốc cuối vài phần tỉ
      // → hai chuỗi "13.6M" in đè nhau. Bước tròn thì mọi mốc rơi đúng vị trí
      // và phép cộng không sinh sai số.
      final (:san, :buoc) = daiTrucDuBao(const [13590000, 13202000]);

      expect(buoc, 200000, reason: 'số tròn gần nhất ≥ dải/3');
      expect(san % buoc, 0, reason: 'sàn là bội của bước → mốc rơi tròn');
      expect(san, lessThanOrEqualTo(13202000));
      expect(san + buoc * 3, greaterThanOrEqualTo(13590000));
    });

    test('bước tròn chọn trong họ 1 · 2 · 2,5 · 5 × 10^k', () {
      // ⚠️ Hai ca cuối đổi số ngày 2026-09-17 khi phép trừ hao `dải/2` được
      // thay bằng phép kiểm đúng: 3000 nay ra bước 1000 (trần 3000, khít đỉnh)
      // thay vì 2000 (trần 6000), và 45000 ra 20000 thay vì 25000. Tính chất
      // được canh vẫn nguyên — bước tròn, sàn ≤ đáy, trần ≥ đỉnh — chỉ là dải
      // thôi rộng gấp đôi mức cần.
      for (final ca in [
        (const [1000.0, 0.0], 500.0),
        (const [10000.0, 0.0], 5000.0),
        (const [3000.0, 0.0], 1000.0),
        (const [45000.0, 0.0], 20000.0),
      ]) {
        final (:san, :buoc) = daiTrucDuBao(ca.$1);
        expect(buoc, ca.$2, reason: 'dải ${ca.$1}');
        expect(san + buoc * 3, greaterThanOrEqualTo(ca.$1.first));
      }
    });

    test('⚠️ dải RỘNG từ 0 không được nới trần lên hơn gấp đôi đỉnh', () {
      // Máy ảo 2026-09-17, khối "Tổng tài sản": năm kỳ đầu là 0 (quãng chưa có
      // giao dịch) và kỳ cuối 13.590.000. Luật cũ `dải/2` cho bước 10.000.000
      // → trần 30.000.000, và đường thật bị ép xuống 45% dưới của khung. Không
      // test nào đỏ vì mọi tính chất đều vẫn đúng — chỉ mắt mới thấy.
      final (:san, :buoc) = daiTrucDuBao(const [0, 0, 0, 0, 0, 13590000]);

      expect(san, 0);
      expect(san + buoc * 3, greaterThanOrEqualTo(13590000),
          reason: 'trần vẫn phải phủ đỉnh');
      expect(san + buoc * 3, lessThan(13590000 * 1.5),
          reason: 'và không được rộng quá mức: trần gấp hơn hai lần đỉnh là '
              'nửa khung trống, đường dí sát đáy.');
    });

    test('mọi điểm bằng nhau (không cam kết) vẫn ra dải hợp lệ, không chia 0',
        () {
      final (:san, :buoc) = daiTrucDuBao(const [10000000, 10000000]);
      expect(buoc, greaterThan(0));
      expect(san, lessThanOrEqualTo(10000000));
      expect(san + buoc * 3, greaterThanOrEqualTo(10000000));
    });

    test('dải có phần âm thì sàn âm — vạch 0 nằm trong khung', () {
      final (:san, :buoc) = daiTrucDuBao(const [500000, -300000]);
      expect(san, lessThan(0));
      expect(san + buoc * 3, greaterThan(500000));
    });

    test('danh sách rỗng trả dải mặc định thay vì nổ', () {
      final (:san, :buoc) = daiTrucDuBao(const []);
      expect(buoc, greaterThan(0));
      expect(san, 0);
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
