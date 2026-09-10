import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/bao_cao_xuat.dart';
import '../domain/xuat_tep.dart';
import 'luu_tep_platform.dart';
import 'xuat_tep_service.dart';

/// Lưu tệp báo cáo **vào thư mục Tải về của máy**; máy nào không làm được thì
/// lùi về sheet chia sẻ.
///
/// Đường chính là `MediaStore` (xem [LuuTepPlatform]): nó là cách duy nhất đặt
/// tệp vào bộ nhớ chung mà **không xin quyền nào** trên Android 10+. Đường lùi
/// ghi tệp vào thư mục tạm rồi mở sheet chia sẻ — ở đó người dùng tự chọn nơi
/// lưu, và nó chạy trên mọi nền tảng.
class XuatTepServiceImpl implements XuatTepService {
  final LuuTepPlatform luuTep;

  XuatTepServiceImpl({this.luuTep = const LuuTepPlatform()});

  @override
  Future<String?> xuat(
    BaoCao bc, {
    required String dinhDang,
    required String nhanVi,
    required String nhanDanhMuc,
    required DateTime lapNgay,
  }) async {
    final duoi = dinhDang.toLowerCase();
    final ten = tenTepBaoCao(bc, duoi: duoi);
    final laPdf = duoi == 'pdf';

    final Uint8List bytes = laPdf
        ? await pdfBaoCao(
            bc,
            nhanVi: nhanVi,
            nhanDanhMuc: nhanDanhMuc,
            lapNgay: lapNgay,
            fontThuong: await _font('Roboto-Regular.ttf'),
            fontDam: await _font('Roboto-Bold.ttf'),
          )
        // `utf8.encode` chứ không phải mã mặc định: chuỗi đã mang sẵn BOM ở
        // đầu, và encoder này biến nó thành đúng ba byte EF BB BF mà Excel chờ.
        : Uint8List.fromList(utf8.encode(csvBaoCao(
            bc,
            nhanVi: nhanVi,
            nhanDanhMuc: nhanDanhMuc,
            lapNgay: lapNgay,
          )));

    final noiLuu = await luuTep.luuVaoTaiVe(
      ten: ten,
      mime: laPdf ? 'application/pdf' : 'text/csv',
      bytes: bytes,
    );
    if (noiLuu != null) return noiLuu;

    // Đường lùi: thư mục tạm + sheet chia sẻ.
    final thuMuc = await getTemporaryDirectory();
    final tep = File('${thuMuc.path}/$ten');
    await tep.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(tep.path)], subject: ten),
    );
    return null;
  }

  /// Font nhúng vào PDF, nạp từ `assets/`. **Không** dùng `PdfGoogleFonts`:
  /// hàm ấy tải font qua mạng lúc chạy, mà app này offline-first.
  Future<pw.Font> _font(String ten) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$ten'));
}
