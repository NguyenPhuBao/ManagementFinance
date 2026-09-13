import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/notification/notification_rules.dart';
import '../../../../core/sync/sync_models.dart';
import '../repositories/bill_repository.dart';

/// Gỡ khoản trả hoá đơn mà server đã từ chối bằng `BILL_ALREADY_PAID`.
///
/// Chốt `chanTraHaiLan` ở `upsertTransaction` (backend, CAN-LAM 20 §2.1, có từ
/// `7779999`) cho máy nào đẩy trước thì thắng: khoản chi thứ hai mang cùng
/// `Idbill` bị từ chối. Không có lớp này, máy thua giữ một khoản chi mà server
/// không có, ví bị trừ một lần không ai hoàn, và sổ hai máy lệch nhau **im
/// lặng** — không lỗi, không log, không gì báo cho người dùng.
///
/// Vì sao đứng riêng chứ không nằm trong `SyncEngine`: engine đã ~1900 dòng, và
/// cho nó biết về tầng hoá đơn là phá đúng ranh giới nó giữ được tới giờ. Ở đây
/// nó chỉ phát `SyncOpFailure.code` ra `pushResultStream`, còn ai muốn phản ứng
/// thì tự nghe.
///
/// Thiết kế: `docs/superpowers/specs/2026-09-13-auto-pay-dong-bo-design.md` §4.
class BillPaymentConflictResolver {
  BillPaymentConflictResolver({
    required AppDatabase db,
    required BillRepository bills,
  })  : _db = db,
        _bills = bills;

  /// Mã backend gắn cho khoản chi thứ hai mang cùng `Idbill`.
  static const String maDaTra = 'BILL_ALREADY_PAID';

  final AppDatabase _db;
  final BillRepository _bills;
  StreamSubscription<SyncResult>? _sub;

  /// Bắt đầu nghe kết quả đẩy. Gọi nhiều lần thì lượt sau thay lượt trước —
  /// nghe hai lần là hoàn tác chạy hai lượt cho cùng một khoản chi.
  void batDauNghe(Stream<SyncResult> pushResults) {
    _sub?.cancel();
    _sub = pushResults.listen(_xuLy);
  }

  Future<void> dung() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _xuLy(SyncResult ketQua) async {
    for (final f in ketQua.failures) {
      // Mã này chỉ có nghĩa cho thao tác đẩy KHOẢN CHI. Đọc nó ở entity khác
      // là hiểu sai hợp đồng.
      if (f.entity != SyncEntityType.transaction) continue;
      if (f.code != maDaTra) continue;
      await _hoanTac(f.localId);
    }
  }

  Future<void> _hoanTac(String idKhoanChi) async {
    // `getById` đọc CẢ hàng đã xoá mềm: một chu kỳ trước có thể đã gỡ khoản chi
    // rồi, và bỏ qua ca ấy là để hai bản ghi kẹt hàng đợi đẩy.
    final khoanChi = await _db.transactionDao.getById(idKhoanChi);
    final billId = khoanChi?.billId;

    if (billId == null) {
      // Khoản chi do bản app trước 2026-09-06 tạo không mang `billId`, nên
      // không lần ngược được về hoá đơn. Không đoán — đúng cách `undoPayment`
      // từ chối thay vì dò tiền tố ghi chú. Vẫn cho nó thoát hàng đợi, nếu
      // không nó bị đẩy lại mãi và lần nào cũng bị từ chối y như vậy.
      await _db.transactionDao.markSynced(idKhoanChi);
      debugPrint('[BillConflict] Khoản chi $idKhoanChi không có billId — '
          'không gỡ được, chỉ cho thoát hàng đợi');
      return;
    }

    try {
      await _bills.undoPayment(billId: billId);
      debugPrint('[BillConflict] Đã gỡ khoản trả hoá đơn $billId vì máy khác '
          'đã trả trước');
      // Chỉ báo khi THẬT SỰ có gì đổi trên máy này. Hai nhánh `catch` bên dưới
      // nghĩa là không còn gì để gỡ, nên báo là làm phiền vô cớ.
      await _baoNguoiDung(idaccount: khoanChi!.idaccount, billId: billId);
    } on BillNotPaidException {
      // Hoá đơn đã được kéo về chưa trả bởi một chu kỳ pull trước — không còn
      // gì để gỡ. Không phải lỗi.
      debugPrint('[BillConflict] Hoá đơn $billId vốn đã ở trạng thái chưa trả');
    } on BillUndoUnavailableException {
      // Khoản chi không lần ngược được về hoá đơn. Như trên.
      debugPrint('[BillConflict] Không lần được khoản chi của hoá đơn $billId');
    }

    // NGOÀI `try`: phải chạy cả khi `undoPayment` ném, vì hai bản ghi vẫn cần
    // thoát hàng đợi đẩy. Thiếu một trong hai là một lỗi im lặng **khác nhau**:
    //
    // (a) `undoPayment` xoá MỀM khoản chi, nên nó quay lại hàng đợi với cờ xoá
    //     — trong khi server CHƯA BAO GIỜ có nó (chính nó vừa bị từ chối). Xoá
    //     một bản ghi không tồn tại là vòng lặp `Record not found` ở mọi chu
    //     kỳ, đúng cái đã vấp ngày 2026-09-04.
    await _db.transactionDao.markSynced(idKhoanChi);
    // (b) `undoPayment` kéo hoá đơn về chưa trả với `updatedAt` mới hơn bản
    //     `Payed` mà máy thắng vừa ghi. Đẩy lên là LWW cho MÁY THUA thắng — nó
    //     xoá đúng kết quả vừa được server chấp nhận. Trạng thái thật phải đến
    //     từ nhánh kéo về ở chu kỳ sau.
    await _db.billDao.markSynced(billId);
  }

  /// Ghi một thông báo vào trung tâm thông báo.
  ///
  /// Vì sao không dùng toast: việc này xảy ra lúc đồng bộ **nền**, có thể khi
  /// app đang đóng — toast sẽ trôi mất, mà số dư ví thì vừa đổi hai lần (bị trừ
  /// lúc trả, được hoàn lúc gỡ).
  ///
  /// Khoá chống trùng chỉ cần `billId`: mỗi kỳ của hoá đơn lặp là **một hàng
  /// riêng**, nên id hoá đơn đã định danh đúng kỳ. Một chu kỳ đồng bộ hỏng rồi
  /// thử lại là hai lượt phát cùng một thất bại — `insertIfAbsent` nuốt lượt
  /// sau.
  ///
  /// **Không nêu số tiền** — nếp thông báo tối giản của dự án; số tiền còn nằm
  /// ở khoản chi và ở ví, người dùng mở ra xem được.
  Future<void> _baoNguoiDung({
    required int idaccount,
    required String billId,
  }) async {
    final bill = await _db.billDao.getById(billId);
    final ten = bill?.name ?? 'Hoá đơn';

    await _db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
      id: const Uuid().v4(),
      idaccount: idaccount,
      kind: NotificationKind.billPaidOnOtherDevice.name,
      dedupeKey: 'billConflict:$billId',
      title: 'Hoá đơn đã được trả trên thiết bị khác',
      body: 'Khoản trả $ten trên máy này đã được gỡ và tiền đã hoàn về ví.',
      severity: NotificationSeverity.info.name,
      subjectType: const Value('bill'),
      subjectId: Value(billId),
      deeplink: const Value('/bills'),
      createdAt: DateTime.now(),
    ));
  }
}
