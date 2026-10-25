import 'package:dio/dio.dart' show CancelToken;

import '../../domain/su_kien_online.dart';
import '../datasources/tro_ly_online_remote_data_source.dart';
import '../models/luot_hoi_online.dart';
import 'tro_ly_online_repository.dart';

class TroLyOnlineRepositoryImpl implements TroLyOnlineRepository {
  TroLyOnlineRepositoryImpl(this._nguon);
  final TroLyOnlineRemoteDataSource _nguon;

  @override
  LuotHoiOnline hoi({required String cauHoi, required String conversationId, required List<TinLichSu> history}) {
    final cancel = CancelToken();
    return LuotHoiOnline(
      suKien: _nguon.hoi(cauHoi: cauHoi, conversationId: conversationId, history: history, cancel: cancel),
      huy: cancel.cancel,
    );
  }
}
