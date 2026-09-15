/// Dòng tiền tự do — **định nghĩa duy nhất** (A8 #8, 2026-09-15).
///
/// Nguyên văn mục 8 của bảng A8 (`Project.md` dòng 1036): *"Xu hướng của dòng
/// tiền tự do (thu nhập sau khi trả nợ)"*.
///
/// ## Hai chữ "thu nhập" không phải `tong.thu`
///
/// [TongThuChi.thu] là **mọi** khoản `type = 'thu'`, nên nó **đã gồm cả tiền đi
/// vay và tiền thu nợ**. Cả hai đều không phải thu nhập: một là tiền mượn, một
/// là vốn cũ quay về. Lấy nguyên `tong.thu` thì tháng nào người dùng vay tiền,
/// đường này lại **vọt lên** — đúng tháng tình hình của họ xấu đi, và không có
/// exception nào báo.
///
/// Nên luật là **thu nhập = tổng thu − mọi khoản tiền VÀO thuộc nhóm Vay/nợ**:
/// `diVay`, `thuNo`, **và** `khacVao`. Ô thứ ba dễ bị bỏ sót vì nó là khoản
/// không đoán được vai — nhưng một khoản vay/nợ tiền vào chỉ có thể là *đi vay*
/// hoặc *thu nợ*, không đường nào biến nó thành thu nhập. Liệt kê hai vai rồi
/// quên ô thứ ba là chừa đúng một lối cho tiền vay lọt vào.
///
/// Chiều ngược lại thì **không** đụng tới: `choVay` và `khacRa` là tiền đi ra,
/// chúng nằm ở `tong.chi` và không liên quan gì tới vế thu.
///
/// ## Vì sao ghép hai chuỗi chứ không dựng chuỗi thứ ba
///
/// [ThongKeKy.chuoi] và [ThongKeKy.chuoiVayNo] đều đã đi qua `khoanVaoThongKe`
/// và đều lùi kỳ bằng `lui`, nên chúng cùng sáu kỳ, cùng thứ tự **cũ nhất
/// trước**. Dựng chuỗi thứ ba từ giao dịch thô là cách chắc chắn nhất để hai
/// khối trên cùng một trang nói hai con số cho cùng một tháng.
library;

import 'pham_vi_ky.dart';
import 'thong_ke_thang.dart';
import 'vai_vay_no.dart';

/// Một điểm trên biểu đồ dòng tiền tự do.
typedef DiemTuDo = ({Ky ky, double thuNhap, double traNo, double tuDo});

/// Tiêu đề khối, đổi theo đơn vị đang xem — cùng khuôn với [tieuDeXuHuong].
///
/// Đặt ở tầng domain để test được: tầng vẽ không test được (bẫy 4.9
/// `ANALYTICS_FEATURE.md`). Kỳ tuỳ chọn rơi về "tháng" vì chuỗi của nó cũng lùi
/// theo tháng.
String tieuDeDongTienTuDo(DonViKy donVi) => switch (donVi) {
      DonViKy.tuan => 'Dòng tiền tự do $kSoKyXuHuong tuần',
      DonViKy.quy => 'Dòng tiền tự do $kSoKyXuHuong quý',
      DonViKy.nam => 'Dòng tiền tự do $kSoKyXuHuong năm',
      DonViKy.thang || DonViKy.tuyChon => 'Dòng tiền tự do $kSoKyXuHuong tháng',
    };

/// Ghép [chuoi] và [chuoiVayNo] **theo chỉ số**, giữ nguyên thứ tự cũ nhất
/// trước của cả hai.
///
/// Ném [ArgumentError] khi hai chuỗi lệch độ dài hoặc lệch kỳ ở bất kỳ vị trí
/// nào: ghép theo chỉ số mà hai nguồn lệch một kỳ là gán số trả nợ của tháng
/// này cho thu nhập của tháng khác — biểu đồ vẫn vẽ ra một đường trông hợp lý,
/// và không ai biết. Thà nổ ngay ở tầng thuần, nơi có test bắt được.
List<DiemTuDo> dongTienTuDo(
  List<DiemThoiGian> chuoi,
  List<DiemVayNo> chuoiVayNo,
) {
  if (chuoi.length != chuoiVayNo.length) {
    throw ArgumentError(
      'Hai chuỗi phải cùng độ dài: chuoi=${chuoi.length}, '
      'chuoiVayNo=${chuoiVayNo.length}',
    );
  }

  return [
    for (var i = 0; i < chuoi.length; i++)
      () {
        final a = chuoi[i];
        final b = chuoiVayNo[i];
        if (a.ky != b.ky) {
          throw ArgumentError(
            'Hai chuỗi lệch kỳ ở vị trí $i: ${a.ky} vs ${b.ky}',
          );
        }
        final thuNhap = a.tong.thu - b.diVay - b.thuNo - b.khacVao;
        return (
          ky: a.ky,
          thuNhap: thuNhap,
          traNo: b.traNo,
          // Âm khi trả nợ vượt thu nhập — **không kẹp về 0**: đó đúng là kỳ
          // người dùng cần thấy nhất.
          tuDo: thuNhap - b.traNo,
        );
      }(),
  ];
}
