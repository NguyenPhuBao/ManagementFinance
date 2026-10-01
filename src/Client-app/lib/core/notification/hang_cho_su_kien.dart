/// Tệp hàng chờ của nhật ký thông báo (B5a, spec mục 5).
///
/// Nút *Hoãn* chạy trong isolate nền của `flutter_local_notifications`: không DI,
/// không CSDL, không phiên. Nó nối một dòng JSON vào [kTepHangCho];
/// [NhapHangCho] đưa vào bảng khi app mở lại.
///
/// ⚠️ Spike Realme 2026-09-29: trên Android nút *Hoãn* vào isolate nền **kể cả
/// khi app còn sống**, nên đây là đường của MỌI hàng `hoan` trên Android — không
/// riêng lúc app đóng. Hàng vào bảng ở lần `NotificationScanner.start` kế tiếp,
/// mang mốc của chính cú bấm.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'nhat_ky_thong_bao.dart';

const String kTepHangCho = 'su_kien_thong_bao_cho.jsonl';

typedef DongCho = ({String dedupeKey, DateTime luc});

String dongHangCho({required String dedupeKey, required DateTime luc}) =>
    jsonEncode({'k': dedupeKey, 't': luc.toIso8601String()});

DongCho? docDongHangCho(String dong) {
  try {
    final m = jsonDecode(dong);
    if (m is! Map) return null;
    final k = m['k'];
    final t = m['t'];
    if (k is! String || k.isEmpty || t is! String) return null;
    final luc = DateTime.tryParse(t);
    if (luc == null) return null;
    return (dedupeKey: k, luc: luc);
  } catch (_) {
    return null;
  }
}

Future<List<DongCho>> locHangCho(
  Iterable<String> dong,
  Future<bool> Function(String dedupeKey) thuocTaiKhoan,
) async {
  final ra = <DongCho>[];
  for (final d in dong) {
    final r = docDongHangCho(d.trim());
    if (r == null) continue;
    if (await thuocTaiKhoan(r.dedupeKey)) ra.add(r);
  }
  return ra;
}

class NhapHangCho {
  NhapHangCho({
    required this.thuMuc,
    required this.nhatKy,
    required this.thuocTaiKhoan,
  });

  final Future<Directory> Function() thuMuc;
  final NhatKyThongBao nhatKy;

  /// Dòng thuộc [idaccount] khi `dedupeKey` khớp một `dat_lich` HOẶC một hàng
  /// `AppNotifications` của chính tài khoản ấy. Dòng không khớp (người khác đăng
  /// nhập giữa chừng) thì bỏ — không đoán tài khoản (quy tắc 2).
  final Future<bool> Function(int idaccount, String dedupeKey) thuocTaiKhoan;

  /// Trả số hàng đã ghi. Không bao giờ ném.
  ///
  /// Đổi tên tệp TRƯỚC khi đọc: một cú Hoãn đúng lúc này sẽ ghi vào tệp MỚI thay
  /// vì bị xoá theo tệp đang nhập.
  Future<int> nhap(int idaccount) async {
    try {
      final dir = await thuMuc();
      final goc = File('${dir.path}/$kTepHangCho');
      if (!goc.existsSync()) return 0;
      final dangNhap = await goc.rename('${goc.path}.dang_nhap');
      final dong = await dangNhap.readAsLines();
      final hop = await locHangCho(dong, (k) => thuocTaiKhoan(idaccount, k));
      for (final d in hop) {
        await nhatKy.ghi(d.dedupeKey, SuKienThongBao.hoan, idaccount: idaccount, luc: d.luc);
      }
      await dangNhap.delete();
      return hop.length;
    } catch (e) {
      debugPrint('[NhatKy] nhập hàng chờ hỏng: $e');
      return 0;
    }
  }
}
