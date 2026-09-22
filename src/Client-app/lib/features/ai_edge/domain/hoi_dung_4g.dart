// lib/features/ai_edge/domain/hoi_dung_4g.dart
/// Chuỗi của hộp thoại "tải bằng dữ liệu di động".
///
/// Tách khỏi màn để test khẳng định đúng câu người dùng đọc, thay vì chép lại
/// chuỗi ở hai nơi rồi để chúng trôi khỏi nhau. Người dùng chốt 2026-09-22:
/// Wi-Fi mặc định, nhưng **cho phép** 4G sau khi hỏi — tệp 2,41 GB.
library;

const String kCauHoi4G = 'Tải bằng dữ liệu di động?';

const String kCauMoTa4G =
    'Tệp nặng 2,41 GB. Tải bằng Wi-Fi thì không tốn dung lượng gói cước.';

const String kCauDongY4G = 'Tải tiếp';

const String kCauTuChoi4G = 'Để sau';
