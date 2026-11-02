import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_models.dart';
import '../../notification/domain/notification_rules.dart';
import '../../wallet/data/so_du_vi_service.dart';
import '../data/repositories/nha_repository.dart';
import '../domain/cau_loi_nha.dart';
import 'gop_quy_service.dart';

/// Giữ hai nửa của khoản góp / rút khớp nhau (`docs/Family/02A` mục 6). Đứng riêng khỏi `SyncEngine` như
/// `BillPaymentConflictResolver`: engine chỉ phát `SyncOpFailure.code` ra `pushResultStream`, ai muốn phản ứng thì tự nghe.
///
/// Ba lối vào, một việc chung là GỠ NỬA RIÊNG (xoá mềm + tính lại ví riêng) và báo một thông báo:
/// - [xuLy]: server từ chối nửa của nhà (nhà đóng, chỉ đọc, không còn là thành viên…) — gỡ CẢ HAI nửa.
/// - [xuLyNuaNhaBiXoa]: Chủ nhà xoá nửa của nhà, kéo về — nửa của nhà đã xoá từ server, chỉ gỡ nửa riêng.
/// - [traVeKhiBoNha]: mình rời nhà khi nửa của nhà chưa đẩy — sau đó server sẽ không nhận, gỡ như [xuLy].
///
/// ⚠️ Mã từ chối VĨNH VIỄN không làm hàng thôi `pending` (`gui_lo_dong_bo.dart` chỉ chặn theo thời gian): nửa của nhà phải tự
/// `markSynced`, nếu không nó bị đẩy lại mãi và lần nào cũng bị từ chối. Xoá mềm đặt lại `pending` nên `markSynced` đứng SAU
/// xoá mềm — khuôn của Bill resolver. Lý do thật: lệnh xoá của hàng nhà bị chính mã ấy từ chối ở bước kiểm quyền của server,
/// TRƯỚC khi tới xoá — đẩy lại là bị từ chối lại mỗi chu kỳ. (Không phải vì server "chưa có hàng": xoá hàng server không có
/// được trả `synced`, còn bản sửa bị từ chối thì server CÒN hàng — lệch hai nửa đó là G119.)
class GopQuyConflictResolver {
  GopQuyConflictResolver({
    required AppDatabase db,
    required GopQuyService gopQuy,
    required NhaRepository nha,
    required SoDuViService soDuVi,
    required int? Function() taiKhoanPhien,
    required void Function() henDongBo,
    Future<void> Function(int idaccount)? xinKeoLai,
  })  : _db = db,
        _gopQuy = gopQuy,
        _nha = nha,
        _soDuVi = soDuVi,
        _taiKhoanPhien = taiKhoanPhien,
        _henDongBo = henDongBo,
        _xinKeoLai = xinKeoLai;

  final AppDatabase _db;
  final GopQuyService _gopQuy;
  final NhaRepository _nha;
  final SoDuViService _soDuVi;

  /// Tài khoản của phiên đang mở (DI: `GoiRepository.idaccount`, cùng nguồn với `SoDuViService`). `null` = chưa có phiên
  /// (vd. lượt nền chưa đặt tài khoản) thì KHÔNG gỡ gì.
  final int? Function() _taiKhoanPhien;
  final void Function() _henDongBo;

  /// Xin một lượt kéo TOÀN BỘ cho tài khoản (DI: `SyncEngine.keoLaiToanBo`) sau khi gỡ hàng sửa / xoá hộ bị `ROLE_FORBIDDEN`.
  /// `null` = không xin (test). ⚠️ Gọi NGOÀI [_tuanTu]: lượt kéo gọi `xuLyNuaNhaBiXoa` (cũng trong [_tuanTu]) — chờ lượt kéo
  /// ngay trong hàng việc là tự khoá chết.
  final Future<void> Function(int idaccount)? _xinKeoLai;
  StreamSubscription<SyncResult>? _sub;
  Future<void> _hang = Future.value();

  /// Hai lượt phát cho cùng một thất bại, hoặc lượt đẩy và lượt kéo cùng lúc, không được chạy chồng lên nhau.
  Future<T> _tuanTu<T>(Future<T> Function() viec) {
    final f = _hang.then((_) => viec());
    _hang = f.then<void>((_) {}, onError: (Object _) {});
    return f;
  }

