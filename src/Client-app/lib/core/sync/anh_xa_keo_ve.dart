/// Dựng companion từ một hàng `/sync/pull` cho sáu thực thể — tách khỏi `ApDuLieuKeoVe.pullFromBackend` 2026-10-20
/// (file kéo về 743/800 dòng, quét 34). Thân và chú thích **dời nguyên văn**; mọi bước có tác dụng phụ (ghi CSDL, neo số
/// dư, gộp trùng, mốc) ở lại `ApDuLieuKeoVe`. Nội bộ của `core/sync` (quét 35).
///
/// Tham số hàng là `dynamic` như trong vòng `map` cũ (`List<dynamic>` của JSON) — đổi sang `Map` là đổi ngữ nghĩa đọc khoá.
library;

import 'package:drift/drift.dart';

import '../../features/bill/domain/bill_pay_status.dart';
import '../../features/bill/domain/bill_recurrence.dart';
import '../../features/goal/domain/uu_tien_hop_le.dart';
import '../../features/wallet/domain/wallet_status.dart';
import '../category/category_name.dart';
import '../database/app_database.dart';
import 'backend_bool.dart';
import 'bieu_tuong_danh_muc_mac_dinh.dart';
import 'sync_models.dart';
import 'sync_payload_normalizer.dart';

/// 1. Ví.
WalletsCompanion companionViKeoVe(dynamic w, int accountId) {
  return WalletsCompanion(
    id: Value((w['idwallet'] ?? w['id']).toString()),
    idaccount:
        Value(int.tryParse(w['idaccount'].toString()) ?? accountId),
    name: Value(w['name'].toString()),
    type: Value(SyncPayloadNormalizer.walletTypeFromBackend(
        w['type']?.toString() ?? 'Cash')),
    // ⚠️ **KHÔNG đọc số dư của server.**
    //
    // `balance` nay là **cache của tổng sổ giao dịch**
    // (`SoDuViService`), và sổ thì đã đồng bộ đúng. Con số của
    // server chỉ là ảnh chụp cũ, nên đọc nó về là nuốt mọi thay đổi
    // cục bộ chưa kịp đẩy — đúng cơ chế của **G37**, đo thật trên
    // hai máy ảo ngày 2026-09-13: ví bị trừ còn 1.650.000 → push ví
    // xung đột → pull ghi đè về 2.000.000 → lần trừ biến mất, mà
    // hàng vừa bị `GuiLoDongBo._markSyncedById` nên cũng không còn gì để đẩy
    // lại.
    //
    // Ví MỚI về từ máy khác không cần cột này để đúng: lần INSERT
    // đầu lấy mặc định `0`, nhưng **neo là một giao dịch** nên nó
    // cũng được pull về cùng lượt, và bước tính lại cuối `ApDuLieuKeoVe.pullFromBackend`
    // cho ra đúng số.
    balance: const Value.absent(),
    currency: Value(w['currency']?.toString() ?? 'VND'),
    icon: Value(w['icon']?.toString() ?? 'wallet'),
    colour: Value(
        (w['color'] ?? w['colour'])?.toString() ?? '#4CAF50'),
    isDefault: Value(doiSangBool(w['is_default'])),
    // Server im lặng về cờ này nghĩa là CHƯA BIẾT, không phải
    // "hãy loại ví khỏi tổng": `doiSangBool(null)` trả `false`, nên
    // đọc thẳng sẽ lặng lẽ tắt cờ của mọi ví ngay lượt pull đầu
    // tiên gặp một payload thiếu khoá — cùng bài học với `idgoal`.
    includeInTotal: w['include_in_total'] != null
        ? Value(doiSangBool(w['include_in_total']))
        : const Value.absent(),
    // `status` (lưu trữ ví) đi qua đồng bộ **hai chiều** từ
    // 2026-09-14 — G28. Trước đó nó là cột cục bộ vì lược đồ
    // PostgreSQL tự mâu thuẫn ở đúng đây: `chk_wallet_status` cho
    // phép `'Inactive'` trong khi kiểu cột là `varchar(7)` còn
    // chuỗi ấy dài 8 ký tự, nên ví lưu trữ đẩy lên là **kẹt hàng
    // đợi đẩy vĩnh viễn, im lặng** (vấp thật trên máy ảo
    // 2026-09-10). Đo lại 2026-09-14: `varchar(20)`, `NOT NULL`,
    // `DEFAULT 'Active'`.
    //
    // Lưu **chữ thường**: cột SQLite mặc định `'active'` và hợp
    // đồng ghi ở `wallet_entity.dart` là `'active' | 'inactive'`.
    // Trộn hai cách viết thì mọi câu SQL thô so chuỗi trực tiếp
    // lọc lệch — `WalletDao.getActive` cố ý lọc ở tầng Dart chính
    // vì chờ đúng nhánh này.
    //
    // Thiếu khoá nghĩa là **chưa biết**, không phải "hãy đánh
    // thức": cột của server hiện `NOT NULL` nên nó luôn trả giá
    // trị, nhưng `absent` là lớp phòng thủ trước một bản backend
    // không trả khoá ấy — cùng bài học với `include_in_total`.
    status: w['status'] != null
        ? Value(WalletStatus.tuKhoa(w['status'].toString()).khoa)
        : const Value.absent(),
    isDeleted: Value(w['delete_at'] != null),
    deletedAt: Value(_deletedAtFrom(w['delete_at'])),
    syncStatus: const Value('synced'),
    updatedAt: Value(
        DateTime.tryParse(w['update_at']?.toString() ?? '') ??
            DateTime.now()),
  );
}

