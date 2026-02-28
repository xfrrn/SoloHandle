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
