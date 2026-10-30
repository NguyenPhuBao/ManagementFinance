import 'dart:ui' show AppLifecycleState;

import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/sync/sync_models.dart';
import '../../domain/vai_nha.dart';
import '../models/loi_moi.dart';
import '../models/nha_cua_toi.dart';

/// Nguồn sự thật phía client về nhà của tài khoản đang đăng nhập (spec gia đình 2026-10-23 mục 5.8; `docs/Family/01` mục
/// 2.8) — khuôn `GoiRepository`:
///
/// - [lamMoi] **không bao giờ ném**: hỏng (mạng, 5xx) thì giữ trạng thái đang có. Làm mới nhà (`/me`) RỒI danh sách lời mời
///   (`/invitations`) — hai lượt mạng, mỗi lượt nuốt lỗi riêng.
/// - Kho theo tài khoản (`nha_tai_khoan_<id>`) cho trạng thái nhà; lời mời gửi tới tôi chỉ ở RAM (nguồn sự thật là server,
///   hạn 7 ngày). Hai [lamMoi] chồng nhau dùng chung một `Future`.
/// - Năm nguồn làm mới nối ở `main.dart` / DI: phiên · `resumed` giãn 5 phút · socket `household.changed` (cả hai) ·
///   socket `household.invited` (chỉ lời mời) · kết quả đẩy mang mã `kMaDayLoiNha`. Cộng: sau mỗi thao tác (thân không phải
///   trạng thái nhà → hỏi lại `/me`), và khi thao tác gặp lỗi cho thấy nhà đã đổi nơi khác.
/// - [doiNha] phát khi id nhà ĐỔI so với lần biết trước (kể cả bản trong kho) — KHÔNG phát khi nạp kho hay đăng xuất.
///
/// Thao tác ném `LoiNha` (`domain/cau_loi_nha.dart`) — trang không thấy Dio.
abstract class NhaRepository {
  NhaCuaToi get hienTai;
  Stream<NhaCuaToi> get theoDoi;
  Stream<DoiNha> get doiNha;
  int? get idaccount;

  /// Lời mời gửi tới tôi (#14) — RAM, rỗng khi chưa làm mới / đã đăng xuất.
  List<LoiMoiToiEntity> get loiMoiToi;
  Stream<List<LoiMoiToiEntity>> get theoDoiLoiMoi;

  /// Lượt nạp kho của [datTaiKhoan] gần nhất (cửa route / trang chờ trước khi đọc — khuôn G92). Không bao giờ ném.
  Future<void> choNapKho();

  /// Mở phiên: nạp kho; kho trống → chưa có nhà. Không gọi mạng.
  Future<void> datTaiKhoan(int idaccount);

  /// Đăng xuất: RAM về "chưa có nhà", kho GIỮ.
  void xoaPhien();

  /// Id nhà trong KHO của [idaccount] (bất kỳ tài khoản) — phép dọn lúc đổi tài khoản (`purgeDataForOtherAccounts`).
  Future<int?> nhaDaLuu(int idaccount);

  Future<void> lamMoi();

  /// Chỉ danh sách lời mời (#14). Không ném.
  Future<void> lamMoiLoiMoi();

  /// Làm mới nếu lượt trước đã cách quá [gian].
  Future<void> lamMoiNeuCu(Duration gian);

  Future<void> taoNha(String ten);
  Future<MaMoiEntity> taoMaMoi(VaiNha vai);

  /// Mọi mã / lời mời #4 trả, kể cả đã hết hiệu lực — nơi gọi lọc `conHieuLuc`.
  Future<List<MaMoiEntity>> dsMaMoi();
  Future<void> huyMaMoi(String ma);
  Future<XemTruocLoiMoi> xemTruoc(String ma);
  Future<void> thamGia(String ma);
  Future<void> doiVai(int idaccount, VaiNha vai);
  Future<void> chuyenChu(int idaccount);
  Future<void> moiRa(int idaccount);
  Future<void> roiNha();
  Future<void> giaiTan();

  /// #13 — email cắt trắng + chữ thường trước khi gửi (server so với `lower(account.Email)`).
  Future<KetQuaMoiEmail> moiQuaEmail(String email, VaiNha vai);

  /// #15 — như [thamGia].
  Future<void> chapNhanLoiMoi(String ma);

  /// #16 — rồi làm mới danh sách lời mời.
  Future<void> tuChoiLoiMoi(String ma);

  /// Phiên từ `AuthBloc` (`idaccountTuTrangThai`, đã lọc `laTrangThaiPhienRo`): id → [datTaiKhoan] + [lamMoi]; `null` →
  /// [xoaPhien]. Cùng id phát lại thì bỏ qua.
  void noiPhien(Stream<int?> phien);
  void noiVongDoi(Stream<AppLifecycleState> vongDoi, {Duration gian = const Duration(minutes: 5)});

  /// `household.changed` → [lamMoi]; `household.invited` → [lamMoiLoiMoi]. Cả hai là TÍN HIỆU — không đọc payload.
  void noiSuKien(Stream<RealtimeEvent> suKien);

  /// Kết quả đẩy có mã `kMaDayLoiNha` → trạng thái nhà trên máy đã cũ.
  void noiKetQuaDay(Stream<SyncResult> ketQua);

  Future<void> dispose();
}
