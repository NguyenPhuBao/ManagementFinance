/// Ví người dùng **hay dùng** cho một danh mục, học từ chính lịch sử của họ.
///
/// Trước lượt này `chonViChonSan` luôn chọn ví mặc định — giống nhau ở mọi danh
/// mục, mọi giờ. Thói quen thật thì có mẫu: ăn uống trả tiền mặt, mua sắm quẹt
/// thẻ. Luật ở đây chỉ **đếm tần suất**, không mô hình, không học máy.
///
/// ⚠️ **Im lặng khi chưa đủ căn cứ** là phần quan trọng nhất của luật, không
/// phải phần phụ. Ví nhảy lung tung theo một giao dịch lẻ còn tệ hơn hẳn ví
/// mặc định đứng yên: người dùng mất lòng tin vào ô chọn ví và phải kiểm nó mỗi
/// lần ghi. Hai chốt — đủ mẫu **và** áp đảo — đều trả `null` để trang rơi về
/// hành vi cũ.
///
/// Hàm thuần, không Flutter không Drift, nên test được mà không dựng cả trang.
library;

/// Số giao dịch tối thiểu của MỘT danh mục trước khi luật dám nói.
const int kToiThieuMauViHayDung = 5;

/// Tỉ lệ mà ví dẫn đầu phải **vượt** (không phải chạm) để coi là áp đảo.
///
/// ⚠️ Vượt chứ không chạm: 3 trên 5 đúng bằng 0,6, mà một cặp 3–2 thì gần như
/// tung đồng xu — đổi ví theo nó là đoán bừa dưới danh nghĩa "học thói quen".
const double kTiLeApDaoViHayDung = 0.6;

/// Gom lịch sử thành `danh mục → (ví → số lần)`.
///
/// ⚠️ Khoản **không có danh mục** bị bỏ, và đó không phải phép lọc tuỳ tiện:
/// khoản chuyển, khoản điều chỉnh số dư và khoản mở sổ "Số dư ban đầu" đều
/// trống danh mục. Chúng có ví, nhưng không nói gì về thói quen chọn ví *cho
/// một danh mục* — gom vào là để ví của khoản mở sổ lấn át lịch sử thật.
Map<String, Map<String, int>> demViTheoDanhMuc(
  Iterable<({String? categoryId, String? walletId})> khoan,
) {
  final dem = <String, Map<String, int>>{};
  for (final k in khoan) {
    final danhMuc = k.categoryId;
    final vi = k.walletId;
    if (danhMuc == null || vi == null) continue;
    final theoVi = dem.putIfAbsent(danhMuc, () => <String, int>{});
    theoVi[vi] = (theoVi[vi] ?? 0) + 1;
  }
  return dem;
}

/// Ví áp đảo trong [demTheoVi], hoặc `null` khi chưa đủ căn cứ.
///
/// `null` có **một** nghĩa duy nhất: *chưa biết*. Người gọi phải giữ nguyên ví
/// đang có chứ đừng đổi sang ví nào khác.
String? viHayDungCho(Map<String, int> demTheoVi) {
  if (demTheoVi.isEmpty) return null;

  var tong = 0;
  String? dan;
  var nhieuNhat = 0;
  var hoa = false;
  demTheoVi.forEach((vi, lan) {
    tong += lan;
    if (lan > nhieuNhat) {
      nhieuNhat = lan;
      dan = vi;
      hoa = false;
    } else if (lan == nhieuNhat) {
      hoa = true;
    }
  });

  if (tong < kToiThieuMauViHayDung) return null;
  // Hoà ở đỉnh thì không ai áp đảo. Phép kiểm tỉ lệ bên dưới thường đã chặn
  // (hai ví bằng nhau thì mỗi ví ≤ 50 %), nhưng chốt tường minh ở đây để luật
  // không phụ thuộc vào việc ngưỡng đang được đặt trên hay dưới 50 %.
  if (hoa) return null;
  if (nhieuNhat / tong <= kTiLeApDaoViHayDung) return null;
  return dan;
}

/// Bảng `danh mục → ví hay dùng`, **chỉ chứa** danh mục đã đủ căn cứ.
///
/// Danh mục vắng mặt nghĩa là *chưa biết* — trang tra không thấy thì giữ ví
/// mặc định, đúng hành vi trước lượt này.
Map<String, String> viHayDungTheoDanhMuc(Map<String, Map<String, int>> dem) {
  final bang = <String, String>{};
  dem.forEach((danhMuc, theoVi) {
    final vi = viHayDungCho(theoVi);
    if (vi != null) bang[danhMuc] = vi;
  });
  return bang;
}
