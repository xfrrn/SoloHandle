String formatIsoToLocal(String? value) {
  if (value == null || value.isEmpty) return "";
  try {
    final dt = DateTime.parse(value).toLocal();
    final y = dt.year.toString().padLeft(4, "0");
    final m = dt.month.toString().padLeft(2, "0");
    final d = dt.day.toString().padLeft(2, "0");
    final h = dt.hour.toString().padLeft(2, "0");
    final min = dt.minute.toString().padLeft(2, "0");
    return "$y-$m-$d $h:$min";
  } catch (_) {
    return value;
  }
}

String formatIsoToFriendly(String? value) {
  if (value == null || value.isEmpty) return "";
  try {
    final dt = DateTime.parse(value).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diffDays = date.difference(today).inDays;

    final h = dt.hour.toString().padLeft(2, "0");
    final min = dt.minute.toString().padLeft(2, "0");
    final time = "$h:$min";

    if (diffDays == 0) return "\u4ECA\u5929 $time";
    if (diffDays == -1) return "\u6628\u5929 $time";
    if (diffDays == 1) return "\u660E\u5929 $time";
    return "${dt.month}\u6708${dt.day}\u65E5 $time";
  } catch (_) {
    return value;
  }
}

DateTime? parseIsoToLocal(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value).toLocal();
  } catch (_) {
    return null;
  }
}

String toIsoWithOffset(DateTime value) {
  final dt = value.toLocal();
  final y = dt.year.toString().padLeft(4, "0");
  final m = dt.month.toString().padLeft(2, "0");
  final d = dt.day.toString().padLeft(2, "0");
  final h = dt.hour.toString().padLeft(2, "0");
  final min = dt.minute.toString().padLeft(2, "0");
  final s = dt.second.toString().padLeft(2, "0");
  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? "-" : "+";
  final hours = offset.inHours.abs().toString().padLeft(2, "0");
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, "0");
  return "$y-$m-${d}T$h:$min:$s$sign$hours:$minutes";
}
