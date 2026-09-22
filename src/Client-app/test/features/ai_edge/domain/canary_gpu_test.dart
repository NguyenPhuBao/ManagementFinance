/// Canary GPU — vì sao có: đo trên Realme RMX2205 (Dimensity 1100, Mali-G77)
/// 2026-09-22, nạp mô hình với `preferredBackend: gpu` làm app **sập native**
/// (SIGSEGV null-pointer trong `libLiteRtOpenClAccelerator.so` lúc gắn delegate).
/// Bậc thang "GPU hỏng → CPU" của P1 chỉ bắt được **exception**; crash native
/// giết tiến trình trước khi Dart kịp `catch`, nên máy này không bao giờ tới
/// nhánh CPU — mỗi lần hỏi là một lần văng về màn chính.
///
/// Cách chữa: ghi một dấu **trước** khi thử GPU, xoá khi nạp xong. App mở lại
/// mà dấu còn đó nghĩa là lần trước sập giữa chừng → ghi nhớ "GPU hỏng" và
/// dùng CPU từ đó. Hai tệp, không schema, không đồng bộ.
library;

import 'dart:io';

import 'package:flowmoney/features/ai_edge/domain/canary_gpu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tam;
  setUp(() => tam = Directory.systemTemp.createTempSync('canary'));
  tearDown(() => tam.deleteSync(recursive: true));

  CanaryGpu dung() => CanaryGpu(thuMuc: () async => tam);

  test('máy sạch → thử GPU, và dấu canary được ghi trước khi thử', () async {
    final c = dung();
    expect(await c.nenDungCpu(), isFalse);
    await c.batDauThu();
    expect(File('${tam.path}/$kTepCanaryGpu').existsSync(), isTrue,
        reason: 'dấu phải nằm trên đĩa TRƯỚC khi gọi engine — sập là mất '
            'cơ hội ghi');
  });

  test('nạp xong thì dấu được xoá → lần sau vẫn thử GPU', () async {
    final c = dung();
    await c.batDauThu();
    await c.thuXong();
    expect(File('${tam.path}/$kTepCanaryGpu').existsSync(), isFalse);
    expect(await c.nenDungCpu(), isFalse);
  });

  test('⭐ dấu còn sót (lần trước sập) → CPU, và ghi nhớ GPU hỏng', () async {
    // Đúng cảnh Realme: app sập trong `getActiveModel`, mở lại.
    await dung().batDauThu();
    final c = dung(); // tiến trình mới
    expect(await c.nenDungCpu(), isTrue);
    expect(File('${tam.path}/$kTepGpuHong').existsSync(), isTrue,
        reason: 'không ghi nhớ thì lần nạp sau lại thử GPU và lại sập');
  });

  test('đã ghi nhớ GPU hỏng → CPU mãi, kể cả khi canary đã dọn', () async {
    File('${tam.path}/$kTepGpuHong').createSync();
    final c = dung();
    expect(await c.nenDungCpu(), isTrue);
    await c.batDauThu();
    await c.thuXong();
    expect(await c.nenDungCpu(), isTrue);
  });

  test('nenDungCpu khi đã hỏng thì KHÔNG ghi thêm canary — CPU không cần dấu',
      () async {
    File('${tam.path}/$kTepGpuHong').createSync();
    final c = dung();
    await c.nenDungCpu();
    await c.batDauThu();
    expect(File('${tam.path}/$kTepCanaryGpu').existsSync(), isFalse,
        reason: 'để dấu lại khi chạy CPU là lần sau đọc nhầm CPU cũng sập');
  });
}