  /// Bắt đầu nghe kết quả đẩy. Gọi nhiều lần thì lượt sau thay lượt trước.
  void batDauNghe(Stream<SyncResult> ketQua) {
    unawaited(_sub?.cancel());
    _sub = ketQua.listen((kq) {
      unawaited(xuLy(kq).catchError((Object e) {
        debugPrint('[GopQuy] xử lý thất bại đẩy hỏng: ${e.runtimeType}');
      }));
    });
  }

  @visibleForTesting
  Future<void> xuLy(SyncResult ketQua) async {
    final canKeoLai = await _tuanTu(() async {
      var keoLai = false;
      for (final f in ketQua.failures) {
        // Hai máy Chủ cùng bật mục tiêu offline: máy đẩy sau thua chỉ mục duy nhất của `goal`. Không thuộc `kMaDayLoiNha`, vì mã
        // này cũng về từ hàng riêng; chỉ `_traBanServerMucTieu` xét `idhousehold`. Chu kỳ ấy vẫn tính là hỏng nên lượt kéo toàn
        // bộ trễ 30 s; hàng thắng đã về ở lượt kéo tăng dần cùng chu kỳ.
        final trungMucTieu = f.entity == SyncEntityType.goal && f.code == 'UNIQUE_VIOLATION';
        if (!kMaDayLoiNha.contains(f.code) && !trungMucTieu) continue;
        final phien = _taiKhoanPhien();
        if (phien == null) continue;
        final vaiKhongDu = f.code == _maVaiKhongDu;
        switch (f.entity) {
          case SyncEntityType.transaction:
            final nua = await _db.transactionDao.getById(f.localId);
            if (nua == null || nua.idhousehold == null) continue;
            if (nua.fundPairId != null && nua.idaccount == phien) {
              // Nửa do CHÍNH TÔI ghi: gỡ cả cặp.
              if (nua.deletedAt != null) {
                // Người ghi xoá cặp khi offline, lệnh xoá bị từ chối: cả hai nửa đã xoá, chỉ cho nửa nhà thoát hàng đợi.
                // Giới hạn đã biết: server còn hàng ấy (G119).
                await _db.transactionDao.markSynced(nua.id);
              } else {
                await _traVe(nua, idaccount: phien);
              }
            } else if (vaiKhongDu && await _traBanServerGiaoDich(nua)) {
              // Sửa / xoá hộ (Chủ nhà bị hạ vai khi offline), hoặc khoản thường của nhà: vai không đủ nên không tự hết.
              keoLai = true;
            }
          case SyncEntityType.wallet:
            if (vaiKhongDu && await _traBanServerVi(f.localId)) keoLai = true;
          case SyncEntityType.category:
            if (vaiKhongDu && await _traBanServerDanhMuc(f.localId)) keoLai = true;
          case SyncEntityType.goal:
            if ((vaiKhongDu || trungMucTieu) && await _traBanServerMucTieu(f.localId)) keoLai = true;
          // Ngân sách: chưa xử lý — hàng ở lại `pending` với bậc chặn riêng (G120 dòng 5).
          case SyncEntityType.budget || SyncEntityType.bill:
            break;
        }
      }
      return keoLai ? _taiKhoanPhien() : null;
    });
    if (canKeoLai == null || _xinKeoLai == null) return;
    try {
      await _xinKeoLai(canKeoLai);
    } catch (e) {
      debugPrint('[GopQuy] xin kéo toàn bộ hỏng: ${e.runtimeType}');
    }
  }

  /// `HOUSEHOLD_ROLE_FORBIDDEN`: vai của tôi không đủ cho thao tác — không tự hết như `READ_ONLY` (Chủ gia hạn là xong).
  static const _maVaiKhongDu = 'HOUSEHOLD_ROLE_FORBIDDEN';

