import 'package:intl/intl.dart';

double? bmi(num? kg, num? cm) {
  if (kg == null || cm == null || cm <= 0) return null;
  final m = cm / 100;
  return kg / (m * m);
}

List<String> genSlots(String start, String end, int minutes) {
  if (minutes <= 0) return [];
  int p(String s) {
    final a = s.split(':');
    return int.parse(a[0]) * 60 + int.parse(a[1]);
  }

  final out = <String>[];
  for (var t = p(start); t + minutes <= p(end); t += minutes) {
    out.add('${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}');
  }
  return out;
}

String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String todayKey() => dateKey(DateTime.now());
