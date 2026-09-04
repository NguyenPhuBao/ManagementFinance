// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_dao.dart';

// ignore_for_file: type=lint
mixin _$NotificationDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppNotificationsTable get appNotifications =>
      attachedDatabase.appNotifications;
  NotificationDaoManager get managers => NotificationDaoManager(this);
}

class NotificationDaoManager {
  final _$NotificationDaoMixin _db;
  NotificationDaoManager(this._db);
  $$AppNotificationsTableTableManager get appNotifications =>
      $$AppNotificationsTableTableManager(
          _db.attachedDatabase, _db.appNotifications);
}