  /// Hàng của nhà bị server từ chối vì vai: máy này giữ bản sửa / xoá mà server sẽ không bao giờ nhận, và hàng `pending` ở lại
  /// còn chặn kéo về ghi đè nó — số dư lệch mãi. Gỡ khỏi máy (xoá mềm nếu chưa xoá) + `markSynced` để thoát hàng đợi; lượt kéo
  /// TOÀN BỘ ngay sau đó trả bản server (hàng server chưa từng có thì ở lại đã xoá). Trả `true` nếu đã gỡ lần này; hàng đã
  /// gỡ + `synced` (lượt phát thứ hai cho cùng thất bại) thì không làm gì.
  Future<bool> _traBanServerGiaoDich(Transaction nua) async {
    if (nua.deletedAt != null && nua.syncStatus == 'synced') return false;
    final vi = {nua.walletId, if (nua.walletTransfer != null) nua.walletTransfer!};
    await _soDuVi.datNeoNhieuVi(vi);
    if (nua.deletedAt == null) await _db.transactionDao.softDelete(nua.id);
    // Sau xoá mềm (nó đặt lại `pending`).
    await _db.transactionDao.markSynced(nua.id);
    await _soDuVi.tinhLaiNhieuVi(vi);
    return true;
  }

  Future<bool> _traBanServerVi(String id) async {
    final vi = await _db.walletDao.getById(id);
    if (vi == null || vi.idhousehold == null) return false;
    if (vi.deletedAt != null && vi.syncStatus == 'synced') return false;
    if (vi.deletedAt == null) await _db.walletDao.softDelete(id);
    await _db.walletDao.markSynced(id);
    return true;
  }

  Future<bool> _traBanServerDanhMuc(String id) async {
    final dm = await _db.categoryDao.getById(id);
    if (dm == null || dm.idhousehold == null) return false;
    if (dm.deletedAt != null && dm.syncStatus == 'synced') return false;
    if (dm.deletedAt == null) await _db.categoryDao.softDelete(id);
    await _db.categoryDao.markSynced(id);
    return true;
  }

  Future<bool> _traBanServerMucTieu(String id) async {
    final g = await _db.goalDao.getById(id);
    if (g == null || g.idhousehold == null) return false;
    if (g.deletedAt != null && g.syncStatus == 'synced') return false;
    if (g.deletedAt == null) await _db.goalDao.softDelete(id);
    await _db.goalDao.markSynced(id);
    return true;
  }

  /// Chủ nhà xoá nửa của nhà: nửa riêng còn sống trên máy người góp bị gỡ theo. Gọi sau mỗi lượt kéo về.
  Future<void> xuLyNuaNhaBiXoa(int idaccount) => _tuanTu(() async {
        final mo = await _db.transactionDao.nuaRiengMoCoi(idaccount);
        if (mo.isEmpty) return;
        // Không đọc được `/me` (hoặc phiên đã đổi) thì hoãn: không biết nhà còn hay đã giải tán / mình đã bị mời ra.
        if (!await _nha.lamMoi() || _nha.idaccount != idaccount) return;
        final hienTai = _nha.hienTai;
        if (!hienTai.coNha) return;
        final idNha = hienTai.nha!.id;
        for (final m in mo) {
          // Nhà khác hoặc không nhà: rời nhà thì nửa riêng ở lại thành khoản riêng (`02A`), không gỡ.
          if (m.idNha != idNha) continue;
          await _goNuaRiengBiXoa(m.rieng, viNhaId: m.viNhaId, idaccount: idaccount);
        }
      });

  /// Rời nhà [idNha] khi còn nửa của nhà chưa đẩy: server sẽ không nhận, trả tiền về ví riêng TRƯỚC khi dọn hàng của nhà.
  Future<void> traVeKhiBoNha(int idNha, int idaccount) => _tuanTu(() async {
        for (final nua in await _db.transactionDao.nuaNhaChuaDay(idNha, idaccount)) {
          await _traVe(nua, idaccount: idaccount);
        }
      });

