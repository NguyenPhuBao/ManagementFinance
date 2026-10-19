/// Kéo dữ liệu của tài khoản từ `/sync/pull` về SQLite và giữ mốc kéo — tách khỏi `SyncEngine` 2026-10-19 (spec
/// `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`). Thân dời nguyên văn.
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../features/bill/domain/bill_pay_status.dart';
import '../../features/bill/domain/bill_recurrence.dart';
import '../../features/goal/domain/uu_tien_hop_le.dart';
import '../../features/wallet/domain/wallet_status.dart';
import '../api/dio_client.dart';
import '../database/app_database.dart';
import 'backend_bool.dart';
import 'bieu_tuong_danh_muc_mac_dinh.dart';
import 'cong_so_du_vi.dart';
import 'gieo_tu_khoa.dart';
import 'moc_keo_ve.dart';
import 'sync_checkpoint_store.dart';
import 'sync_payload_normalizer.dart';
import 'uuid_dong_bo.dart';

/// Chỉ `SyncEngine` dựng lớp này. Nó SỞ HỮU trạng thái kéo — mốc, cờ đã kéo xong, bộ đếm — nên engine chạm trạng thái
/// ấy qua đúng ba lối: [napMoc] (lúc `start`), [napMocNeuChuaCo] (lúc `syncMotLuot`), [datLaiPhien] (lúc `stop`).
class ApDuLieuKeoVe {
  ApDuLieuKeoVe({
    required DioClient dioClient,
    required AppDatabase db,
    required CongSoDuVi soDuVi,
    SyncCheckpointStore? checkpointStore,
  })  : _dioClient = dioClient,
        _db = db,
        _soDuVi = soDuVi,
        _checkpointStore = checkpointStore;

  final DioClient _dioClient;
  final AppDatabase _db;

  /// Nơi duy nhất ghi `wallets.balance` — `SoDuViService`, qua cổng (G88 gạch 4). Dùng ở cuối mỗi lần kéo về.
  final CongSoDuVi _soDuVi;

  /// Nơi lưu mốc pull gần nhất. Null (thường là trong test) → chỉ giữ trong RAM
  /// như hành vi cũ.
  final SyncCheckpointStore? _checkpointStore;

  DateTime? _lastPullTime;

  /// Đã kéo về thành công ít nhất một lần trong phiên này chưa — lý do và cách dùng ở docstring của
  /// `SyncEngine.hasCompletedPull`.
  bool get daKeoXong => _hasCompletedPull;
  bool _hasCompletedPull = false;

  /// Số lần kéo về THÀNH CÔNG trong đời engine — lý do ở docstring của `SyncEngine.soLanKeoVeXong`. [datLaiPhien] KHÔNG
  /// đặt lại nó.
  int get soLanKeoVeXong => _soLanKeoVeXong;
  int _soLanKeoVeXong = 0;

  /// Lúc `SyncEngine.start`: nạp mốc đã lưu của [idaccount].
  Future<void> napMoc(int idaccount) async {
    // Khôi phục mốc pull đã lưu để không phải kéo lại toàn bộ dữ liệu mỗi lần
    // mở app. Nếu SQLite cục bộ rỗng, pullFromBackend vẫn tự ép full pull nên
    // không sợ thiếu dữ liệu khi cài lại app.
    //
    // Mốc ở TƯƠNG LAI thì coi như không có, và lần pull kế tiếp quay về kéo
    // toàn bộ. Máy đã dính mốc hỏng phải tự thoát ra được: chặn ở đầu ghi thôi
    // thì chúng vẫn kẹt cho tới khi thời gian thật đuổi kịp — trên máy ảo
    // 2026-09-05 là hai tháng không nhận được gì.
    _lastPullTime = mocPullConDungKhong(
      await _checkpointStore?.read(idaccount),
      DateTime.now().toUtc(),
    );
  }

  /// Lúc `SyncEngine.syncMotLuot`: mốc đã có trong RAM thì giữ, KHÔNG đọc checkpoint.
  Future<void> napMocNeuChuaCo(int idaccount) async {
    _lastPullTime ??= mocPullConDungKhong(
      await _checkpointStore?.read(idaccount),
      DateTime.now().toUtc(),
    );
  }

  /// Lúc `SyncEngine.stop`: phiên sau có thể là tài khoản khác.
  void datLaiPhien() {
    // Phiên sau có thể là tài khoản khác — cờ của phiên này không nói được gì
    // về CSDL cục bộ của tài khoản đó.
    _hasCompletedPull = false;
    // Chỉ xoá mốc trong RAM. Mốc đã lưu được giữ lại theo từng idaccount để lần
    // đăng nhập sau vẫn pull tăng dần; nếu dữ liệu cục bộ đã bị xoá thì
    // pullFromBackend tự ép full pull.
    _lastPullTime = null;
  }

