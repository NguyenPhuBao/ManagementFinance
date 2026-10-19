// lib/features/ai_chat/data/datasources/tro_ly_online_remote_data_source.dart
/// Nguồn **trợ lý online**: `POST /api/ai/chatbot/chat/stream` của backend (SSE) —
/// spec trợ lý online 2026-10-11 §3.2, hợp đồng §4. Bọc API, không luật nghiệp vụ:
/// luật rơi ở `domain/duong_hoi.dart`, công tắc ở `data/cong_tac_online.dart`.
///
/// `Dio` tiêm qua constructor; DI đưa `sl<DioClient>().dio` nên request đi qua
/// `AuthInterceptor` (Bearer, 401 → làm mới token rồi phát lại trọn request —
/// xảy ra trước khi có chunk nào). `receiveTimeout` riêng 45 s là khoảng lặng
/// giữa hai gói: Gemini gọi tool rồi suy luận lượt hai có thể lâu hơn 30 s mặc định.
/// Log chỉ loại sự kiện / mã HTTP — không in câu hỏi, câu trả lời.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/khung_sse.dart';
import '../../domain/su_kien_online.dart';

const Duration kChoGoiOnline = Duration(seconds: 45);
const String kDuongChatStream = '/ai/chatbot/chat/stream';

abstract class TroLyOnlineRemoteDataSource {
  /// Luồng kết thúc bằng [XongOnline] / [DuPhongOnline] / [LoiOnline] (đúng một).
  Stream<SuKienOnline> hoi({
    required String cauHoi,
    required String conversationId,
    required List<TinLichSu> history,
    required CancelToken cancel,
  });
}

class TroLyOnlineRemoteDataSourceImpl implements TroLyOnlineRemoteDataSource {
  TroLyOnlineRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Stream<SuKienOnline> hoi({
    required String cauHoi,
    required String conversationId,
    required List<TinLichSu> history,
    required CancelToken cancel,
  }) async* {
    final boTach = BoTachSse();
    final batDau = DateTime.now();
    try {
      final res = await _dio.post<ResponseBody>(
        kDuongChatStream,
        data: {
          'message': cauHoi,
          'conversationId': conversationId,
          'history': [for (final t in history) {'role': t.role, 'text': t.text}],
        },
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: kChoGoiOnline,
          headers: {'Accept': 'text/event-stream'},
        ),
        cancelToken: cancel,
      );
      final than = res.data;
      if (res.statusCode != 200 || than == null) {
        yield LoiOnline(http: res.statusCode, lyDo: 'HTTP ${res.statusCode}');
        return;
      }
      await for (final doan in than.stream.cast<List<int>>().transform(utf8.decoder)) {
        for (final sk in _dichCac(boTach.nhan(doan))) {
          yield sk;
          if (_laKet(sk, batDau)) return;
        }
      }
      for (final sk in _dichCac(boTach.dong())) {
        yield sk;
        if (_laKet(sk, batDau)) return;
      }
      yield const LoiOnline(http: 200, lyDo: 'luồng đóng không done');
    } on DioException catch (e) {
      debugPrint('[Online] lỗi ${e.type.name} http=${e.response?.statusCode} sau ${DateTime.now().difference(batDau).inMilliseconds} ms');
      yield LoiOnline(http: e.response?.statusCode, lyDo: '${e.type.name}: ${e.message ?? ''}');
    } catch (e) {
      // Mất mạng giữa luồng (HttpException), thân cụt giữa ký tự UTF-8
      // (FormatException)…: không ném ra ngoài; chỉ ghi kiểu lỗi, không nội dung.
      debugPrint('[Online] lỗi ${e.runtimeType} sau ${DateTime.now().difference(batDau).inMilliseconds} ms');
      yield LoiOnline(http: null, lyDo: '${e.runtimeType}');
    }
  }

  /// Khung → sự kiện, dừng sau sự kiện kết đầu tiên.
  Iterable<SuKienOnline> _dichCac(Iterable<KhungSse> khung) sync* {
    for (final k in khung) {
      final sk = _dich(k);
      if (sk == null) continue;
      yield sk;
      if (sk is! ChuOnline) return;
    }
  }

  /// `true` (và log) khi [sk] là sự kiện kết — ở cả hai đường `nhan` và `dong`.
  bool _laKet(SuKienOnline sk, DateTime batDau) {
    if (sk is ChuOnline) return false;
    debugPrint('[Online] kết ${sk.runtimeType} sau ${DateTime.now().difference(batDau).inMilliseconds} ms');
    return true;
  }

  /// Khung SSE → sự kiện; `meta` chỉ log; JSON hỏng → `null` (bỏ qua, luồng đi tiếp).
  SuKienOnline? _dich(KhungSse k) {
    Map<String, dynamic> json;
    try {
      final d = jsonDecode(k.data);
      if (d is! Map<String, dynamic>) return null;
      json = d;
    } catch (_) {
      return null;
    }
    switch (k.event) {
      case 'delta':
        return ChuOnline((json['text'] ?? json['content'] ?? '').toString());
      case 'done':
        if (json['fallback'] == true) return DuPhongOnline((json['reason'] ?? '').toString());
        // `done` chỉ có `error` (không `fallback`): luồng dự phòng của server tự ném, sau chunk
        // báo lỗi. Là rơi về máy (DuPhongOnline), không phải lời đáp. `done {}` trống → XongOnline
        // (cố ý không đoán thêm).
        final loi = json['error'];
        if (loi != null && loi.toString().isNotEmpty) {
          return DuPhongOnline(loi.toString());
        }
        final ms = json['responseTimeMs'];
        return XongOnline(responseTimeMs: ms is num ? ms.toInt() : null);
      case 'error':
        return LoiOnline(http: 200, lyDo: (json['message'] ?? 'error').toString());
      case 'meta':
        debugPrint('[Online] meta snapshotLoaded=${json['snapshotLoaded']} healthScore=${json['healthScore']}');
        return null;
      default:
        return null;
    }
  }
}