  /// Gỡ cả cặp: nửa riêng (nếu có) và nửa của nhà [nua]; tính lại hai ví; một thông báo.
  Future<void> _traVe(Transaction nua, {required int idaccount}) async {
    final maCap = nua.fundPairId!;
    final cap = await _gopQuy.docCap(maCap);
    final rieng = cap.rieng;
    final vi = {nua.walletId, if (rieng != null) rieng.walletId};
    await _soDuVi.datNeoNhieuVi(vi);
    await _db.transaction(() async {
      if (rieng != null) await _db.transactionDao.softDelete(rieng.id);
      await _db.transactionDao.softDelete(nua.id);
      // Sau xoá mềm (nó đặt lại `pending`): lệnh xoá của hàng nhà sẽ bị chính mã từ chối này chặn lại mỗi chu kỳ (kiểm quyền
      // đứng trước xoá) — thoát hàng đợi thay vì đẩy lại mãi. Server có thể còn hàng (G119).
      await _db.transactionDao.markSynced(nua.id);
    });
    await _soDuVi.tinhLaiNhieuVi(vi);
    final gop = nua.type == 'thu';
    final tenNha = (await _db.walletDao.getById(nua.walletId))?.name ?? '';
    final tenRieng = rieng == null ? null : ((await _db.walletDao.getById(rieng.walletId))?.name ?? 'ví riêng');
    final String body;
    if (gop) {
      body = tenRieng == null
          ? 'Chưa ghi được khoản góp vào quỹ $tenNha.'
          : 'Chưa góp được vào quỹ $tenNha, đã trả tiền về $tenRieng.';
    } else {
      body = tenRieng == null
          ? 'Chưa ghi được khoản rút từ quỹ $tenNha.'
          : 'Chưa rút được từ quỹ $tenNha, đã huỷ khoản nhận ở $tenRieng.';
    }
    await _baoNguoiDung(
      idaccount: idaccount,
      loai: NotificationKind.gopQuyBiTraVe,
      khoa: 'gopTraVe:$maCap',
      title: gop ? 'Chưa góp được vào quỹ' : 'Chưa rút được từ quỹ',
      body: body,
    );
    _henDongBo();
  }

  /// Chỉ gỡ nửa riêng: nửa của nhà đã bị Chủ nhà xoá từ server (không đụng, không đẩy gì).
  Future<void> _goNuaRiengBiXoa(Transaction rieng, {required String viNhaId, required int idaccount}) async {
    await _soDuVi.datNeoNhieuVi({rieng.walletId});
    await _db.transactionDao.softDelete(rieng.id);
    await _soDuVi.tinhLaiNhieuVi({rieng.walletId});
    final gop = rieng.type == 'chi';
    final tenNha = (await _db.walletDao.getById(viNhaId))?.name ?? '';
    final tenRieng = (await _db.walletDao.getById(rieng.walletId))?.name ?? 'ví riêng';
    await _baoNguoiDung(
      idaccount: idaccount,
      loai: NotificationKind.gopQuyBiXoa,
      khoa: 'gopBiXoa:${rieng.fundPairId}',
      title: gop ? 'Khoản góp đã bị xoá' : 'Khoản rút đã bị xoá',
      body: gop
          ? 'Chủ nhà đã xoá khoản góp vào quỹ $tenNha, đã trả tiền về $tenRieng.'
          : 'Chủ nhà đã xoá khoản rút từ quỹ $tenNha, đã huỷ khoản nhận ở $tenRieng.',
    );
    _henDongBo();
  }

  /// Thông báo ghi thẳng vào trung tâm (việc xảy ra lúc đồng bộ nền, toast sẽ trôi). Khoá theo mã cặp nên hai lượt phát cho
  /// cùng một thất bại chỉ báo một lần. Không nêu số tiền (nếp thông báo tối giản).
  Future<void> _baoNguoiDung({
    required int idaccount,
    required NotificationKind loai,
    required String khoa,
    required String title,
    required String body,
  }) =>
      _db.notificationDao.insertIfAbsent(AppNotificationsCompanion.insert(
        id: const Uuid().v4(),
        idaccount: idaccount,
        kind: loai.name,
        dedupeKey: khoa,
        title: title,
        body: body,
        severity: NotificationSeverity.info.name,
        subjectType: const Value('nha'),
        deeplink: const Value('/transactions'),
        createdAt: DateTime.now(),
      ));
}
