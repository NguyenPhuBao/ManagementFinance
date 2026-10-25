/// `TroLyOnlineRepositoryImpl` giấu `CancelToken` của Dio sau hàm `huy` thuần — trang Trợ lý AI không cầm kiểu Dio (quét 31).
/// Hai thứ phải giữ: luồng là ĐÚNG luồng của datasource, và `huy` cắt ĐÚNG token đã đưa xuống (nút Dừng cắt luồng thật).
library;

import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flowmoney/features/ai_chat/data/datasources/tro_ly_online_remote_data_source.dart';
import 'package:flowmoney/features/ai_chat/data/repositories/tro_ly_online_repository_impl.dart';
import 'package:flowmoney/features/ai_chat/domain/su_kien_online.dart';
import 'package:flutter_test/flutter_test.dart';

class _NguonGia implements TroLyOnlineRemoteDataSource {
  CancelToken? token;
  String? cauHoi;
  @override
  Stream<SuKienOnline> hoi({
    required String cauHoi,
    required String conversationId,
    required List<TinLichSu> history,
    required CancelToken cancel,
  }) {
    token = cancel;
    this.cauHoi = cauHoi;
    return Stream.fromIterable(const [ChuOnline('chào')]);
  }
}

void main() {
  test('hoi chuyển tham số xuống datasource; huy cắt đúng token ấy', () async {
    final nguon = _NguonGia();
    final luot = TroLyOnlineRepositoryImpl(nguon).hoi(cauHoi: 'Quỹ khẩn cấp?', conversationId: 'c1', history: const []);
    expect(nguon.cauHoi, 'Quỹ khẩn cấp?');
    expect((await luot.suKien.toList()).single, isA<ChuOnline>().having((c) => c.text, 'text', 'chào'));
    expect(nguon.token!.isCancelled, isFalse);
    luot.huy('người dùng dừng');
    expect(nguon.token!.isCancelled, isTrue);
  });
}
