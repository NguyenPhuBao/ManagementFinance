/// Lượt nền THẬT — chạy trong engine headless do `TuChuyenTienWorker.kt` dựng (spec
/// `2026-10-10-tu-chuyen-tien-chay-nen-design.md` mục 3.3). Không bao giờ chạy trong engine của app.
///
/// Phần điều phối thuần (thứ tự bước, nuốt lỗi) nằm ở `luot_nen.dart` và có test; tệp này chỉ dựng phụ thuộc thật
/// và báo `nenXong` cho Kotlin.
library;

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/premium/data/goi_repository.dart';
import '../constants/app_constants.dart';
import '../di/injection_container.dart';
import '../notification/nhat_ky_thong_bao.dart';
import '../notification/notification_scanner.dart';
import '../sync/noi_bo_nghe_ket_qua_day.dart';
import '../sync/sync_engine.dart';
import 'kenh_tu_chuyen_tien.dart';
import 'lich_nen.dart';
import 'luot_nen.dart';
import 'mui_gio.dart';

Future<void> chayNen() async {
  // Hỏng trước cả khi đọc được gì → giữ lượt định kỳ (không biết thì đừng huỷ).
  LichNenKeTiep lich = (moc: null, coTuDong: true);
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await initializeDateFormatting('vi_VN', null);
    await khoiTaoMuiGio();
    await setupDependencies(cheDoNen: true);
    noiBoNgheKetQuaDay();
    lich = await LuotNen(
      coToken: () async {
        final t = await sl<FlutterSecureStorage>().read(key: AppConstants.accessTokenKey);
        return t != null && t.isNotEmpty;
      },
      docPhien: () async {
        final u = await sl<AuthRepository>().getCurrentUser();
        final id = int.tryParse(u?.id ?? '');
        if (u == null || id == null) return null;
        return (idaccount: id, loaiPhien: u.loaiTaiKhoan);
      },
      datGoi: (id, loai) => sl<GoiRepository>().datTaiKhoan(id, loaiPhien: loai),
      datNhatKy: (id) => sl<NhatKyThongBao>().datNguonPhien(() => id),
      dongBo: (id) => sl<SyncEngine>().syncMotLuot(id),
      quet: (id) => sl<NotificationScanner>().scan(id),
      tinhLich: (id) => sl<LichNen>().tinhCho(id),
    ).chay();
  } catch (e) {
    debugPrint('[Nen] Lượt nền hỏng: $e');
  } finally {
    debugPrint('[Nen] Xong — mốc kế ${lich.moc}, còn tự động: ${lich.coTuDong}');
    try {
      await const MethodChannel(kKenhNen).invokeMethod<void>('nenXong', lichSangKenh(lich));
    } catch (_) {
      // Bỏ qua có chủ ý — Kotlin hết trần 3 phút thì tự kết thúc.
    }
  }
}
