import '../../../category/data/models/category_entity.dart';
import '../../../category/data/models/category_tree.dart';
import '../../../goal/data/models/goal_entity.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../domain/hang_chua_day.dart';
import '../../domain/muc_tieu_chung.dart';

/// Đọc / ghi ví chung và khoản của nhà (gia đình 1A). Mọi phép lọc theo NHÀ, không theo tài khoản: `idaccount` của hàng thuộc nhà
/// chỉ nghĩa người tạo / người ghi.
abstract class DuLieuNhaRepository {
  /// Ví chung của nhà, kể cả ví lưu trữ (để còn bỏ lưu trữ được).
  Stream<List<WalletEntity>> theoDoiViChung(int idNha);

  /// Ví chung **đang hoạt động** — bộ chọn ví của chế độ nhà. Bộ chọn ví cá nhân KHÔNG được thấy ví chung (quét 2).
  Future<List<WalletEntity>> viChungDangDung(int idNha);

  /// Mọi khoản sống của nhà, kể cả do người khác ghi. Có [walletId] thì gồm cả khoản chuyển ĐẾN ví ấy.
  Stream<List<TransactionEntity>> theoDoiKhoan(int idNha, {String? walletId});

  /// Bảng tra TÊN danh mục cho dòng khoản của nhà: danh mục của tài khoản, khuôn mặc định VÀ danh mục của nhà, kể cả hàng xoá
  /// mềm (khoản cũ vẫn trỏ vào nó). Bọc `categoryDao.watchBangTraTen` — định nghĩa duy nhất của bảng tra (quy tắc 8), không phải
  /// danh sách để CHỌN. [idaccount] từ phiên.
  Stream<List<CategoryEntity>> theoDoiBangTraDanhMuc(int idaccount);

  /// [idaccount] là người tạo — tầng trên lấy từ phiên, không có mặc định.
  Future<WalletEntity> taoViChung({
    required int idNha,
    required int idaccount,
    required String ten,
    required String loai,
    required double soDuBanDau,
    required String icon,
    required String mau,
    DatMucTieu? mucTieu,
  });

  /// Ví và mục tiêu ghi trong MỘT giao tác (`docs/Family/03` mục 6).
  Future<void> suaViChung(WalletEntity vi, {ThayDoiMucTieu mucTieu = const GiuMucTieu()});

  /// Mục tiêu sống của nhà. Hàng riêng không có ở đây.
  Stream<List<GoalEntity>> theoDoiMucTieuChung(int idNha);

  /// Cho bộ quét thông báo.
  Future<List<({GoalEntity mucTieu, WalletEntity vi})>> mucTieuKemVi(int idNha);

  /// Bộ chọn ví của form nhà: ví đang hoạt động, cộng các ví trong [giuLai] dù đã lưu trữ (đang sửa khoản trên ví ấy), ví
  /// [uuTien] đứng đầu.
  Future<List<WalletEntity>> viChungChoForm(int idNha, {Set<String> giuLai = const {}, String? uuTien});

  /// Cây danh mục của nhà theo [classify]: nhóm kèm con, và danh mục con chưa thuộc nhóm nào. Không có khuôn mặc định / ẩn.
  Future<CategoryTree> napCayDanhMuc(int idNha, String classify);

  Stream<CategoryTree> theoDoiCayDanhMuc(int idNha, String classify);

  /// Lưu trữ / bỏ lưu trữ ví chung. KHÔNG qua chốt "ví hoạt động cuối cùng" của ví riêng (nó đếm ví của tài khoản).
  Future<void> luuTruViChung({required int idNha, required String id, required bool luuTru});

  /// Ném `CacheException` khi còn số dư hoặc còn giao dịch (G45): câu chỉ lối sang lưu trữ.
  Future<void> xoaViChung({required int idNha, required String id});

  /// [idaccount] từ phiên (`null` khi không phiên: mọi hàng vào `khoan`). Chỉ nửa của [idaccount] mới vào `gop` / `rut`,
  /// vì `traVeKhiBoNha` chỉ trả tiền nửa của tôi; nửa người khác (Chủ xoá hộ offline) đếm vào `khoan`.
  Future<HangChuaDayNha> hangChuaDay(int idNha, {required int? idaccount});
}
