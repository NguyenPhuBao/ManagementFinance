import 'dart:ffi';
import 'dart:io' show Platform;

/// `CLOCK_BOOTTIME` của Linux / Android (`<linux/time.h>`).
const int _clockBoottime = 7;

typedef _ClockGettimeC = Int32 Function(Int32 clockId, Pointer<IntPtr> ts);
typedef _ClockGettimeDart = int Function(int clockId, Pointer<IntPtr> ts);
typedef _MallocC = Pointer<IntPtr> Function(IntPtr size);
typedef _MallocDart = Pointer<IntPtr> Function(int size);
typedef _FreeC = Void Function(Pointer<IntPtr> p);
typedef _FreeDart = void Function(Pointer<IntPtr> p);

_ClockGettimeDart? _clockGettime;
_MallocDart? _malloc;
_FreeDart? _free;
bool _daThu = false;

/// `clock_gettime(CLOCK_BOOTTIME)` qua `dart:ffi` (đồng bộ, không thêm gói). `struct timespec { time_t; long; }` — cả hai là
/// `long` nên đọc bằng `IntPtr` (cùng cỡ, đúng cả máy 32-bit lẫn 64-bit). Không đọc được (nền tảng khác, thiếu ký hiệu,
/// lỗi) → `null`; không bao giờ ném.
Duration? docThoiGianKhoiDong() {
  if (!Platform.isAndroid && !Platform.isLinux) return null;
  try {
    if (!_daThu) {
      _daThu = true;
      final lib = DynamicLibrary.process();
      _clockGettime = lib.lookupFunction<_ClockGettimeC, _ClockGettimeDart>('clock_gettime');
      _malloc = lib.lookupFunction<_MallocC, _MallocDart>('malloc');
      _free = lib.lookupFunction<_FreeC, _FreeDart>('free');
    }
    final gettime = _clockGettime, malloc = _malloc, free = _free;
    if (gettime == null || malloc == null || free == null) return null;
    final ts = malloc(2 * sizeOf<IntPtr>());
    if (ts == nullptr) return null;
    try {
      if (gettime(_clockBoottime, ts) != 0) return null;
      final giay = ts[0], nano = ts[1];
      if (giay < 0 || nano < 0) return null;
      return Duration(seconds: giay, microseconds: nano ~/ 1000);
    } finally {
      free(ts);
    }
  } catch (_) {
    _clockGettime = null;
    return null;
  }
}
