/// Kéo dữ liệu của tài khoản từ `/sync/pull` về SQLite và giữ mốc kéo — tách khỏi `SyncEngine` 2026-10-19 (spec
/// `docs/superpowers/specs/2026-10-19-tach-sync-engine-design.md`). Thân dời nguyên văn. Từ 2026-10-20 sáu khối dựng companion
/// từ hàng JSON nằm ở `anh_xa_keo_ve.dart` (dời nguyên văn); ở đây còn điều phối và mọi bước có tác dụng phụ.
library;

import 'package:flutter/foundation.dart' hide Category;

import '../api/dio_client.dart';
import '../database/app_database.dart';
import 'anh_xa_keo_ve.dart';
import 'backend_bool.dart';
import 'cong_so_du_vi.dart';
import 'gieo_tu_khoa.dart';
import 'moc_keo_ve.dart';
import 'sync_checkpoint_store.dart';
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
            final companions = wallets.map((w) => companionViKeoVe(w, accountId)).toList();
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
          // INSERT mang `balance = 0` (nhánh trên — `companionViKeoVe` — thôi đọc cột ấy) trong khi sổ
          // của nó đầy đủ; vá nó là sinh một khoản chi bằng cả tổng sổ (đo thật
          // 2026-09-13: ví 2.000.000 hiện thành `Total balance: 0đ`). Neo của ví
          // vừa về — nếu có — là một giao dịch, về cùng lượt.
          await _soDuVi.datNeoNhieuVi(viDungToi.intersection(viDaCoTruocPull));
          if (transactions.isNotEmpty) {
            final companions = transactions.map((t) => companionGiaoDichKeoVe(t, accountId)).toList();
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
              final existingLocal = await _db.categoryDao.getById(catUuid);
              if (existingLocal?.isLocalOnly == true) {
                continue;
              }
              companions.add(companionDanhMucKeoVe(
                c,
                catUuid: catUuid,
                catName: catName,
                existingLocal: existingLocal,
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
            final companions = budgets.map((b) => companionNganSachKeoVe(b, accountId)).toList();
            await _db.budgetDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${budgets.length} budgets into SQLite local.');
          }

          // 5. Bills
          final bills =
              (payloadData['bills'] ?? payloadData['bill']) as List<dynamic>? ??
                  [];
          if (bills.isNotEmpty) {
            final companions = bills.map((bill) => companionHoaDonKeoVe(bill, accountId)).toList();
            await _db.billDao.upsertAll(companions);
            debugPrint(
                '[SyncEngine] Pulled & Saved ${bills.length} bills into SQLite local.');
          }

          // 6. Goals
          final goals =
              (payloadData['goals'] ?? payloadData['goal']) as List<dynamic>? ??
                  [];
          if (goals.isNotEmpty) {
            final companions = goals.map((g) => companionMucTieuKeoVe(g, accountId)).toList();
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
          // `balance` theo LWW — đúng thứ nhánh ví ở trên (`companionViKeoVe`) vừa thôi đọc.
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
}