/// 2. Giao dịch.
TransactionsCompanion companionGiaoDichKeoVe(dynamic t, int accountId) {
  return TransactionsCompanion(
    id: Value((t['idtran'] ?? t['id']).toString()),
    idaccount:
        Value(int.tryParse(t['idaccount'].toString()) ?? accountId),
    walletId: Value((t['idwallet'] ?? t['wallet_id']).toString()),
    categoryId: Value((t['idcategory'] ?? t['category_id'])?.toString()),
    walletTransfer: Value(
        (t['idwallet_transfer'] ?? t['wallet_transfer'])
            ?.toString()),
    amount: Value((num.tryParse(t['amount'].toString()) ?? 0.0)
        .abs()
        .toDouble()),
    type: Value(SyncPayloadNormalizer.transactionTypeFromBackend(
      t['type']?.toString() ?? 'Transaction',
      num.tryParse(t['amount'].toString()) ?? 0,
    )),
    note: Value(t['note']?.toString() ?? ''),
    // Server im lặng về `idgoal` nghĩa là **chưa biết**, không
    // phải **hãy xoá**. Cột `transaction.Idgoal` mới có ngày
    // 2026-09-07, nên mọi hàng đã nằm sẵn trên server đều mang
    // NULL cho tới khi client đẩy lại từng hàng một. Gán thẳng
    // `Value(null)` ở đây là xoá sạch liên kết cục bộ ngay ở chu
    // kỳ đồng bộ đầu tiên — và lịch sử tích luỹ lặng lẽ rơi hết
    // xuống nhánh so TÊN, tức tái hiện nguyên vẹn G18.
    //
    // `Value.absent()` để Drift bỏ qua cột này khi ghi đè, giữ
    // nguyên giá trị đang có. Đánh đổi: server KHÔNG gỡ được liên
    // kết theo chiều này — chấp nhận được, vì chỉ client đặt nó.
    goalId: (t['idgoal'] ?? t['goal_id']) != null
        ? Value((t['idgoal'] ?? t['goal_id']).toString())
        : const Value.absent(),
    // Cùng luật với `idgoal` ngay trên, và cùng lý do: cột
    // `transaction.Idbill` chỉ đi qua đồng bộ từ 2026-09-12, nên
    // hàng đã nằm sẵn trên server mang NULL cho tới khi client đẩy
    // lại từng hàng. Gán thẳng `Value(null)` là xoá liên kết cục bộ
    // ngay chu kỳ pull đầu tiên, và hoàn tác thanh toán mất đường
    // lần về khoản chi.
    billId: (t['idbill'] ?? t['bill_id']) != null
        ? Value((t['idbill'] ?? t['bill_id']).toString())
        : const Value.absent(),
    date: Value(DateTime.tryParse(
            (t['date_transaction'] ?? t['date'])?.toString() ?? '') ??
        DateTime.now()),
    isDeleted: Value(t['deleted_at'] != null),
    deletedAt: Value(_deletedAtFrom(t['deleted_at'])),
    syncStatus: const Value('synced'),
    updatedAt: Value(
        DateTime.tryParse(t['update_at']?.toString() ?? '') ??
            DateTime.now()),
  );
}

