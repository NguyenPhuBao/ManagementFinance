/// Mã danh mục ẢO cho nửa riêng của khoản góp, rút (`02A` mục 7.2). Chỉ sống trong phép gom thống kê: không đồng bộ, không ghi
/// CSDL, không chọn được ở bảng chọn. Nhận dạng theo `fundPairId`, không theo ghi chú.
const kDanhMucAoGopQuy = '__gop_quy__';
const kDanhMucAoRutQuy = '__rut_quy__';
const kTenGopQuyGiaDinh = 'Góp quỹ gia đình';
const kTenRutQuyGiaDinh = 'Rút quỹ gia đình';

/// Mã dùng để gom: nửa riêng (`fundPairId` có, `idhousehold` null) chưa có danh mục thật thì mã ảo theo chiều; còn lại giữ
/// nguyên. Danh mục thật của nửa riêng luôn thắng.
String? categoryIdThongKe({
  required String? categoryId,
  required String? fundPairId,
  required int? idhousehold,
  required String loai,
}) {
  if (fundPairId == null || idhousehold != null || categoryId != null) return categoryId;
  return loai == 'thu' ? kDanhMucAoRutQuy : kDanhMucAoGopQuy;
}

/// Nhãn của mã ảo; mã khác trả `null`. Định nghĩa DUY NHẤT: mọi chỗ tra tên / màu / icon rơi về đây trước khi nói
/// "Danh mục đã xoá". `classify`: góp là `chi`, rút là `thu` để `phanLoaiCua` xếp đúng lát.
({String ten, String classify, String mauHex, String icon})? nhanAoQuy(String? id) => switch (id) {
      kDanhMucAoGopQuy => (
          ten: kTenGopQuyGiaDinh,
          classify: 'chi',
          mauHex: '#4F6F52',
          icon: 'account_balance',
        ),
      kDanhMucAoRutQuy => (
          ten: kTenRutQuyGiaDinh,
          classify: 'thu',
          mauHex: '#2E7D6B',
          icon: 'account_balance',
        ),
      _ => null,
    };

/// `true` khi là nửa riêng của khoản rút: nhận theo mã cặp, không theo danh mục (có danh mục thật vẫn là tiền quay về).
bool laNuaRutQuy({
  required String? fundPairId,
  required int? idhousehold,
  required String loai,
}) =>
    fundPairId != null && idhousehold == null && loai == 'thu';
