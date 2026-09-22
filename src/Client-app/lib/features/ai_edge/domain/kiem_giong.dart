/// Bộ kiểm GIỌNG — lớp chắn thứ hai, đứng ngay sau `kiemSo`.
///
/// `kiemSo` chặn *số bịa*. Hàm này chặn *diễn giải sai một con số đúng*: hệ luật
/// đã kết luận mức (`MucNhanXet`), và câu mô hình sinh ra phải mang đúng giọng
/// của mức ấy. Câu "kiểm soát tốt" cho một ngân sách 90 % còn 11 ngày qua được
/// bộ kiểm số mà vẫn sai — người dùng đọc rồi yên tâm tiêu tiếp.
///
/// ⚠️ **Blocklist theo CỤM, không theo từ**, và có kiểm phủ định: "không kiểm
/// soát tốt" là cảnh báo, không phải trấn an. Cửa sổ phủ định là **ba từ**
/// trước cụm — xa hơn thì "không" ở đầu câu không còn nói về cụm ấy.
///
/// Giới hạn cố ý: đây là phép lọc từ vựng, không phải hiểu ngữ nghĩa. Nó bắt
/// được lớp lỗi phổ biến nhất (giọng ngược mức) chứ không phải mọi diễn giải
/// sai. Mọi nhánh trượt đều rơi về mẫu câu, nên sai theo chiều **an toàn**.
library;

import 'nhan_xet.dart';

/// Cụm trấn an — không được xuất hiện (chưa bị phủ định) ở mức cảnh báo.
const List<String> kCumTranAn = [
  'kiểm soát tốt',
  'đang ổn',
  'thoải mái',
  'yên tâm',
  'dư dả',
  'an toàn',
  'rất tốt',
];

/// Cụm báo động — không được xuất hiện (chưa bị phủ định) ở mức bình thường.
const List<String> kCumBaoDong = [
  'vượt hạn mức',
  'nguy hiểm',
  'báo động',
  'cạn kiệt',
  'cần cắt ngay',
];

/// Từ phủ định; đứng trong ba từ trước một cụm thì đảo nghĩa cụm ấy.
/// Không có "hết": "hết tiền" là báo động chứ không phải phủ định.
const List<String> kTuPhuDinh = ['không', 'chưa', 'chẳng'];

/// `true` khi [cau] mang đúng giọng của [muc].
bool kiemGiong(String cau, MucNhanXet muc) {
  final thap = cau.toLowerCase();
  return switch (muc) {
    MucNhanXet.canhBao => !_coCumSong(thap, kCumTranAn),
    MucNhanXet.binhThuong => !_coCumSong(thap, kCumBaoDong),
    MucNhanXet.thieuDuLieu => true,
  };
}

/// Có cụm nào trong [cums] xuất hiện mà **không** bị phủ định không.
bool _coCumSong(String cau, List<String> cums) {
  for (final c in cums) {
    var viTri = cau.indexOf(c);
    while (viTri >= 0) {
      if (!_biPhuDinh(cau, viTri)) return true;
      viTri = cau.indexOf(c, viTri + 1);
    }
  }
  return false;
}

/// Trong ba từ ngay trước [viTri] có từ phủ định không.
bool _biPhuDinh(String cau, int viTri) {
  final truoc = cau
      .substring(0, viTri)
      .split(RegExp(r'[\s,;:—-]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final tu = truoc.length > 3 ? truoc.length - 3 : 0;
  return truoc.sublist(tu).any(kTuPhuDinh.contains);
}