/// 3. Danh mục. [existingLocal] là hàng cục bộ cùng id (người gọi đọc, đã bỏ hàng `isLocalOnly`) — biểu tượng / màu rơi
/// về nó khi server trả rỗng.
CategoriesCompanion companionDanhMucKeoVe(
  dynamic c, {
  required String catUuid,
  required String catName,
  required Category? existingLocal,
}) {
  final rawIcon = c['icon']?.toString();
  // Backend trả `color` (G24). `null` nghĩa là server CHƯA có màu —
  // nhánh dưới rơi về màu cục bộ chứ không xoá nó.
  final rawColor = c['color']?.toString();

  String finalIcon;
  if (rawIcon != null &&
      rawIcon.isNotEmpty &&
      rawIcon != 'category') {
    finalIcon = rawIcon;
  } else if (existingLocal != null &&
      existingLocal.icon.isNotEmpty &&
      existingLocal.icon != 'category') {
    finalIcon = existingLocal.icon;
  } else {
    finalIcon = defaultIconForCategoryName(catName);
  }

  String finalColor;
  if (rawColor != null && rawColor.isNotEmpty) {
    finalColor = rawColor;
  } else if (existingLocal != null &&
      existingLocal.colour.isNotEmpty) {
    finalColor = existingLocal.colour;
  } else {
    finalColor = defaultColorForCategoryName(catName);
  }

  return CategoriesCompanion(
    id: Value(catUuid),
    idaccount: Value(c['is_default'] == true
        ? 0
        : (int.tryParse(
                // Backend Prisma field là `create_by` (không có
                // 'd'). Giữ 'created_by'/'idaccount' làm fallback
                // để tương thích ngược nếu payload thay đổi.
                (c['create_by'] ?? c['created_by'] ?? c['idaccount'] ?? 0)
                    .toString()) ??
            0)),
    name: Value(catName),
    classify: Value(SyncPayloadNormalizer.categoryClassifyFromBackend(
        c['classify']?.toString() ?? 'Chi')),
    icon: Value(finalIcon),
    colour: Value(finalColor),
    isDefault: Value(doiSangBool(c['is_default'])),
    // Cấu trúc nhóm do backend lưu (Is_group / Idgroup). BẮT BUỘC
    // phải đọc lại: upsertAll dùng InsertMode.insertOrReplace nên
    // cột nào không gán sẽ bị đưa về mặc định — trước đây điều này
    // xoá sạch nhóm và quan hệ cha–con ở local sau mỗi lần pull.
    isGroup: Value(doiSangBool(c['is_group'])),
    parentId: Value((c['idgroup'] ?? c['parent_id'])?.toString()),
    // Đọc cờ xoá từ payload như các thực thể khác. Trước đây ghi
    // cứng `false`, nên danh mục đã xoá mềm trên server bị HỒI SINH
    // thành chưa-xoá sau mỗi lần pull — backend không lọc
    // `delete_at` khi trả dữ liệu nên nó vẫn nằm trong response.
    isDeleted: Value(c['delete_at'] != null),
    deletedAt: Value(_deletedAtFrom(c['delete_at'])),
    syncStatus: const Value('synced'),
    updatedAt: Value(
        DateTime.tryParse(c['update_at']?.toString() ?? '') ??
            DateTime.now()),
  );
}

