import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/bill/bill_recurrence.dart';
import '../../domain/bill_note.dart';
import '../datasources/bill_local_datasource.dart';
import 'bill_repository.dart';

class BillRepositoryImpl implements BillRepository {
  final BillLocalDataSource dataSource;
  final AppDatabase db;
  final SyncEngine? syncEngine;

  BillRepositoryImpl({
    required this.dataSource,
    required this.db,
    this.syncEngine,
  });

  @override
  Stream<List<Bill>> watchBills(int idaccount) {
    return dataSource.watchBills(idaccount);
  }

  @override
  Future<List<Bill>> getBills(int idaccount) {
    return dataSource.getBills(idaccount);
  }

  @override
  Future<Map<String, Transaction>> paymentsOf(int idaccount) {
    return db.transactionDao.getBillPayments(idaccount);
  }

  @override
  Future<void> addBill(BillsCompanion bill) async {
    await dataSource.insertBill(bill);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> editBill(BillsCompanion bill) async {
    // KHÔNG dùng insertBill: nó chèn theo insertOrReplace nên thay cả hàng và
    // đưa mọi cột vắng mặt về mặc định. Xem `BillDao.updateFields`.
    await dataSource.updateBill(bill);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> deleteBill(String id) async {
    await dataSource.softDeleteBill(id);
    syncEngine?.scheduleSync();
  }

  @override
  Future<void> payBill({
    required Bill bill,
    required String walletId,
    required int idaccount,
    double? amount,
    DateTime? occurredAt,
    String? note,
  }) async {
    // UI truyền vào ảnh chụp `Bill` mà nó đang giữ; bấm nút hai lần thì lần
    // thứ hai vẫn mang isPaid = false. Trạng thái thật phải đọc lại từ CSDL.
    final current = await dataSource.getBillById(bill.id);
    if (current == null) {
      throw StateError('Không tìm thấy hoá đơn ${bill.id}');
    }
    if (current.isPaid || current.payStatus == 'Payed') {
      throw BillAlreadyPaidException(bill.id);
    }

    // Số tiền THẬT của kỳ này. Kiểm trước khi mở transaction: ô nhập nằm
    // ngoài khối nguyên tử nên không được tin.
    final soTien = amount ?? current.amount;
    if (soTien <= 0) throw BillInvalidAmountException(soTien);

    final now = DateTime.now();

    // Đây là tầng ghi tiền; một tham số ngày để ngỏ là cửa sau. Khoản chi
    // không thể mang dấu thời gian chưa tới — chặn giống `depositToGoal`.
    final ngayGiaoDich = occurredAt ?? now;
    if (ngayGiaoDich.isAfter(now)) {
      throw ArgumentError.value(
          occurredAt, 'occurredAt', 'Ngày giao dịch không được ở tương lai');
    }

    // Cả bốn bước nằm trong một transaction: hỏng giữa chừng mà vẫn giữ lại
    // phần đã ghi thì ví bị trừ nhưng hoá đơn chưa đánh dấu (hoặc ngược lại).
    await db.transaction(() async {
      // 1. Đánh dấu đã thanh toán (đặt cả isPaid lẫn payStatus), và ghi lại
      //    số tiền THẬT đã trả — tab "Đã thanh toán" là lịch sử, nó phải nói
      //    số đã trả chứ không phải con số dự kiến lúc tạo hoá đơn.
      await dataSource.markPaid(current.id);
      if (soTien != current.amount) {
        await dataSource.updateBill(BillsCompanion(
          id: Value(current.id),
          amount: Value(soTien),
        ));
      }

      // 2. Sinh giao dịch chi tương ứng.
      await db.transactionDao.insert(
        TransactionsCompanion.insert(
          id: const Uuid().v4(),
          idaccount: idaccount,
          walletId: walletId,
          // Không gắn danh mục thì khoản chi này nằm ngoài mọi thống kê theo
          // danh mục và mọi ngân sách.
          categoryId: Value(current.categoryId),
          amount: soTien,
          type: 'chi',
          // Tiền tố đứng TRƯỚC — `transactionOwnerOf` nhận diện bằng
          // startsWith; ghi chú của lần trả (nếu có) nối sau bằng gạch dài.
          note: Value(ghiChuTraHoaDon(current.name, note)),
          // Sợi dây để hoàn tác lần được ngược về đây. Cột CỤC BỘ (v16) —
          // tiền tố ghi chú ở trên KHÔNG đủ: người dùng gõ trùng tiền tố là
          // hoàn nhầm tiền vào ví bằng một khoản chi khác của họ.
          billId: Value(current.id),
          // Ngày của SỰ VIỆC. `updatedAt` bên dưới vẫn là "bây giờ": nó là sổ
          // sách đồng bộ, lùi theo là LWW coi bản ghi cũ hơn thực tế.
          date: ngayGiaoDich,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );

      // 3. Trừ số dư ví.
      final wallet = await db.walletDao.getById(walletId);
      if (wallet != null) {
        await db.walletDao.updateBalance(walletId, wallet.balance - soTien);
      }

      // 4. Sinh hoá đơn kỳ kế tiếp.
      //
      // Nguồn sự thật là cặp `isRecurrence` + `timeRecurrence`. Cột
      // `recurrence` dạng chuỗi cũ KHÔNG đáng tin: nhánh pull không ghi nó,
      // nên hàng kéo về từ backend luôn mang mặc định 'monthly' của bảng — đọc
      // theo nó thì hoá đơn không lặp cũng đẻ ra kỳ mới.
      if (current.isRecurrence) {
        await dataSource.insertBill(
          _nextPeriodOf(current, now, soTien),
        );
      }
    });

    syncEngine?.scheduleSync();
  }

  @override
  Future<void> undoPayment({required String billId}) async {
    final current = await dataSource.getBillById(billId);
    if (current == null) {
      throw StateError('Không tìm thấy hoá đơn $billId');
    }
    if (!current.isPaid && current.payStatus != 'Payed') {
      throw BillNotPaidException(billId);
    }

    // Khoản chi mà lần trả đã sinh ra. Không tìm thấy thì DỪNG — xem
    // `BillUndoUnavailableException`.
    final khoanChi = await db.transactionDao.getByBill(billId);
    if (khoanChi == null) {
      throw BillUndoUnavailableException(billId);
    }

    final now = DateTime.now();

    // Ba bước phải nguyên tử, cùng lý do với `payBill`: hỏng giữa chừng mà
    // giữ lại phần đã ghi thì tiền về ví nhưng hoá đơn vẫn "đã trả".
    await db.transaction(() async {
      // 1. Hoàn tiền vào ĐÚNG ví đã bị trừ, ĐÚNG số đã trừ. Đọc từ giao dịch
      //    chứ không từ hoá đơn: người dùng có thể đã trả bằng ví khác, và
      //    với số tiền khác số ghi trên hoá đơn.
      final wallet = await db.walletDao.getById(khoanChi.walletId);
      if (wallet != null) {
        await db.walletDao
            .updateBalance(khoanChi.walletId, wallet.balance + khoanChi.amount);
      }

      // 2. Xoá mềm khoản chi (quy tắc 5 trong CLAUDE.md).
      await db.transactionDao.softDelete(khoanChi.id);

      // 3. Gỡ kỳ kế tiếp mà lần trả đã sinh ra. Để lại thì người dùng có hai
      //    kỳ cùng mở, và trả lại lần nữa sẽ đẻ thêm một kỳ trùng.
      final kySau = await db.billDao.getGeneratedFrom(billId);
      if (kySau != null) {
        await dataSource.softDeleteBill(kySau.id);
      }

      // 4. Đưa hoá đơn về chưa thanh toán. Đặt CẢ HAI cột, cùng lý do với
      //    `markPaid`: nhánh đẩy gửi `pay_status` chứ không gửi `isPaid`.
      await dataSource.updateBill(BillsCompanion(
        id: Value(billId),
        isPaid: const Value(false),
        payStatus: const Value('Pending'),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));
    });

    syncEngine?.scheduleSync();
  }

  /// Hoá đơn của kỳ kế tiếp, kế thừa toàn bộ cấu hình của [current].
  ///
  /// Bỏ sót `walletId`/`categoryId` ở đây là tự tạo lại đúng lỗi chặn đường
  /// đẩy: hai cột đó NOT NULL phía backend. Bỏ sót `isRecurrence` thì chuỗi
  /// hoá đơn định kỳ dừng lại sau đúng một kỳ.
  ///
  /// Kỳ sau bắt đầu **đúng tại ngày đến hạn của kỳ trước**, nên các kỳ nối
  /// đuôi nhau không hở và luôn giữ được `startDate < dueDate`. Vì chuỗi mất
  /// mốc gốc theo cách ấy, `anchorDay` được **chép sang từng kỳ** để mốc không
  /// tụt dần — xem `core/bill/bill_recurrence.dart`. Quên chép là hoá đơn
  /// "ngày 31 hàng tháng" tụt về 28 vĩnh viễn ngay sau tháng Hai đầu tiên.
  BillsCompanion _nextPeriodOf(Bill current, DateTime now, double soTien) {
    return BillsCompanion.insert(
      id: const Uuid().v4(),
      idaccount: current.idaccount,
      // Sợi dây để hoàn tác gỡ đúng kỳ này. Cột CỤC BỘ (v16).
      generatedFromBillId: Value(current.id),
      walletId: Value(current.walletId),
      categoryId: Value(current.categoryId),
      name: current.name,
      // Kỳ sau bắt đầu từ số VỪA TRẢ, không phải số cũ: một quy tắc duy nhất,
      // không có "số mẫu" ẩn, và số vừa trả là ước lượng sát hơn.
      amount: soTien,
      startDate: Value(current.dueDate),
      // Ngày gốc đi theo cả chuỗi — đây là chỗ duy nhất giữ được nó. Kỳ cũ
      // chưa có (hoá đơn tạo trước v18, hoặc kéo từ server) thì neo vào ngày
      // đến hạn hiện tại, tức giữ nguyên hành vi cũ thay vì đoán.
      anchorDay: Value(current.anchorDay ?? current.dueDate.day),
      dueDate: nextBillDueDate(
        current.dueDate,
        current.timeRecurrence,
        anchorDay: current.anchorDay ?? current.dueDate.day,
      ),
      payStatus: const Value('Pending'),
      isPaid: const Value(false),
      timeNotification: Value(current.timeNotification),
      // Quên chép là chuỗi tự trả dừng sau đúng một kỳ, im lặng.
      autoPayEnabled: Value(current.autoPayEnabled),
      isRecurrence: const Value(true),
      timeRecurrence: Value(current.timeRecurrence),
      recurrence: Value(legacyFromTimeRecurrence(current.timeRecurrence)),
      icon: Value(current.icon),
      colour: Value(current.colour),
      note: Value(current.note),
      syncStatus: const Value('pending'),
      updatedAt: now,
    );
  }
}
