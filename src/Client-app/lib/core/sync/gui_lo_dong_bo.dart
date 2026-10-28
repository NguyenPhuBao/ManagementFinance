/// Gửi một lô thao tác lên `/sync/push`, đọc kết quả từng thao tác, phân loại lỗi — tách khỏi `SyncEngine` 2026-10-19
/// (spec `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`). Thân dời nguyên văn.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../api/dio_client.dart';
import '../database/app_database.dart';
import '../network/trang_thai_may_chu.dart';
import 'sync_models.dart';
import 'sync_payload_normalizer.dart';
import 'uuid_dong_bo.dart';

/// Chỉ `SyncEngine` dựng lớp này. Hai thứ của engine đọc **qua hàm**, không chụp giá trị: [_now] (đồng hồ tiêm được) và
/// [_bacChan] (bậc giãn cách hiện tại — đọc SAU một `await` trong vòng kết quả, mà `start()` có thể đặt lại giãn cách
/// giữa chừng).
class GuiLoDongBo {
  GuiLoDongBo({
    required DioClient dioClient,
    required AppDatabase db,
    required DateTime Function() now,
    required Duration Function() bacChan,
  })  : _dioClient = dioClient,
        _db = db,
        _now = now,
        _bacChan = bacChan;

  final DioClient _dioClient;
  final AppDatabase _db;
  final DateTime Function() _now;
  final Duration Function() _bacChan;

  // ── Send batch to backend ─────────────────────────────────────────────────