/// 4. Ngân sách.
BudgetsCompanion companionNganSachKeoVe(dynamic b, int accountId) {
  // Backend trả field Prisma thật: idbudget, idcategory,
  // total_amount, start, end, delete_at, update_at (không phải
  // id/category_id/amount/start_date/is_deleted/updated_at).
  return BudgetsCompanion(
    id: Value((b['idbudget'] ?? b['id']).toString()),
    idaccount:
        Value(int.tryParse(b['idaccount'].toString()) ?? accountId),
    categoryId: Value((b['idcategory'] ?? b['category_id'])?.toString()),
    amount: Value((num.tryParse(
                (b['total_amount'] ?? b['amount']).toString()) ??
            0.0)
        .toDouble()),
    spent: Value(
        (num.tryParse((b['spent'] ?? 0).toString()) ?? 0.0)
            .toDouble()),
    thresholdWarningAmount: Value(
        b['threshold_warning_amount'] != null
            ? num
                .tryParse(b['threshold_warning_amount'].toString())
                ?.toDouble()
            : null),
    // Backend lưu 0–100 (`Decimal(15,2)`), client giữ nguyên đơn vị
    // đó — việc quy về tỉ lệ nằm ở `BudgetEntity.warningRatio`.
    thresholdWarningPercent: Value(
        b['threshold_warning_percent'] != null
            ? num
                .tryParse(b['threshold_warning_percent'].toString())
                ?.toDouble()
            : null),
    overSpending: Value(b['over_spending']?.toString() ?? 'Over'),
    overAmount: Value(b['over_amount'] != null
        ? num.tryParse(b['over_amount'].toString())?.toDouble()
        : null),
    startDate: Value(DateTime.tryParse(
            (b['start'] ?? b['start_date'])?.toString() ?? '') ??
        DateTime.now()),
    endDate: Value((b['end'] ?? b['end_date']) != null
        ? DateTime.tryParse((b['end'] ?? b['end_date']).toString())
        : null),
    recurrence: Value(doiSangBool(b['recurrence'])),
    timeRecurrence:
        Value(b['time_recurrence']?.toString() ?? 'Month'),
    nextTimeRecurrence: Value(b['nexttime_recurrence'] != null
        ? DateTime.tryParse(b['nexttime_recurrence'].toString())
        : null),
    note: Value(b['note']?.toString() ?? ''),
    isDeleted: Value(b['delete_at'] != null),
    deletedAt: Value(_deletedAtFrom(b['delete_at'])),
    syncStatus: const Value('synced'),
    updatedAt: Value(DateTime.tryParse(
            (b['update_at'] ?? b['updated_at'])?.toString() ??
                '') ??
        DateTime.now()),
  );
}

/// 5. Hoá đơn.
BillsCompanion companionHoaDonKeoVe(dynamic bill, int accountId) {
  // Backend trả field Prisma thật: idbill, idwallet, idcategory,
  // start_date, due_date, pay_status, delete_at, update_at
  // (không phải id/is_paid/is_deleted/updated_at).
  final payStatus = bill['pay_status']?.toString() ?? 'Pending';
  final isRecurrence = doiSangBool(bill['recurrence']);
  final timeRecurrence =
      bill['time_recurrence']?.toString() ?? kBillCycleMonth;
  return BillsCompanion(
    id: Value((bill['idbill'] ?? bill['id']).toString()),
    idaccount: Value(
        int.tryParse(bill['idaccount'].toString()) ?? accountId),
    walletId:
        Value((bill['idwallet'] ?? bill['wallet_id'])?.toString()),
    categoryId: Value(
        (bill['idcategory'] ?? bill['category_id'])?.toString()),
    name: Value(bill['name'].toString()),
    amount: Value((num.tryParse(bill['amount'].toString()) ?? 0.0)
        .toDouble()),
    startDate: Value(bill['start_date'] != null
        ? DateTime.tryParse(bill['start_date'].toString())
        : null),
    dueDate: Value(
        DateTime.tryParse(bill['due_date']?.toString() ?? '') ??
            DateTime.now()),
    payStatus: Value(payStatus),
    isPaid: Value(payStatus == kBillPayed),
    timeNotification: Value(bill['time_notification']?.toString()),
    isRecurrence: Value(isRecurrence),
    timeRecurrence: Value(timeRecurrence),
    // Cột chuỗi cũ phải ghi CÙNG LÚC. Bỏ trống nó là để nó rơi về
    // mặc định 'monthly' của bảng, nên một hoá đơn không lặp kéo
    // về từ backend vẫn trông như hoá đơn hàng tháng với bất kỳ
    // chỗ nào còn đọc cột cũ — sai lệch im lặng (quy tắc 4).
    recurrence: Value(
      isRecurrence ? legacyFromTimeRecurrence(timeRecurrence) : 'once',
    ),
    icon: Value(bill['icon']?.toString() ?? 'receipt'),
    colour: Value(bill['color']?.toString() ?? '#4CAF50'),
    note: Value(bill['note']?.toString() ?? ''),
    // Server im lặng nghĩa là **chưa biết**, không phải **hãy
    // xoá**: hai cột này chỉ đi qua đồng bộ từ 2026-09-12, nên mọi
    // hàng đã nằm sẵn trên server mang NULL cho tới khi client đẩy
    // lại từng hàng. Gán thẳng `Value(null)` là cắt đứt chuỗi kỳ và
    // xoá ngày gốc ngay chu kỳ pull đầu tiên — cùng bài học với
    // `idgoal`, và mất ngày gốc thì ngày đến hạn quay về bị ĐOÁN.
    generatedFromBillId: bill['previous_bill_id'] != null
        ? Value(bill['previous_bill_id'].toString())
        : const Value.absent(),
    anchorDay: bill['anchor_day'] != null
        ? Value(int.tryParse(bill['anchor_day'].toString()))
        : const Value.absent(),
    // Cùng luật với hai cột trên: server im lặng = CHƯA BIẾT. Hàng
    // cũ trên server mang NULL cho tới khi client đẩy lại; gán
    // thẳng là xoá ngày kết thúc kỳ và kỳ sau lại nối từ hạn trả
    // (ân hạn, v21 — 2026-09-12).
    periodEnd: bill['period_end'] != null
        ? Value(DateTime.tryParse(bill['period_end'].toString()))
        : const Value.absent(),
    // Cùng luật nốt: cột này chỉ đi qua đồng bộ từ 2026-09-13 (bước
    // 12), nên hàng đã nằm sẵn trên server mang NULL cho tới khi
    // client đẩy lại từng hàng. Gán thẳng `Value(false)` là TẮT tự
    // động trả của mọi hoá đơn ngay chu kỳ pull đầu tiên — người
    // dùng không được báo gì và chỉ phát hiện ra khi một hoá đơn
    // đến hạn mà không ai trả.
    autoPayEnabled: bill['auto_pay'] != null
        ? Value(bill['auto_pay'] == true)
        : const Value.absent(),
    isDeleted: Value(bill['delete_at'] != null),
    deletedAt: Value(_deletedAtFrom(bill['delete_at'])),
    syncStatus: const Value('synced'),
    updatedAt: Value(DateTime.tryParse(
            (bill['update_at'] ?? bill['updated_at'])
                    ?.toString() ??
                '') ??
        DateTime.now()),
  );
}

