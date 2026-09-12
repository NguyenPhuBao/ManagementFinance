import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/bill_an_han.dart';
import '../../domain/bill_pay_status.dart';
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
    if (daCoKhoanChi(current)) {
      throw BillAlreadyPaidException(bill.id);
    }
    // Kỳ bỏ qua ĐÃ sinh kỳ kế tiếp; trả tiếp trên nó là sinh kỳ thứ hai trùng
    // hạn. Người dùng phải hoàn tác việc bỏ qua trước.
    if (daBoQua(current)) {
      throw BillSkippedCannotPayException(bill.id);
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
    if (!daCoKhoanChi(current)) {
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

  @override
  Future<void> skipBill({required String billId}) async {
    // Đọc lại từ CSDL, cùng lý do với `payBill`: UI giữ một ảnh chụp có thể đã
    // cũ, và bấm nút hai lần thì lần thứ hai vẫn mang trạng thái cũ.
    final current = await dataSource.getBillById(billId);
    if (current == null) {
      throw StateError('Không tìm thấy hoá đơn $billId');
    }
    if (daCoKhoanChi(current)) {
      throw BillAlreadyPaidException(billId);
    }
    if (daBoQua(current)) {
      throw BillAlreadySkippedException(billId);
    }

    final now = DateTime.now();

    // Hai bước phải nguyên tử: hỏng giữa chừng mà giữ lại phần đã ghi thì kỳ
    // này đã đóng nhưng chuỗi không có kỳ sau, hoặc ngược lại — hai kỳ mở.
    await db.transaction(() async {
      await dataSource.updateBill(BillsCompanion(
        id: Value(billId),
        payStatus: const Value(kBillSkipped),
        // Không có khoản chi nào, nên isPaid phải false. Đặt true là mọi chỗ
        // hỏi "đã trả chưa" trả lời sai, và nhánh pull cũng suy ngược lại từ
        // `pay_status`.
        isPaid: const Value(false),
        syncStatus: const Value('pending'),
        updatedAt: Value(now),
      ));

      // Cùng luật với `payBill`: nguồn sự thật là `isRecurrence`, KHÔNG phải
      // cột chuỗi `recurrence` — hàng kéo về từ backend luôn mang mặc định
      // 'monthly' của bảng.
      if (current.isRecurrence) {
        // Số tiền kế thừa số ghi trên hoá đơn: không có lần trả nào để lấy số
        // thật, và bịa một con số khác thì tệ hơn.
        await dataSource.insertBill(
          _nextPeriodOf(current, now, current.amount),
        );
      }
    });

    syncEngine?.scheduleSync();
  }

  @override
  Future<void> undoSkip({required String billId}) async {
    final current = await dataSource.getBillById(billId);
    if (current == null) {
      throw StateError('Không tìm thấy hoá đơn $billId');
    }
    // Chặn cả kỳ đã TRẢ: hoàn tác lần trả phải đi qua `undoPayment`, thứ có
    // bước hoàn tiền. Đi nhầm đường này là hoá đơn về `Pending` mà tiền vẫn
    // nằm ngoài ví và khoản chi vẫn còn trong sổ.
    if (!daBoQua(current)) {
      throw BillNotSkippedException(billId);
    }

    final now = DateTime.now();

    await db.transaction(() async {
      // Gỡ kỳ kế tiếp mà lần bỏ qua đã sinh ra — cùng lý do với `undoPayment`:
      // để lại thì người dùng có hai kỳ cùng mở, và bỏ qua lần nữa sẽ đẻ thêm
      // một kỳ trùng.
      final kySau = await db.billDao.getGeneratedFrom(billId);
      if (kySau != null) {
        await dataSource.softDeleteBill(kySau.id);
      }

      // Về `Pending` chứ không `Overdue`: `markOverdue` chạy sau mỗi lần đồng
      // bộ và tự gắn lại cờ nếu kỳ đã trễ. Đoán ở đây là dựng bản thứ hai của
      // luật ấy.
      await dataSource.updateBill(BillsCompanion(
        id: Value(billId),
        payStatus: const Value(kBillPending),
        isPaid: const Value(false),
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
  /// Kỳ sau bắt đầu **đúng tại ngày kết thúc kỳ trước** (`periodEnd`; hàng cũ
  /// chưa có cột thì là ngày đến hạn), nên các kỳ nối đuôi nhau không hở và
  /// luôn giữ được `startDate < dueDate`. Vì chuỗi mất mốc gốc theo cách ấy,
  /// `anchorDay` được **chép sang từng kỳ** để mốc không tụt dần — xem
  /// `core/bill/bill_recurrence.dart`. Quên chép là hoá đơn "ngày 31 hàng
  /// tháng" tụt về 28 vĩnh viễn ngay sau tháng Hai đầu tiên.
  BillsCompanion _nextPeriodOf(Bill current, DateTime now, double soTien) {
    // Kỳ sau bắt đầu tại NGÀY KẾT THÚC KỲ, không phải hạn trả: với hoá đơn có
    // ân hạn (kỳ 01–30/09, hạn 15/10) nối từ hạn trả là hở nửa tháng và mỗi kỳ
    // trôi thêm — bẫy §4.4 tài liệu xin backend. Hàng cũ (periodEnd NULL) thì
    // hai mốc trùng nhau, kết quả y hệt trước v21.
    final batDauSau = current.periodEnd ?? current.dueDate;
    // Ngày gốc đi theo cả chuỗi — đây là chỗ duy nhất giữ được nó. Kỳ cũ chưa
    // có (hoá đơn tạo trước v18, hoặc kéo từ server) thì neo vào mốc hiện tại,
    // tức giữ nguyên hành vi cũ thay vì đoán.
    final goc = current.anchorDay ?? batDauSau.day;
    final ketThucSau = nextBillDueDate(
      batDauSau,
      current.timeRecurrence,
      anchorDay: goc,
    );
    // Ân hạn đi theo chuỗi mà không cần cột riêng: suy từ kỳ hiện tại.
    final anHan = anHanCua(current);
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
      startDate: Value(batDauSau),
      // LUÔN ghi — NULL chỉ dành cho hàng cũ (xem `Bills.periodEnd`).
      periodEnd: Value(ketThucSau),
      anchorDay: Value(goc),
      dueDate: hanTraTu(ketThucSau, anHan),
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
