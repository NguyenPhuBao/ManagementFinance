// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_feedback_dao.dart';

// ignore_for_file: type=lint
mixin _$AiFeedbackDaoMixin on DatabaseAccessor<AppDatabase> {
  $AiRebalancingFeedbacksTable get aiRebalancingFeedbacks =>
      attachedDatabase.aiRebalancingFeedbacks;
  AiFeedbackDaoManager get managers => AiFeedbackDaoManager(this);
}

class AiFeedbackDaoManager {
  final _$AiFeedbackDaoMixin _db;
  AiFeedbackDaoManager(this._db);
  $$AiRebalancingFeedbacksTableTableManager get aiRebalancingFeedbacks =>
      $$AiRebalancingFeedbacksTableTableManager(
          _db.attachedDatabase, _db.aiRebalancingFeedbacks);
}