/// 6. Mục tiêu.
GoalsCompanion companionMucTieuKeoVe(dynamic g, int accountId) {
  // Backend trả field Prisma thật: idgoal, idwallet,
  // status_complete, delete_at, update_at (không phải
  // id/wallet_id/is_deleted/updated_at).
  return GoalsCompanion(
    id: Value((g['idgoal'] ?? g['id']).toString()),
    idaccount:
        Value(int.tryParse(g['idaccount'].toString()) ?? accountId),
    name: Value(g['name'].toString()),
    targetAmount: Value(
        (num.tryParse(g['target_amount'].toString()) ?? 0.0)
            .toDouble()),
    currentAmount: Value(
        (num.tryParse(g['current_amount'].toString()) ?? 0.0)
            .toDouble()),
    startDate: Value(g['start_date'] != null
        ? DateTime.tryParse(g['start_date'].toString())
        : null),
    targetDate: Value(
        DateTime.tryParse(g['target_date']?.toString() ?? '') ??
            DateTime.now()),
    walletId: Value((g['idwallet'] ?? g['wallet_id'])?.toString()),
    cycleTakeMoney: Value(g['cycle_take_money']?.toString()),
    timeCycleTakeMoney: Value(g['time_cycle_take_money'] != null
        ? DateTime.tryParse(g['time_cycle_take_money'].toString())
        : null),
    autoDepositAmount: Value(
        num.tryParse(g['auto_deposit_amount']?.toString() ?? '')
            ?.toDouble()),
    autoDepositWalletId:
        Value(g['auto_deposit_wallet_id']?.toString()),
    autoDepositLastRun: Value(g['auto_deposit_last_run'] != null
        ? DateTime.tryParse(g['auto_deposit_last_run'].toString())
        : null),
    // `doiSangBool` chứ không so cứng: `Recurrence` là boolean
    // thật còn `Status_complete` là chuỗi — hai kiểu khác nhau
    // trong CÙNG một bảng. So khớp cứng từng kiểu thì chỉ cần một
    // bên đổi cách tuần tự hoá là cờ lặng lẽ về `false`.
    recurrence: Value(doiSangBool(g['recurrence'])),
    timeRecurrence: Value(g['time_recurrence']?.toString()),
    // `int.tryParse` trên chuỗi: Prisma trả `Priority` là số,
    // nhưng JSON đi qua nhiều tầng và một giá trị `"200"` phải
    // đọc được. Giá trị rác về `null` — tức "chưa sắp", xếp cuối —
    // thay vì làm hỏng cả hàng.
    // `<= 0` là `null` bị backend ép (G32 — backend sửa ở `7675b35`,
    // nhưng hàng cũ còn có thể mang `0`): lưu nguyên thì mục tiêu
    // chưa sắp đứng đầu danh sách — xem `uu_tien_hop_le.dart`.
    priority: Value(uuTienHopLe(
        int.tryParse(g['priority']?.toString() ?? ''))),
    icon: Value(g['icon']?.toString() ?? 'flag'),
    colour: Value(g['color']?.toString() ?? '#4CAF50'),
    note: Value(g['note']?.toString() ?? ''),
    isCompleted: Value(doiSangBool(g['status_complete'])),
    isDeleted: Value(g['delete_at'] != null),
    deletedAt: Value(_deletedAtFrom(g['delete_at'])),
    syncStatus: const Value('synced'),
    updatedAt: Value(DateTime.tryParse(
            (g['update_at'] ?? g['updated_at'])?.toString() ??
                '') ??
        DateTime.now()),
  );
}

