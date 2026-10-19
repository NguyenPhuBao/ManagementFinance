/// Ba hàng chọn từ danh sách rời của trang Cài đặt thông báo (`notification_settings_page.dart`): số ngày nhắc hoá đơn,
/// ngưỡng số dư thấp, ngưỡng khoản chi lớn. Dời nguyên văn khỏi trang; ghi xuống kho qua `onGhi` do trang truyền vào.
library;

import 'package:flutter/material.dart';

import '../../../domain/notification_prefs.dart';
import '../../../../bill/domain/bill_nhac_truoc.dart';
import '../../../../../core/utils/currency_formatter.dart';
import 'khung_cai_dat.dart';

class HangSoNgay extends StatelessWidget {
  const HangSoNgay({super.key, required this.prefs, required this.onGhi});

  final NotificationPrefs prefs;
  final Future<void> Function(NotificationPrefs moi) onGhi;

  @override
  Widget build(BuildContext context) {
    // Danh sách rời chứ không phải ô nhập số: nhập tay mở đường cho những giá
    // trị vô nghĩa (âm, 400) mà `NotificationPrefs` sẽ lặng lẽ quy về mặc định
    // — người dùng gõ xong thấy số nhảy về 3 và không hiểu vì sao. Đúng các
    // chip của form Thêm hoá đơn (`kMucNhacTruoc`); giá trị cũ 0 · 2 hiện bằng
    // `hint`, form chọn sẵn chip 3 cho chúng (`mucNhacChonSan`).
    const luaChon = kMucNhacTruoc;

    return KhungCaiDat(
      icon: Icons.event_outlined,
      nhan: 'Nhắc trước',
      // Hai nghĩa, nói cả hai (người dùng chốt 2026-10-17): mặc định cho hoá đơn
      // MỚI (form Thêm chọn sẵn chip), và ngưỡng nhãn "Sắp đến hạn" của hoá đơn
      // đã tắt nhắc — những hoá đơn ấy không được nhắc (tắt là tắt thật, 2026-10-16).
      phu: 'Chọn sẵn khi tạo hoá đơn mới; cũng là ngưỡng "Sắp đến hạn" của '
          'hoá đơn đã tắt nhắc.',
      trailing: DropdownButton<int>(
        key: const ValueKey('nhac-truoc-hoa-don'),
        value: luaChon.contains(prefs.soNgayNhacHoaDon)
            ? prefs.soNgayNhacHoaDon
            : null,
        hint: Text('${prefs.soNgayNhacHoaDon} ngày'),
        underline: const SizedBox.shrink(),
        items: [
          for (final n in luaChon)
            DropdownMenuItem(value: n, child: Text('$n ngày')),
        ],
        onChanged: (v) {
          if (v == null) return;
          onGhi(prefs.copyWith(soNgayNhacHoaDon: v));
        },
      ),
    );
  }
}

/// Ngưỡng "khoản chi lớn" — bản sao có chủ ý của [HangNguongSoDu].
///
/// Danh sách rời chứ không phải ô nhập tiền, cùng lý lẽ: gõ tay mở đường cho
/// những giá trị mà `NotificationPrefs` sẽ lặng lẽ kẹp về 0 hoặc về trần, và
/// người dùng chỉ thấy con số của mình biến mất.
///
/// Các mức bắt đầu từ 500.000 chứ không từ 50.000 như ngưỡng số dư: đây là
/// ngưỡng của **một** khoản chi, và một mức quá thấp biến tính năng thành
/// một thông báo cho gần như mọi giao dịch — đúng kiểu báo động giả làm
/// người dùng tắt sạch thông báo rồi không bật lại.
class HangNguongChiLon extends StatelessWidget {
  const HangNguongChiLon({
    super.key,
    required this.prefs,
    required this.onGhi,
    required this.khoa,
  });

  final NotificationPrefs prefs;
  final Future<void> Function(NotificationPrefs moi) onGhi;
  final Key khoa;

  @override
  Widget build(BuildContext context) {
    const luaChon = [
      0,
      500000,
      1000000,
      2000000,
      5000000,
      10000000,
      20000000,
    ];

    return KhungCaiDat(
      icon: Icons.trending_up_outlined,
      nhan: 'Cảnh báo khoản chi lớn',
      phu: 'Báo khi một khoản chi đạt tới mức này.',
      trailing: DropdownButton<int>(
        key: khoa,
        // Giá trị lạ rơi về `null` kèm `hint` thay vì ném giữa `build` — cùng
        // lý do với ô ngưỡng số dư.
        value: luaChon.contains(prefs.nguongChiLon) ? prefs.nguongChiLon : null,
        hint: Text(CurrencyFormatter.format(prefs.nguongChiLon)),
        underline: const SizedBox.shrink(),
        items: [
          for (final n in luaChon)
            DropdownMenuItem(
              value: n,
              // `0` đọc thành "Tắt": một ngưỡng bằng không đọc như "báo mọi
              // khoản chi", trong khi nó tắt hẳn tính năng.
              child: Text(n == 0 ? 'Tắt' : CurrencyFormatter.format(n)),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          onGhi(prefs.copyWith(nguongChiLon: v));
        },
      ),
    );
  }
}

class HangNguongSoDu extends StatelessWidget {
  const HangNguongSoDu({
    super.key,
    required this.prefs,
    required this.onGhi,
    required this.khoa,
  });

  final NotificationPrefs prefs;
  final Future<void> Function(NotificationPrefs moi) onGhi;
  final Key khoa;

  @override
  Widget build(BuildContext context) {
    // Danh sách rời chứ không phải ô nhập tiền, cùng lý lẽ với `HangSoNgay`:
    // gõ tay mở đường cho những giá trị mà `NotificationPrefs` sẽ lặng lẽ quy
    // về 0, và người dùng chỉ thấy con số của mình biến mất.
    const luaChon = [0, 50000, 100000, 200000, 500000, 1000000, 2000000];

    return KhungCaiDat(
      icon: Icons.account_balance_wallet_outlined,
      nhan: 'Cảnh báo số dư thấp',
      phu: 'Báo khi một ví còn dưới mức này. Ví nợ không tính.',
      trailing: DropdownButton<int>(
        key: khoa,
        // Giá trị lạ — do sửa tay hoặc do một bản sau đổi danh sách — rơi về
        // `null` kèm `hint`, chứ không được ném giữa `build`.
        value: luaChon.contains(prefs.nguongSoDuThap)
            ? prefs.nguongSoDuThap
            : null,
        hint: Text(CurrencyFormatter.format(prefs.nguongSoDuThap)),
        underline: const SizedBox.shrink(),
        items: [
          for (final n in luaChon)
            DropdownMenuItem(
              value: n,
              // `0` phải đọc thành "Tắt", không phải "0 đ": một ngưỡng bằng
              // không đọc như "báo khi ví hết sạch", trong khi nó tắt hẳn
              // tính năng.
              child: Text(n == 0 ? 'Tắt' : CurrencyFormatter.format(n)),
            ),
        ],
        onChanged: (v) {
          if (v == null) return;
          onGhi(prefs.copyWith(nguongSoDuThap: v));
        },
      ),
    );
  }
}
