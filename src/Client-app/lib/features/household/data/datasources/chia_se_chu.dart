import 'package:share_plus/share_plus.dart';

/// Bảng chia sẻ của máy cho chữ soạn sẵn (spec 5.2). Cổng nền tảng: không chạm CSDL / API nên trang gọi thẳng được (quét 31).
abstract class ChiaSeChu {
  Future<void> chiaSe(String chu);
}

class ChiaSeChuThat implements ChiaSeChu {
  const ChiaSeChuThat();

  @override
  Future<void> chiaSe(String chu) async {
    await SharePlus.instance.share(ShareParams(text: chu));
  }
}
