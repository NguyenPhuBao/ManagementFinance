import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canh chừng điều gì: sổ giao dịch chỉ được cho xoá khi bản thân giao dịch là
/// nguồn sự thật DUY NHẤT của hệ quả nó gây ra. Khoản nạp/rút mục tiêu còn
/// một bộ đếm `current_amount` ở bảng goal, khoản trả hoá đơn còn cờ Payed và
/// kỳ kế tiếp — xoá ở sổ chỉ hoàn ví, ba thứ kia đứng nguyên (đã thấy trên
/// máy ảo 2026-09-06: xoá hai khoản nạp, tiến độ MuaXe vẫn 1.100.000).
///
/// Việc 4c (2026-10-17): khoản trả hoá đơn khoá theo `billId`, KHÔNG theo tiền tố ghi chú. Khoản kiểu cũ (tiền tố,
/// không `billId`) và khoản mồ côi (`billId` + hoá đơn đã xoá mềm) mở khoá có cảnh báo — trước đó cả hai kẹt vĩnh
/// viễn: Hoàn tác không lần được (kiểu cũ) hoặc đã mất theo hoá đơn (mồ côi), còn sổ khoá theo tiền tố.
void main() {
  TransactionEntity tx({
    String? goalId,
    String? billId,
    String note = '',
    String type = 'chi',
  }) =>
      TransactionEntity(
        id: 't',
        walletId: 'w',
        idaccount: 1,
        goalId: goalId,
        billId: billId,
        amount: 1000,
        type: type,
        note: note,
        date: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      );

  const ghiChuTra = '${kGhiChuTraHoaDon}Tiền điện';

  group('transactionOwnerOf', () {
    test('giao dịch thường và chuyển khoản thường là của chính nó', () {
      expect(transactionOwnerOf(tx()), TransactionOwner.transaction);
      expect(transactionOwnerOf(tx(note: 'Cà phê sáng')),
          TransactionOwner.transaction);
      expect(transactionOwnerOf(tx(type: 'transfer')),
          TransactionOwner.transaction);
    });

    test('có goalId là của mục tiêu, bất kể ghi chú', () {
      expect(transactionOwnerOf(tx(goalId: 'g1', note: 'ghi chú tự sửa')),
          TransactionOwner.goal);
    });

    test('hàng kéo từ server không có goalId thì nhận theo tiền tố ghi chú',
        () {
      // Hàng cũ trên server mang `Idgoal = NULL` (goal_id đồng bộ từ 2026-09-07,
      // hàng tạo trước đó thì chưa) — máy khác chỉ còn ghi chú.
      expect(transactionOwnerOf(tx(note: 'Tích lũy mục tiêu: MuaXe')),
          TransactionOwner.goal);
      expect(transactionOwnerOf(tx(note: 'Rút từ mục tiêu: MuaXe')),
          TransactionOwner.goal);
    });

    test('dạng cũ hai hàng rời "Tích lũy nhận từ …" cũng là của mục tiêu', () {
      // Bản app trước 2026-09-05 ghi mỗi lần nạp thành cặp chi/thu; nửa "thu"
      // mang tiền tố này và vẫn còn trong dữ liệu thật.
      expect(
        transactionOwnerOf(tx(note: 'Tích lũy nhận từ Tiền mặt: MuaXe', type: 'thu')),
        TransactionOwner.goal,
      );
    });

    test('tiền tố phải ở ĐẦU ghi chú — người dùng gõ giữa câu thì không tính',
        () {
      expect(transactionOwnerOf(tx(note: 'đã Tích lũy mục tiêu: xong')),
          TransactionOwner.transaction);
    });
  });

  group('transactionOwnerOf — khoản trả hoá đơn khoá theo billId (việc 4c)', () {
    test('có billId, hoá đơn còn → của hoá đơn, KỂ CẢ khi ghi chú hỏng hay bị sửa',
        () {
      for (final note in [ghiChuTra, 'enc:AbC123==', 'Cà phê', '']) {
        expect(transactionOwnerOf(tx(billId: 'b1', note: note)),
            TransactionOwner.bill,
            reason: 'Ghi chú "$note": nhánh kéo về ghi đè note vô điều kiện và '
                'decrypt() hỏng trả "enc:…" — khoá theo tiền tố thì khoản trả mất '
                'khoá, xoá rời được: đúng loại hỏng im lặng mà khoá sinh ra để chặn.');
      }
    });

    test('mặc định không truyền hoaDonDaXoa → khoản có billId VẪN khoá', () {
      expect(transactionOwnerOf(tx(billId: 'b1', note: ghiChuTra)),
          TransactionOwner.bill,
          reason: 'Nơi chưa hỏi cổng (trang Hoá đơn, người gọi tương lai) phải '
              'nhận mặc định an toàn: chưa biết thì không mở.');
    });

    test('có billId, hoá đơn đã xoá (khoản mồ côi) → của chính nó', () {
      expect(
          transactionOwnerOf(tx(billId: 'b1', note: ghiChuTra),
              hoaDonDaXoa: true),
          TransactionOwner.transaction,
          reason: 'Hoá đơn xoá mềm thì nút Hoàn tác mất theo — sổ còn khoá nữa là '
              'khoản chi kẹt vĩnh viễn.');
    });

    test('tiền tố mà KHÔNG billId (khoản kiểu cũ) → của chính nó', () {
      expect(transactionOwnerOf(tx(note: ghiChuTra)),
          TransactionOwner.transaction,
          reason: 'Trước 4c ca này là `bill`: Hoàn tác ở trang Hoá đơn ném '
              'BillUndoUnavailableException (không billId để lần về), sổ lại khoá '
              'theo tiền tố — không lối nào gỡ được. Đo máy ảo 2026-10-17: 3 khoản '
              'như thế ở tài khoản 10.');
    });

    test('mục tiêu xét TRƯỚC hoá đơn', () {
      expect(
          transactionOwnerOf(tx(goalId: 'g1', billId: 'b1'), hoaDonDaXoa: true),
          TransactionOwner.goal);
      expect(transactionOwnerOf(tx(goalId: 'g1', billId: 'b1')),
          TransactionOwner.goal,
          reason: 'Hoá đơn CÒN (mặc định) mà khoản mang cả goalId: mục tiêu vẫn '
              'thắng. Chỉ ca hoaDonDaXoa:true không phân biệt được thứ tự hai '
              'vế (cờ ấy đã tắt vế billId).');
    });
  });

  group('canhBaoXoaTaiSo', () {
    test('khoản mồ côi → câu "hoá đơn đã xoá"', () {
      expect(
          canhBaoXoaTaiSo(tx(billId: 'b1', note: ghiChuTra), hoaDonDaXoa: true),
          'Hoá đơn của khoản này đã xoá — xoá ở đây chỉ trả tiền về ví.');
    });

    test('khoản kiểu cũ → câu "bản cũ", nói rõ hoá đơn vẫn ghi đã trả', () {
      expect(
          canhBaoXoaTaiSo(tx(note: ghiChuTra)),
          'Khoản trả hoá đơn ghi bằng bản cũ — xoá ở đây chỉ trả tiền về ví, '
          'hoá đơn vẫn ghi là đã trả.',
          reason: 'Xoá ở sổ không đổi trạng thái kỳ (spec mục 4) — câu phải nói '
              'đúng điều ấy.');
    });

    test('khoản còn khoá, mục tiêu, giao dịch thường → null', () {
      expect(canhBaoXoaTaiSo(tx(billId: 'b1', note: ghiChuTra)), isNull,
          reason: 'Khoản còn khoá đã có câu riêng (lyDoKhongXoaTaiSo).');
      expect(canhBaoXoaTaiSo(tx(goalId: 'g1')), isNull);
      expect(canhBaoXoaTaiSo(tx(note: 'Cà phê')), isNull);
      expect(canhBaoXoaTaiSo(tx(note: 'Cà phê'), hoaDonDaXoa: true), isNull,
          reason: 'Cờ hoaDonDaXoa chỉ có nghĩa với khoản có billId.');
    });

    test('tiền tố phải ở ĐẦU ghi chú', () {
      expect(canhBaoXoaTaiSo(tx(note: 'đã $ghiChuTra')), isNull);
    });
  });

  group('cauXacNhanXoaGiaoDich', () {
    const chung = 'Số dư ví sẽ được hoàn lại. Không hoàn tác được.';

    test('giao dịch thường giữ nguyên câu cũ', () {
      expect(cauXacNhanXoaGiaoDich(tx(note: 'Cà phê')), chung);
    });

    test('khoản mồ côi: câu cảnh báo đứng TRƯỚC câu chung', () {
      expect(
          cauXacNhanXoaGiaoDich(tx(billId: 'b1', note: ghiChuTra),
              hoaDonDaXoa: true),
          'Hoá đơn của khoản này đã xoá — xoá ở đây chỉ trả tiền về ví. $chung');
    });

    test('khoản kiểu cũ: câu cảnh báo đứng TRƯỚC câu chung', () {
      expect(
          cauXacNhanXoaGiaoDich(tx(note: ghiChuTra)),
          'Khoản trả hoá đơn ghi bằng bản cũ — xoá ở đây chỉ trả tiền về ví, '
          'hoá đơn vẫn ghi là đã trả. $chung');
    });
  });

  group('lyDoKhongXoaTaiSo', () {
    test('giao dịch thường thì không có lý do — xoá được', () {
      expect(lyDoKhongXoaTaiSo(TransactionOwner.transaction), isNull);
    });

    test('mục tiêu và hoá đơn có câu chỉ đường riêng', () {
      expect(lyDoKhongXoaTaiSo(TransactionOwner.goal), contains('mục tiêu'));
      expect(lyDoKhongXoaTaiSo(TransactionOwner.bill), contains('hoá đơn'));
    });
  });
}
