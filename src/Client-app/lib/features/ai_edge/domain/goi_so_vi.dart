/// Gói số của trang Quản lý ví — trả lời câu người dùng hay hỏi nhất về ví:
/// *"vì sao tổng tài sản không bằng tổng các ví tôi nhìn thấy?"*
///
/// Đáp án nằm ở hai chỗ tiền **cố ý** bị loại khỏi tổng: ví tắt cờ
/// `includeInTotal`, và ví đã **lưu trữ**. Cả hai là lựa chọn của người dùng,
/// nhưng người dùng chỉ thấy hệ quả (một con số nhỏ hơn) chứ không thấy nguyên
/// nhân — khối này nói ra nguyên nhân ấy.
///
/// Luật "ví nào cộng vào tổng" có **một định nghĩa duy nhất**: `viTinhVaoTong`.
/// Lớp này gọi lại nó chứ không tự viết vế `includeInTotal && status == ...` —
/// chính hàm ấy sinh ra để dẹp bốn bản chép tay không khớp nhau.
library;

import '../../wallet/domain/vi_tinh_vao_tong.dart';
import 'goi_so.dart';
import 'nhan_xet.dart';

/// Một ví, rút gọn còn đúng sáu thứ gói số cần.
///
/// Nhận kiểu riêng thay vì hàng Drift `Wallet` hay `WalletEntity`, cùng lý do
/// với `viTinhVaoTong`: luật chạy trên **hai kiểu dữ liệu khác nhau** ở hai
/// tầng, và tầng thuần này không được kéo Drift vào.
class ViChoGoiSo {
  const ViChoGoiSo({
    required this.ten,
    required this.soDu,
    required this.includeInTotal,
    required this.status,
    required this.isDeleted,
    required this.allowNegative,
  });

  final String ten;
  final double soDu;
  final bool includeInTotal;
  final String? status;
  final bool isDeleted;

  /// Ví được phép âm (thẻ tín dụng, ví theo dõi nợ) — **không** đếm vào số ví
  /// âm, đúng luật G27.
  final bool allowNegative;
}

/// Ngưỡng coi số dư là âm, tính bằng đồng — cùng nửa đồng với
/// `dieu_chinh_so_du.dart`, vì `balance` là `double` và mọi phép cộng dồn để
/// lại đuôi lẻ. Không có ngưỡng thì một ví đúng bằng 0 có thể bị gọi là âm.
const double _nguongAm = -0.5;

class GoiSoVi extends GoiSo {
  @override
  String get man => 'vi';

  final double tongTaiSan;
  final int soViTrongTong;

  /// Tiền nằm ở ví **không** cộng vào tổng — có thể âm, và vẫn đúng.
  final double tienNgoaiTong;
  final int soViNgoaiTong;

  /// Số ví âm **ngoài ý muốn**: đã trừ ví bật cờ cho phép âm.
  final int soViAm;

  @override
  final List<SoLieu> soLieu;

  GoiSoVi._({
    required this.tongTaiSan,
    required this.soViTrongTong,
    required this.tienNgoaiTong,
    required this.soViNgoaiTong,
    required this.soViAm,
    required this.soLieu,
  });

  factory GoiSoVi.tu(List<ViChoGoiSo> vis) {
    var tong = 0.0;
    var soTrong = 0;
    var ngoai = 0.0;
    var soNgoai = 0;
    var am = 0;

    for (final v in vis) {
      // Ví đã xoá mềm không còn là ví của người dùng ở bất kỳ vế nào — kể cả
      // vế "ngoài tổng". Đây là lỗi G42 ở dạng khác: cộng ví đã xoá vào một
      // con số hiển thị.
      if (v.isDeleted) continue;

      if (viTinhVaoTong(
        includeInTotal: v.includeInTotal,
        status: v.status,
        isDeleted: v.isDeleted,
      )) {
        tong += v.soDu;
        soTrong++;
      } else {
        ngoai += v.soDu;
        soNgoai++;
      }

      if (v.soDu < _nguongAm && !v.allowNegative) am++;
    }

    final rong = soTrong == 0 && soNgoai == 0;
    return GoiSoVi._(
      tongTaiSan: tong,
      soViTrongTong: soTrong,
      tienNgoaiTong: ngoai,
      soViNgoaiTong: soNgoai,
      soViAm: am,
      soLieu: rong
          ? const []
          : [
              soTien('Tổng tài sản', tong),
              soDem('Số ví', soTrong),
              // Không có ví nào ngoài tổng thì hai thẻ này là ô trống đội lốt
              // số liệu — và câu cũng không nhắc tới chúng.
              if (soNgoai > 0) soDem('Ví ngoài tổng', soNgoai),
              if (soNgoai > 0) soTien('Không tính vào tổng', ngoai),
              if (am > 0) soDem('Ví đang âm', am),
            ],
    );
  }

  @override
  bool get thieuDuLieu => soViTrongTong == 0 && soViNgoaiTong == 0;

  @override
  NhanXet mauCau() {
    if (thieuDuLieu) {
      return const NhanXet(
        cau: 'Chưa có ví nào.',
        theSoLieu: [],
        muc: MucNhanXet.thieuDuLieu,
      );
    }
    final s = {for (final x in soLieu) x.nhan: x.chuoi};

    // Ví âm nói TRƯỚC: đó là thứ duy nhất ở đây cần người dùng làm gì đó.
    if (soViAm > 0) {
      return NhanXet(
        cau: 'Có ${s['Ví đang âm']} ví đang âm. Tổng tài sản '
            '${s['Tổng tài sản']} từ ${s['Số ví']} ví.',
        theSoLieu: soLieu,
        muc: MucNhanXet.canhBao,
      );
    }

    final veNgoai = soViNgoaiTong > 0
        ? '; ${s['Ví ngoài tổng']} ví khác giữ ${s['Không tính vào tổng']} '
            'không cộng vào tổng'
        : '';
    return NhanXet(
      cau: 'Tổng tài sản ${s['Tổng tài sản']} từ ${s['Số ví']} ví$veNgoai.',
      theSoLieu: soLieu,
      muc: MucNhanXet.binhThuong,
    );
  }
}
