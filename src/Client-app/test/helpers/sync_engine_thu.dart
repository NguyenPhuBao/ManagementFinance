/// Dựng `SyncEngine` cho test với hai cổng ví BẮT BUỘC (G88 gạch 4, spec 2026-10-15 mục 3.1). Mặc định là BẢN THẬT dựng trên
/// `db` — `SoDuViService` + `ViBiGiuDongBo`, như DI.
///
/// ⚠️ Đừng đổi mặc định sang bản rỗng "cho test tiện": engine bỏ qua bước neo số dư / thả ví là hỏng im lặng (spec mục 9),
/// và bộ test đồng bộ (engine thật, CSDL thật trong bộ nhớ) là lưới duy nhất phủ đường ấy khi không bật backend.
/// Lớp con `extends SyncEngine` không đi qua [taoSyncEngineThu] được (`super(...)`) — chúng truyền [congSoDuViThat] /
/// [congViBiGiuThat] thẳng vào `super`.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flowmoney/core/api/dio_client.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/network/trang_thai_may_chu.dart';
import 'package:flowmoney/core/sync/cong_so_du_vi.dart';
import 'package:flowmoney/core/sync/cong_vi_bi_giu.dart';
import 'package:flowmoney/core/sync/sync_checkpoint_store.dart';
import 'package:flowmoney/core/sync/sync_engine.dart';
import 'package:flowmoney/features/wallet/data/so_du_vi_service.dart';
import 'package:flowmoney/features/wallet/data/vi_bi_giu_dong_bo.dart';

/// Bản thật của cổng số dư — như DI (`sl<SoDuViService>()`).
CongSoDuVi congSoDuViThat(AppDatabase db) => SoDuViService(db: db);

/// Bản thật của cổng ví bị giữ — như DI.
CongViBiGiu congViBiGiuThat(AppDatabase db) => ViBiGiuDongBo(db: db);

SyncEngine taoSyncEngineThu({
  required DioClient dioClient,
  required AppDatabase db,
  Connectivity? connectivity,
  SyncCheckpointStore? checkpointStore,
  DateTime Function()? now,
  CongSoDuVi? soDuVi,
  CongViBiGiu? viBiGiu,
  TrangThaiMayChu? trangThaiMayChu,
}) =>
    SyncEngine(
      dioClient: dioClient,
      db: db,
      soDuVi: soDuVi ?? congSoDuViThat(db),
      viBiGiu: viBiGiu ?? congViBiGiuThat(db),
      connectivity: connectivity,
      checkpointStore: checkpointStore,
      now: now,
      trangThaiMayChu: trangThaiMayChu,
    );
