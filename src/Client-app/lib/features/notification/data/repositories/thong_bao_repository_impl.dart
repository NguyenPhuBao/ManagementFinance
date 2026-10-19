import '../../../../core/database/daos/notification_dao.dart';
import '../datasources/nhat_ky_thong_bao.dart';
import '../models/notification_entity.dart';
import '../models/notification_entity_companion.dart';
import 'thong_bao_repository.dart';

/// Bản thi hành duy nhất ngoài test: chuyển tiếp 1–1 sang [NotificationDao], map `fromDrift` ở biên trả về, `companionTu` ở biên ghi.
class ThongBaoRepositoryImpl implements ThongBaoRepository {
  ThongBaoRepositoryImpl(this._dao, {NhatKyThongBao? nhatKy}) : _nhatKy = nhatKy;
  final NotificationDao _dao;
  final NhatKyThongBao? _nhatKy;

  @override
  Stream<int> watchUnreadCount(int idaccount) =>
      _dao.watchUnreadCount(idaccount);
  @override
  Stream<List<NotificationEntity>> watchFeed(int idaccount,
          {int limit = 50, List<String>? kinds, bool chiChuaDoc = false}) =>
      _dao
          .watchFeed(idaccount,
              limit: limit, kinds: kinds, chiChuaDoc: chiChuaDoc)
          .map((rows) => rows.map(NotificationEntity.fromDrift).toList());
  @override
  Future<List<NotificationEntity>> getAll(int idaccount) async =>
      (await _dao.getAll(idaccount)).map(NotificationEntity.fromDrift).toList();
  @override
  Stream<int> watchDemBienDong(int idaccount) =>
      _dao.watchDemBienDong(idaccount);
  @override
  Future<void> markRead(String id) => _dao.markRead(id);
  @override
  Future<void> markAllRead(int idaccount) => _dao.markAllRead(idaccount);
  @override
  Future<void> markUnread(String id) => _dao.markUnread(id);
  @override
  Future<List<String>> khoaChuaDoc(int idaccount) =>
      _dao.khoaChuaDoc(idaccount);
  @override
  Future<void> dismiss(String id) => _dao.dismiss(id);
  @override
  Future<void> khoiPhuc(String id) => _dao.khoiPhuc(id);
  @override
  Future<bool> chenLai(NotificationEntity hang) =>
      _dao.insertIfAbsent(companionTu(hang));
  @override
  Future<int> xoaCung(int idaccount, String dedupeKey) =>
      _dao.xoaCung(idaccount, dedupeKey);
  @override
  Future<void> ghiNhatKy(String dedupeKey, String suKien, {required int idaccount}) async =>
      _nhatKy?.ghi(dedupeKey, suKien, idaccount: idaccount);
  @override
  Future<void> ghiNhatKyNhieu(List<String> dedupeKeys, String suKien, {required int idaccount}) async =>
      _nhatKy?.ghiNhieu(dedupeKeys, suKien, idaccount: idaccount);
}