  // ── Pull data from backend to local SQLite ────────────────────────────────

  Future<void> pullFromBackend(int accountId) async {
    final allWallets = await _db.walletDao.getAll(accountId);
    final isLocalDbEmpty = allWallets.isEmpty;

    final since = (isLocalDbEmpty || _lastPullTime == null)
        ? '1970-01-01T00:00:00.000Z'
        : _lastPullTime!.toUtc().toIso8601String();

    debugPrint(
        '[SyncEngine] Pulling data from backend for account $accountId since $since (isLocalDbEmpty: $isLocalDbEmpty)...');
    try {
      final response = await _dioClient.dio.get(
        '/sync/pull',
        queryParameters: {'since': since},
      );

      if (response.statusCode == 200 && response.data != null) {
        final topData = response.data['data'] as Map<String, dynamic>?;
        // ResponseHandler bọc dữ liệu thành topData['data']['wallets']...
        final Map<String, dynamic>? payloadData =
            (topData != null && topData['data'] is Map<String, dynamic>)
                ? topData['data'] as Map<String, dynamic>?
                : topData;

        if (payloadData != null) {
          // 1. Wallets
          final wallets = (payloadData['wallets'] ?? payloadData['wallet'])
                  as List<dynamic>? ??
              [];

          // Ví đã có TRƯỚC lượt kéo về này. Chỉ chúng mới được vá neo — xem
          // `viDungToi` ngay trước khi ghi giao dịch.
          final viDaCoTruocPull = {
            for (final w in await _db.walletDao.getAll(accountId)) w.id,
          };
          if (wallets.isNotEmpty) {
            final companions = wallets.map((w) {
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
                // cũng được pull về cùng lượt, và bước tính lại cuối hàm này
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
            }).toList();
            await _db.walletDao.upsertAll(companions);
            // G63 (spec 2026-10-05 mục 4.6): ví mặc định server gửi xuống là
            // ví mặc định DUY NHẤT trên máy — người dùng chốt "bản server thắng".
            // `upsertAll` ghi đúng cờ cho hàng kéo về nhưng không đụng hàng chỉ
            // có trên máy, nên máy từng mang HAI ví mặc định (Realme 2026-10-03).
            // Chỉ khi lô kéo về CÓ ví mặc định: pull là tăng dần, "không thấy"
            // không có nghĩa "server không có" (bẫy 8).
            final idMacDinhServer = _idViMacDinhTrongLo(wallets);
            if (idMacDinhServer != null) {
              await _db.walletDao.clearDefaultExcept(
                idaccount: accountId,
                keepId: idMacDinhServer,
              );
            }
            debugPrint(
                '[SyncEngine] Pulled & Saved ${wallets.length} wallets into SQLite local.');
          }

          // 2. Transactions
          final transactions = (payloadData['transactions'] ??
                  payloadData['transaction']) as List<dynamic>? ??
              [];
          // Ví mà lượt kéo này đụng tới: ví vừa về, ví của giao dịch vừa về, và
          // ví ĐÍCH của khoản chuyển vừa về (`tongTheoVi` cộng khoản chuyển đến).
          final viDungToi = <String>{
            for (final t in transactions)
              if (t is Map) ...[
                if ((t['idwallet'] ?? t['wallet_id']) != null)
                  (t['idwallet'] ?? t['wallet_id']).toString(),
                if ((t['idwallet_transfer'] ?? t['wallet_transfer']) != null)
                  (t['idwallet_transfer'] ?? t['wallet_transfer']).toString(),
              ],
            for (final w in wallets)
              if (w is Map && (w['idwallet'] ?? w['id']) != null)
                (w['idwallet'] ?? w['id']).toString(),
          };
          // Vá neo cho ví đã có trên máy nhưng chưa có khoản mở sổ (ví tạo bằng
          // bản app trước 2026-09-13, **và ví server tự tạo khi đăng ký** — hai
          // ví seed không bao giờ có neo) — **TRƯỚC khi ghi giao dịch vừa kéo
          // vào sổ**. Neo tính bằng `balance − Σ sổ`; vá SAU khi ghi là neo nuốt
          // luôn giao dịch của máy kia, đúng bẫy "thời điểm đặt neo" của G37.
          // Đo thật hai máy ảo 2026-10-08 (nghiệm thu G67): ví Tiết kiệm seed,
          // B −11.000 offline, kéo về −22.000 của A → neo +22.000, số dư cả hai
          // máy −11.000 thay vì −33.000.
          //
          // ⚠️ Ví VỪA về không được vá, và đây là chốt chặn bắt buộc. Ví vừa
          // INSERT mang `balance = 0` (nhánh trên thôi đọc cột ấy) trong khi sổ
          // của nó đầy đủ; vá nó là sinh một khoản chi bằng cả tổng sổ (đo thật
          // 2026-09-13: ví 2.000.000 hiện thành `Total balance: 0đ`). Neo của ví
          // vừa về — nếu có — là một giao dịch, về cùng lượt.
          await _soDuVi.datNeoNhieuVi(viDungToi.intersection(viDaCoTruocPull));
          if (transactions.isNotEmpty) {
            final companions = transactions.map((t) {
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
            }).toList();
            await _db.transactionDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${transactions.length} transactions into SQLite local.');
          }

          // 3. Categories
          final categories = (payloadData['categories'] ??
                  payloadData['category']) as List<dynamic>? ??
              [];
          if (categories.isNotEmpty) {
            final List<CategoriesCompanion> companions = [];
            // Từ khoá phân loại backend gửi kèm mỗi danh mục, gom lại để gieo
            // SAU khi hàng danh mục đã tồn tại ở local.
            final Map<String, List<String>> tuKhoaTheoDanhMuc = {};
            for (final c in categories) {
              final catUuid = (c['idcategory'] ?? c['uuid'] ?? c['id'])
                  .toString();
              if (catUuid.isEmpty || catUuid == 'null') {
                debugPrint('[SyncEngine] Skipping category without an ID.');
                continue;
              }
              final catName =
                  (c['name_category'] ?? c['namecategory'] ?? c['name'] ?? '')
                      .toString();
              final rawIcon = c['icon']?.toString();
              // Backend trả `color` (G24). `null` nghĩa là server CHƯA có màu —
              // nhánh dưới rơi về màu cục bộ chứ không xoá nó.
              final rawColor = c['color']?.toString();

              final existingLocal = await _db.categoryDao.getById(catUuid);
              if (existingLocal?.isLocalOnly == true) {
                continue;
              }
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

              companions.add(CategoriesCompanion(
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
              ));

              // Backend lưu từ khoá thành MỘT chuỗi nối bằng dấu phẩy trên hàng
              // category (`classify.repository.js` ghi bằng `join(',')`), client
              // lưu mỗi từ khoá một dòng có `idaccount`. Không tách ra thì cả
              // chuỗi thành một "từ khoá" dài và không bao giờ khớp gì.
              final tuKhoa = (c['keyword'] ?? c['Keyword'])
                      ?.toString()
                      .split(',')
                      .map((k) => k.trim())
                      .where((k) => k.isNotEmpty)
                      .toList() ??
                  const <String>[];
              if (tuKhoa.isNotEmpty && c['delete_at'] == null) {
                tuKhoaTheoDanhMuc[catUuid] = tuKhoa;
              }
            }
            await _db.categoryDao.upsertAll(companions);
            await gieoTuKhoaKhiTrong(_db, accountId, tuKhoaTheoDanhMuc);
            // Repair TRƯỚC: cập nhật categoryId từ 'cat_food' → UUID trong các
            // pending transactions. PHẢI chạy trước removeDuplicateLocalSeedCategories()
            // vì resolveCategoryId cần getById('cat_food') để đọc tên category rồi
            // tìm UUID cùng tên — nếu seed 'cat_food' đã bị xóa trước, getById() trả
            // về null và repair sẽ luôn thất bại (transaction bị defer vĩnh viễn).
            final repaired = await _db.transactionDao
                .repairPendingTransactionsCategoryId((id) => resolveCategoryId(_db, id));
            if (repaired > 0) {
              debugPrint(
                  '[SyncEngine] Repaired $repaired transactions: updated categoryId to UUID.');
            }
            // Xóa category seed cục bộ (cat_food...) đã có bản UUID từ backend —
            // chạy SAU repair ở trên để không xóa mất row mà repair cần đọc.
            await _db.categoryDao.removeDuplicateLocalSeedCategories();
            // Dọn bản trùng do chính máy này tạo ra trước khi kịp pull (G14).
            // Chạy SAU cùng: hai bước trên vừa dựng lại quan hệ, giờ mới nhìn
            // được toàn cảnh tài khoản đang có gì. Không dọn thì mỗi bản trùng
            // là một thao tác đẩy hỏng vĩnh viễn, và giãn cách luỹ tiến kéo
            // chậm mọi thay đổi khác.
            final gopTrung = await _db.categoryDao
                .mergeDuplicatePersonalCategories(accountId);
            if (gopTrung > 0) {
              debugPrint(
                  '[SyncEngine] Đã gộp $gopTrung danh mục trùng tên do máy này tự tạo.');
            }
            debugPrint(
                '[SyncEngine] Pulled & Saved ${categories.length} categories into SQLite local.');
          }

          // 4. Budgets
          final budgets = (payloadData['budgets'] ?? payloadData['budget'])
                  as List<dynamic>? ??
              [];
          if (budgets.isNotEmpty) {
            final companions = budgets.map((b) {
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
            }).toList();
            await _db.budgetDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${budgets.length} budgets into SQLite local.');
          }

          // 5. Bills
          final bills =
              (payloadData['bills'] ?? payloadData['bill']) as List<dynamic>? ??
                  [];
          if (bills.isNotEmpty) {
            final companions = bills.map((bill) {
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
            }).toList();
            await _db.billDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${bills.length} bills into SQLite local.');
          }

          // 6. Goals
          final goals =
              (payloadData['goals'] ?? payloadData['goal']) as List<dynamic>? ??
                  [];
          if (goals.isNotEmpty) {
            final companions = goals.map((g) {
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
            }).toList();
            await _db.goalDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${goals.length} goals into SQLite local.');
          }

          // Mốc mới — **G67**. Server từ migration 20 trả `maxSince` (giờ-server
          // `Server_update_at` lớn nhất từng bảng) và lọc theo chính cột ấy, nên
          // mốc lấy từ đó (`mocTuMaxSince`: lớn nhất giữa các bảng, kẹp về
          // `pulledAt − 2 phút`). KHÔNG lấy `update_at` của từng hàng: đó là giờ ghi của
          // MÁY, và bản ghi lên server muộn hơn giờ ghi (máy offline lâu) rơi dưới
          // mốc ấy mãi mãi. Server cũ (không có khoá `maxSince`) thì rơi về
          // `update_at` lớn nhất như trước. Không nhận được bản ghi nào thì giữ
          // nguyên mốc cũ (cùng lắm là pull lại một ít, không bao giờ mất dữ liệu).
          // Kẹp về hiện tại: chỉ cần MỘT hàng mang giờ tương lai là mốc bị đẩy
          // vọt lên, và vì mốc chỉ tiến chứ không lùi nên tài khoản ấy không nhận
          // được gì nữa cho tới khi thời gian thật đuổi kịp — hỏng hoàn toàn im
          // lặng. Kẹp chứ không vứt bỏ: dữ liệu vừa nhận đã là tất cả những gì
          // server có tính tới lúc này.
          final newest = kepVeHienTai(
              topData != null && topData.containsKey('maxSince')
                  ? mocTuMaxSince(topData['maxSince'],
                      pulledAt: topData['pulledAt'])
                  : newestUpdateAt(payloadData));
          if (newest != null) {
            _lastPullTime = newest;
            await _checkpointStore?.write(accountId, newest);
          }

          // Tính lại số dư cho ví có giao dịch vừa về — **mốc đóng G37**.
          //
          // Nhánh pull chỉ ghi giao dịch vào bảng, **không đụng `balance`**
          // (trước bản này là 0 dòng), nên giao dịch của máy khác về tới nơi mà
          // số dư máy này không đổi. Số dư khi ấy chỉ đúng nhờ đồng bộ chính cột
          // `balance` theo LWW — đúng thứ nhánh ví ở trên vừa thôi đọc.
          //
          // Gồm cả ví MỚI về: neo của chúng cũng là một giao dịch, cũng vừa
          // được kéo về, nên tổng sổ ra đúng số dù cột `balance` khởi tạo bằng 0.
          // Neo đã vá ở trên, TRƯỚC khi ghi sổ — xem `viDungToi`.
          if (viDungToi.isNotEmpty) {
            await _soDuVi.tinhLaiNhieuVi(viDungToi);
          }
          // Cờ RIÊNG, không suy ra từ `_lastPullTime`: mốc đó chỉ được đặt khi
          // có dữ liệu trả về, nên một tài khoản mới toanh (chưa có gì trên
          // server) sẽ mãi mãi trông như "chưa pull lần nào".
          _hasCompletedPull = true;
          _soLanKeoVeXong++;
        }
      }
    } catch (e) {
      debugPrint('[SyncEngine] HTTP Sync Pull Error: $e');
    }
  }

  /// Id ví mặc định (chưa xoá) trong lô ví vừa kéo về, hoặc `null`. Server giữ
  /// nhiều nhất một (`uq_wallet_default_active`); lô xếp `update_at` tăng dần
  /// nên có hơn một thì hàng cuối là ý định mới nhất.
  static String? _idViMacDinhTrongLo(List<dynamic> wallets) {
    String? id;
    for (final w in wallets) {
      if (w is! Map) continue;
      if (w['delete_at'] != null) continue;
      if (!doiSangBool(w['is_default'])) continue;
      id = (w['idwallet'] ?? w['id']).toString();
    }
    return id;
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
  static DateTime? _deletedAtFrom(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString()) ?? DateTime.now();
  }
}
