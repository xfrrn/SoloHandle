String truncate(String? text, int maxLen) {
  if (text == null) return "";
  if (text.length <= maxLen) return text;
  return "${text.substring(0, maxLen)}...";
}
