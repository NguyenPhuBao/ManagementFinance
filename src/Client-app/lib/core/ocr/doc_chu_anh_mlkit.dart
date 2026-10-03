import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'doc_chu_anh.dart';
import 'dong_ocr.dart';

/// Bản thật của [DocChuAnh]: ML Kit Text Recognition, chạy TRÊN MÁY — ảnh không rời máy. Bộ nhận dạng chữ Latin đọc
/// được tiếng Việt có dấu (đo ở spike C4, mục 9.44 `AI_EDGE_FEATURE.md`).
class DocChuAnhMlKit implements DocChuAnh {
  const DocChuAnhMlKit();

  @override
  Future<List<DongOcr>> doc(String duongDan) async {
    final tr = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final rt = await tr.processImage(InputImage.fromFilePath(duongDan));
      return [
        for (final b in rt.blocks)
          for (final l in b.lines)
            DongOcr(l.text,
                trai: l.boundingBox.left,
                tren: l.boundingBox.top,
                phai: l.boundingBox.right,
                duoi: l.boundingBox.bottom),
      ];
    } catch (e) {
      // Chỉ kiểu lỗi — thông báo lỗi của gói có thể mang đường dẫn tệp.
      debugPrint('[BienLai] đọc chữ hỏng: ${e.runtimeType}');
      return const [];
    } finally {
      await tr.close();
    }
  }
}
