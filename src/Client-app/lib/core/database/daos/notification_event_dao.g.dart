// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_event_dao.dart';

// ignore_for_file: type=lint
mixin _$NotificationEventDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppNotificationEventsTable get appNotificationEvents =>
      attachedDatabase.appNotificationEvents;
  NotificationEventDaoManager get managers => NotificationEventDaoManager(this);
}

class NotificationEventDaoManager {
  final _$NotificationEventDaoMixin _db;
  NotificationEventDaoManager(this._db);
  $$AppNotificationEventsTableTableManager get appNotificationEvents =>
      $$AppNotificationEventsTableTableManager(
          _db.attachedDatabase, _db.appNotificationEvents);
}