/// Đọc mốc thời điểm xoá mềm từ payload backend cho khối Pull.
///
/// Cờ xoá phải ghi vào **cả hai** cột `isDeleted` và `deletedAt`. Mọi
/// `getAll`/`watchAll` trong dự án lọc theo `deletedAt.isNull()`, KHÔNG theo
/// `isDeleted` — nên nếu chỉ bật cờ boolean thì bản ghi đã xoá trên máy khác
/// vẫn hiện ra sau khi pull, không exception và không log.
///
/// Chuỗi hỏng vẫn trả về một mốc (giờ hiện tại) thay vì `null`: đã biết chắc
/// bản ghi bị xoá thì thà lệch vài giây còn hơn để nó sống lại.
///
/// Lưu ý tên cột không nhất quán ở backend: bảng `transaction` dùng
/// `deleted_at`, các bảng còn lại dùng `delete_at` — nơi gọi phải truyền đúng
/// khoá, hàm này không tự đoán.
DateTime? _deletedAtFrom(dynamic raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString()) ?? DateTime.now();
}

/// So hàng khuôn ĐÃ CÓ trên máy ([cu]) với bản vừa về (tên / biểu tượng SAU ánh xạ — [moi] — và từ khoá [tuKhoaMoi]): khác
/// thì một [ThayDoiKhuon], còn lại `null` (spec 2026-10-27 mục 5). [laKhuon]: hàng về là khuôn (`is_default`), CÒN SỐNG HAY ĐÃ
/// XOÁ — khuôn về đã xoá vẫn lan truyền tên / biểu tượng (admin đổi tên rồi xoá giữa hai lượt kéo; bỏ qua thì bản sao không
/// theo kịp tên mới, và khi admin khôi phục khuôn bộ tạo bản sao mọc thêm một bản). Nơi gọi truyền `tuKhoaCu == tuKhoaMoi`
/// cho khuôn đã xoá nên từ khoá không bao giờ sinh thay đổi (người dùng chốt 2026-10-27).
///
/// Khuôn trên máy còn `icon = 'category'` (server chưa từng gửi icon) thì `companionDanhMucKeoVe` rơi về
/// `defaultIconForCategoryName(catName)` → lượt đầu khuôn ấy về lại sinh một [ThayDoiKhuon] biểu tượng "giả"; vô hại và
/// luỹ đẳng (lan truyền chỉ đụng bản sao còn đúng icon cũ, lượt sau hết).
ThayDoiKhuon? thayDoiKhuonTu({
  required Category? cu,
  required CategoriesCompanion moi,
  required bool laKhuon,
  required List<String> tuKhoaCu,
  required List<String> tuKhoaMoi,
}) {
  if (cu == null || !cu.isDefault || !laKhuon) return null;
  final tenMoi = moi.name.value;
  final iconMoi = moi.icon.value;
  final a = {for (final k in tuKhoaCu) normalizeCategoryName(k)}..remove('');
  final b = {for (final k in tuKhoaMoi) normalizeCategoryName(k)}..remove('');
  final cungTuKhoa = a.length == b.length && a.containsAll(b);
  if (normalizeCategoryName(cu.name) == normalizeCategoryName(tenMoi) && cu.icon == iconMoi && cungTuKhoa) return null;
  return ThayDoiKhuon(
    id: cu.id,
    loai: cu.classify,
    tenCu: cu.name,
    tenMoi: tenMoi,
    iconCu: cu.icon,
    iconMoi: iconMoi,
    tuKhoaCu: List.unmodifiable(tuKhoaCu),
    tuKhoaMoi: List.unmodifiable(tuKhoaMoi),
  );
}
