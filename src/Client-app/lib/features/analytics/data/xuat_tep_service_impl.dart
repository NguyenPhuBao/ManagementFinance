import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../domain/bao_cao_xuat.dart';
import '../domain/xuat_tep.dart';
import 'xuat_tep_service.dart';

/// Ghi tệp vào thư mục tạm rồi đưa cho sheet chia sẻ/lưu của hệ điều hành.
///
/// **Vì sao thư mục tạm chứ không phải "Tải về":** ghi thẳng vào bộ nhớ chung
/// cần quyền `WRITE_EXTERNAL_STORAGE` (Android ≤ 9) hoặc `MediaStore` qua kênh
/// nền tảng (Android 10+). Đưa qua sheet chia sẻ thì **người dùng tự chọn nơi
/// lưu** — kể cả "Lưu vào Tệp" — và app không xin thêm quyền nào cả.
class XuatTepServiceImpl implements XuatTepService {
  @override
  Future<void> xuat(
    BaoCao bc, {
    required String dinhDang,
    required String nhanVi,
    required String nhanDanhMuc,
    required DateTime lapNgay,
  }) async {
    final duoi = dinhDang.toLowerCase();
    final ten = tenTepBaoCao(bc, duoi: duoi);
    final thuMuc = await getTemporaryDirectory();
    final tep = File('${thuMuc.path}/$ten');

    if (duoi == 'pdf') {
      await tep.writeAsBytes(await pdfBaoCao(
        bc,
        nhanVi: nhanVi,
        nhanDanhMuc: nhanDanhMuc,
        lapNgay: lapNgay,
        fontThuong: await _font('Roboto-Regular.ttf'),
        fontDam: await _font('Roboto-Bold.ttf'),
      ));
    } else {
      // `utf8` chứ không phải mã mặc định: chuỗi đã mang sẵn BOM ở đầu, và
      // encoder này biến nó thành đúng ba byte EF BB BF mà Excel chờ.
      await tep.writeAsString(
        csvBaoCao(bc,
            nhanVi: nhanVi, nhanDanhMuc: nhanDanhMuc, lapNgay: lapNgay),
        encoding: utf8,
      );
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(tep.path)], subject: ten),
    );
  }

  /// Font nhúng vào PDF, nạp từ `assets/`. **Không** dùng `PdfGoogleFonts`:
  /// hàm ấy tải font qua mạng lúc chạy, mà app này offline-first.
  Future<pw.Font> _font(String ten) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/$ten'));
}