  Future<SyncResult> sendBatch(List<SyncOperation> ops) async {
    debugPrint(
        '[SyncEngine] Sending batch ${ops.length} operations to backend...');
    try {
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();
      final response = await _dioClient.dio.post(
        '/sync/push',
        data: {
          'clientId': 'flutter-client-app',
          'pushedAt': nowUtcIso,
          'operations': ops.map((op) {
            final operation = op.toJson();
            operation['payload'] = switch (op.entity) {
              SyncEntityType.wallet =>
                SyncPayloadNormalizer.walletForPush(op.payload),
              SyncEntityType.transaction =>
                SyncPayloadNormalizer.transactionForPush(op.payload),
              SyncEntityType.category =>
                SyncPayloadNormalizer.categoryForPush(op.payload),
              _ => SyncPayloadNormalizer.forPush(op.payload),
            };
            return operation;
          }).toList(),
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final topData = response.data['data'] as Map<String, dynamic>? ??
            response.data as Map<String, dynamic>;
        final results = (topData['results'] ?? response.data['results'])
                as List<dynamic>? ??
            [];
        int succeeded = 0;
        int failed = 0;
        final List<String> conflictIds = [];
        final List<String> errorMessages = [];
        final List<SyncOpFailure> failures = [];

        for (final item in results) {
          final respLocalId = item['localId'] as String?;
          final status = item['status'] as String?;
          if (respLocalId != null) {
            final opIndex = ops.indexWhere(
              (e) =>
                  e.localId == respLocalId ||
                  toValidUuid(e.localId) == respLocalId,
            );
            if (opIndex != -1) {
              final op = ops[opIndex];
              if (status == 'synced') {
                await _markSyncedById(op.entity, op.localId);
                succeeded++;
              } else if (status == 'conflict') {
                // Backend trả 'conflict' khi bản trên server có `update_at`
                // mới hơn payload vừa đẩy — tức LWW đã phân xử xong và server
                // thắng. Trước đây bản ghi chỉ được ghi vào `conflictIds` rồi
                // bỏ đó: nó vẫn mang `pending`, nên mọi chu kỳ sau lại đẩy lên
                // và lại thua đúng như vậy, mãi mãi.
                //
                // Đánh dấu đã đồng bộ để thoát vòng lặp. Bản thắng cuộc về máy
                // ở bước Pull ngay sau đó trong cùng chu kỳ: `update_at` của nó
                // lớn hơn payload nên cũng lớn hơn mốc đồng bộ đang lưu.
                await _markSyncedById(op.entity, op.localId);
                conflictIds.add(op.localId);
                debugPrint(
                  '[SyncEngine] Push conflict (bản server mới hơn, lấy theo '
                  'server): entity=${op.entity.name}, localId=${op.localId}',
                );
              } else if (op.operation == SyncOperationType.delete &&
                  _recordNotFoundPattern
                      .hasMatch(item['message']?.toString() ?? '')) {
                // Xoá một bản ghi server không có = **mục tiêu đã đạt**. Đích
                // của thao tác này là "hàng đó không còn trên server", và nó
                // đã không còn.
                //
                // Coi là lỗi thì bản ghi giữ `pending` và được đẩy lại ở mọi
                // chu kỳ, mãi mãi: `_classifyFailure` không có nhánh nào cho
                // thông báo này nên nó rơi vào `transient`. Hai đường dẫn tới
                // đây đều có thật — người dùng tạo một bản ghi khi offline rồi
                // xoá trước khi nó kịp lên server, hoặc hàng đã bị xoá cứng ở
                // phía server.
                await _markSyncedById(op.entity, op.localId);
                succeeded++;
                debugPrint(
                  '[SyncEngine] Push delete: bản ghi vốn đã không có trên '
                  'server, coi như đã xong: entity=${op.entity.name}, '
                  'localId=${op.localId}',
                );
              } else {
                failed++;
                final message = item['message']?.toString() ?? 'Unknown error';
                errorMessages.add(message);
                final code = item['code'] as String?;
                final kind = _classifyFailure(message, code: code);
                failures.add(SyncOpFailure(
                  localId: op.localId,
                  entity: op.entity,
                  message: message,
                  kind: kind,
                  // Chuyển nguyên mã ra ngoài: `kind` chỉ nói vĩnh viễn hay
                  // tạm thời, còn người nghe `pushResultStream` cần biết CHÍNH
                  // lỗi nào để phản ứng khác nhau — `BILL_ALREADY_PAID` thì
                  // hoàn tác khoản trả, các mã khác thì không đụng vào.
                  code: code,
                ));
                if (kind == SyncFailureKind.permanent) {
                  // Lỗi vĩnh viễn: dữ liệu hiện tại đẩy bao nhiêu lần cũng
                  // hỏng như vậy. Trước đây bản ghi vẫn nằm ở 'pending' MÃI
                  // MÃI và được gửi lại ở mọi chu kỳ. Chặn theo thời gian —
                  // vẫn còn đường quay lại nếu người dùng sửa dữ liệu.
                  final step = _bacChan();
                  await _markBlockedById(
                    op.entity,
                    op.localId,
                    _now().add(step),
                    message,
                  );
                }
                debugPrint(
                  '[SyncEngine] Push failed [${kind.name}]: '
                  'entity=${op.entity.name}, localId=${op.localId}, '
                  'reason=$message',
                );
              }
            }
          }
        }

        debugPrint(
            '[SyncEngine] Real Sync Complete: $succeeded/${ops.length} synced successfully.');
        return SyncResult(
          totalOps: ops.length,
          succeeded: succeeded,
          failed: failed,
          conflictIds: conflictIds,
          errorMessages: errorMessages,
          failures: failures,
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final reason = e.response?.data?.toString() ?? e.message ?? '$e';
      debugPrint('[SyncEngine] Sync push rejected [HTTP $statusCode]: $reason');

      // Từ 2026-09-03, backend trả 401 cho CẢ batch khi mọi thao tác đều hỏng
      // vì tài khoản không còn tồn tại (xem SESSION_VALIDITY_FINDINGS.md, F3).
      //
      // Trước đây nhánh này trả về một SyncResult có `failures` RỖNG, nên
      // `hasSessionInvalid` luôn false: engine không phát tín hiệu, và việc
      // phát hiện phiên chết phụ thuộc hoàn toàn vào đường vòng qua
      // AuthInterceptor. Nay báo đúng ngay tại đây.
      if (statusCode == 401) {
        return SyncResult(
          totalOps: ops.length,
          succeeded: 0,
          failed: ops.length,
          errorMessages: [reason],
          failures: [
            for (final op in ops)
              SyncOpFailure(
                localId: op.localId,
                entity: op.entity,
                message: reason,
                kind: SyncFailureKind.sessionInvalid,
              ),
          ],
        );
      }

      // Cả batch không tới nơi (mất mạng, timeout, 5xx). Đánh dấu
      // `transportFailed` để KHÔNG thử lại ngay trong cùng chu kỳ — việc thử
      // lại do giãn cách luỹ tiến lo, và cũng để không nhầm thành lỗi dữ liệu
      // rồi chặn oan từng bản ghi.
      return SyncResult(
        totalOps: ops.length,
        succeeded: 0,
        failed: ops.length,
        transportFailed: true,
        quaTaiThuLaiLuc: mocThuLaiKhiQuaTai(
          status: statusCode,
          body: e.response?.data,
          retryAfter: giaTriRetryAfter(e.response?.headers['retry-after']),
          bayGio: _now(),
        ),
        errorMessages: [reason],
        failures: [
          for (final op in ops)
            SyncOpFailure(
              localId: op.localId,
              entity: op.entity,
              message: reason,
              kind: SyncFailureKind.transient,
            ),
        ],
      );
    } catch (e) {
      debugPrint(
          '[SyncEngine] HTTP Sync API Error: $e — Will retry when online');
    }

    return SyncResult(
      totalOps: ops.length,
      succeeded: 0,
      failed: ops.length,
    );
  }

  Future<void> _markSyncedById(SyncEntityType entity, String id) async {
    switch (entity) {
      case SyncEntityType.wallet:
        await _db.walletDao.markSynced(id);
      case SyncEntityType.transaction:
        await _db.transactionDao.markSynced(id);
      case SyncEntityType.category:
        await _db.categoryDao.markSynced(id);
      case SyncEntityType.budget:
        await _db.budgetDao.markSynced(id);
      case SyncEntityType.bill:
        await _db.billDao.markSynced(id);
      case SyncEntityType.goal:
        await _db.goalDao.markSynced(id);
    }
  }

  Future<void> _markBlockedById(
    SyncEntityType entity,
    String id,
    DateTime until,
    String error,
  ) async {
    switch (entity) {
      case SyncEntityType.wallet:
        await _db.walletDao.markSyncBlocked(id, until, error);
      case SyncEntityType.transaction:
        await _db.transactionDao.markSyncBlocked(id, until, error);
      case SyncEntityType.category:
        await _db.categoryDao.markSyncBlocked(id, until, error);
      case SyncEntityType.budget:
        await _db.budgetDao.markSyncBlocked(id, until, error);
      case SyncEntityType.bill:
        await _db.billDao.markSyncBlocked(id, until, error);
      case SyncEntityType.goal:
        await _db.goalDao.markSyncBlocked(id, until, error);
    }
  }

  // ── Phân loại lỗi đẩy dữ liệu ─────────────────────────────────────────────

  /// Mã lỗi ổn định do backend gắn cho lỗi vỡ khoá ngoại tới bảng `account`
  /// (có từ 2026-09-03, xem `docs/superpowers/backend/DA-XONG/SESSION_VALIDITY_FINDINGS.md`).
  static const String accountNotFoundCode = 'ACCOUNT_NOT_FOUND';

  /// Các mã lỗi có cấu trúc mà backend gắn cho một thao tác đẩy khi **thử lại
  /// y nguyên cũng hỏng y như vậy** (`sync.service.js`, hợp đồng 2026-09-07).
  ///
  /// Từ bản vá ấy backend KHÔNG còn trả nguyên văn stack trace của Prisma;
  /// `message` nay là câu tiếng Việt cho người dùng đọc. Nên mọi regex bên
  /// dưới tụt xuống thành **đường dự phòng** cho backend cũ, và phân loại thật
  /// phải đi theo `code`. Bỏ qua điều đó thì lỗi vĩnh viễn im lặng rơi xuống
  /// nhánh `transient` ở cuối hàm — đúng vòng lặp đẩy-lại-mãi mà G3 và G16
  /// sinh ra để chặn.
  ///
  /// `FOREIGN_KEY_VIOLATION` cố ý KHÔNG nằm ở đây: khoá ngoại tới
  /// category/wallet/parent vỡ thường chỉ là sai **thứ tự** đẩy, Pull xong là
  /// đẩy lại được. Khoá ngoại tới `account` cũng không — nó có mã riêng
  /// `ACCOUNT_NOT_FOUND` và nghĩa là phiên chết, không phải dữ liệu hỏng.
  static const Set<String> _permanentCodes = {
    'UNIQUE_VIOLATION',
    'CATEGORY_NAME_DUPLICATE',
    'CONSTRAINT_VIOLATION',
    'FORBIDDEN_SYSTEM_DEFAULT',
    // Ba mã dưới đây đến cùng `7675b35` của backend (2026-09-10). Tập này là
    // danh sách trắng, nên mã chưa có tên ở đây bị gửi lại mãi — xem
    // `FIX_BACKEND_3_REGRESSIONS.md` mục 4.
    //
    // 23505 trên hai partial unique index của `wallet`; chính client xin tách
    // thành mã riêng (`WALLET_SAVING_INDEX.md` mục 4.2).
    'WALLET_NAME_DUPLICATE',
    'WALLET_DEFAULT_DUPLICATE',
    // Chốt trả hai lần. Xếp vĩnh viễn chỉ ngăn việc gửi lại vô ích; nó không
    // làm thao tác bị từ chối chạy được. Chốt từ chối nhầm — như bản `7675b35`
    // chặn cả hoàn tác thanh toán — thì việc sửa thuộc backend.
    'BILL_ALREADY_PAID',
    // Đơn 41 (`DA-XONG/CHAN_TRA_HAI_LAN_THEO_KY.md`, 2026-10-09): server từ
    // chối khoản chi cho một kỳ TRÙNG đã được trả. Thêm trước khi backend lên —
    // danh sách trắng, mã lạ là gửi lại mãi. Backend lên ở `3a5d320c` (gộp
    // `e7570e16`, 2026-10-18).
    'BILL_PERIOD_ALREADY_PAID',
    // Gia đình (spec `2026-10-23-gia-dinh-nen-mong-design.md` mục 4.2; đơn 50
    // mục A + D.3). Thêm TRƯỚC khi backend lên (2026-10-26) — danh sách trắng.
    // `NOT_OWNER`: sửa / xoá hàng của tài khoản khác (tiền đề kiểm chủ sở
    // hữu); bốn mã `HOUSEHOLD_*`: hết quyền ghi vào nhà.
    'NOT_OWNER',
    'HOUSEHOLD_NOT_MEMBER',
    'HOUSEHOLD_READ_ONLY',
    'HOUSEHOLD_CLOSED',
    'HOUSEHOLD_SCOPE_MISMATCH',
    // Hai mã `docs/Family/` đề xuất (`01_NEN_MONG.md` mục 3 — vai không đủ cho
    // thao tác; `02A_VI_CHUNG_GOP_QUY.md` — vượt trần ví chung). Thêm
    // 2026-10-27 khi backend CHƯA chấp nhận tên: backend đổi tên thì sửa ở đây,
    // không thì mã mới rơi về transient và bị gửi lại mãi.
    'HOUSEHOLD_ROLE_FORBIDDEN',
    'HOUSEHOLD_WALLET_LIMIT',
  };

  /// Khoá ngoại trỏ tới bảng `account` bị vỡ nghĩa là `idaccount` đang dùng
  /// không tồn tại trên server — tức phiên đăng nhập đã chết.
  /// Khớp `fk_category_account`, `fk_transaction_account`, `fk_wallet_account`…
  static final RegExp _accountFkPattern =
      RegExp(r'fk_\w+_account', caseSensitive: false);

  /// Backend trả thông báo này khi được yêu cầu xoá một bản ghi nó không có
  /// (`sync.service.js`, nhánh `operation === 'delete'`).
  static final RegExp _recordNotFoundPattern =
      RegExp(r'record not found', caseSensitive: false);

  /// PostgreSQL từ chối vì dữ liệu vi phạm một ràng buộc `CHECK` (SQLSTATE
  /// 23514). Khớp cả mã lẫn câu chữ vì Prisma bọc lỗi theo nhiều cách tuỳ
  /// phiên bản, và mã 23514 là phần ổn định nhất.
  static final RegExp _checkConstraintPattern =
      RegExp(r'23514|violates check constraint', caseSensitive: false);

  /// PostgreSQL từ chối vì dữ liệu trùng một ràng buộc `UNIQUE` (SQLSTATE
  /// 23505). Khớp cả mã, câu chữ của PostgreSQL, và câu chữ Prisma bọc lại —
  /// Prisma đổi cách diễn đạt theo phiên bản, mà mã 23505 là phần ổn định nhất.
  ///
  /// Đường kích hoạt đã gặp thật (G16): người dùng xoá một danh mục cá nhân
  /// mặc định, `PersonalDefaultCategories.ensureMissing()` tạo lại nó với UUID
  /// mới ở **mỗi lần mở app**, rồi đẩy lên đụng chỉ mục tên danh mục của server —
  /// khi ấy chưa có mệnh đề `WHERE` nên hàng đã xoá mềm vẫn giữ chỗ tên. Chỉ mục hiện hành là
  /// `uq_category_owner_name` (khoá `(Create_by, tên chuẩn hoá)`, có `WHERE "Delete_at" IS NULL`, G108).
  ///
  /// ⚠️ Đường **tự lặp** ấy đã đóng ngày 2026-09-05: `ensureMissing()` không
  /// còn, năm danh mục kia nay thuộc bộ mặc định của backend. Nhưng phép phân
  /// loại này vẫn cần — người dùng xoá rồi tạo lại một danh mục **của chính họ**
  /// cùng tên (hoặc hai máy cùng tạo một tên) vẫn đụng chỉ mục tên. Khác biệt là nay nó chỉ xảy ra khi người
  /// dùng thật sự làm điều ấy, chứ không tự sinh ở mỗi lần mở app.
  static final RegExp _uniqueConstraintPattern = RegExp(
    r'23505|violates unique constraint|unique constraint failed',
    caseSensitive: false,
  );

  static SyncFailureKind _classifyFailure(String message, {String? code}) {
    // Ưu tiên mã lỗi ổn định. Khớp chuỗi thông báo của Prisma là cách làm dễ
    // vỡ: đổi tên constraint hay nâng version Prisma là mất khả năng phát hiện
    // phiên chết, mà KHÔNG có lỗi nào báo ra.
    if (code == accountNotFoundCode) {
      return SyncFailureKind.sessionInvalid;
    }

    // Phần còn lại của hợp đồng mã lỗi. Phải đứng TRƯỚC mọi phép khớp chuỗi:
    // khi backend đã gửi `code` thì `message` là câu tiếng Việt, không còn
    // mang mã SQLSTATE nào để mà khớp.
    if (code != null && _permanentCodes.contains(code)) {
      return SyncFailureKind.permanent;
    }
    // Dự phòng cho backend chưa cập nhật — vẫn còn đang chạy ở máy khác.
    if (_accountFkPattern.hasMatch(message)) {
      // Đây chỉ là TÍN HIỆU. Quyết định đăng xuất do AuthBloc đưa ra sau khi
      // hỏi lại server bằng verifySession() — không bao giờ dựa mỗi vào việc
      // khớp chuỗi tên constraint (dễ vỡ khi đổi tên hoặc đổi version Prisma).
      return SyncFailureKind.sessionInvalid;
    }
    // Các khoá ngoại KHÁC (category/wallet/parent) thường chỉ là sai thứ tự
    // đẩy: Pull xong là đẩy lại được.
    if (message.contains('Foreign key constraint')) {
      return SyncFailureKind.transient;
    }
    // Sai chủ sở hữu = dòng dữ liệu sót của tài khoản khác. KHÔNG phải phiên
    // chết — đăng xuất ở đây là sai; dữ liệu đó cần được dọn thay vì thử lại.
    if (message.contains('Ownership mismatch')) {
      return SyncFailureKind.permanent;
    }
    // Dữ liệu vi phạm ràng buộc CHECK của PostgreSQL (mã 23514) thì đẩy bao
    // nhiêu lần cũng hỏng y như vậy — ví dụ ngân sách có `End` không lớn hơn
    // `Start`, vi phạm `chk_budget_end_after_start`. Xếp vào `transient` nghĩa
    // là gửi lại ở MỌI chu kỳ, và mỗi chu kỳ đó kết thúc ở `error` nên kích
    // hoạt giãn cách luỹ tiến (G2), kéo chậm mọi thay đổi khác.
    //
    // `permanent` chặn theo THỜI GIAN chứ không loại vĩnh viễn: người dùng sửa
    // lại dữ liệu là bản ghi quay về hàng đợi.
    if (_checkConstraintPattern.hasMatch(message)) {
      return SyncFailureKind.permanent;
    }
    // Trùng một ràng buộc UNIQUE thì đẩy lại bao nhiêu lần cũng hỏng y như vậy,
    // cho tới khi dữ liệu đổi hoặc backend nới ràng buộc. Xếp `transient` như
    // trước đây nghĩa là gửi lại ở MỌI chu kỳ, và vì `ensureMissing()` sinh
    // thêm một bản trùng ở mỗi lần mở app nên số bản ghi kẹt chỉ tăng (G16).
    // Nguồn tự sinh ấy đã đóng 2026-09-05; ràng buộc thì vẫn còn.
    //
    // `permanent` chặn theo THỜI GIAN chứ không loại vĩnh viễn: khi backend
    // thêm `WHERE "Delete_at" IS NULL` vào index, bản ghi tự quay lại hàng đợi.
    if (_uniqueConstraintPattern.hasMatch(message)) {
      return SyncFailureKind.permanent;
    }
    return SyncFailureKind.transient;
  }
}
