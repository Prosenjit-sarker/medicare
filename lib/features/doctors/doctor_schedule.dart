import 'package:flutter/material.dart';
import 'package:medicare_bd/core/core.dart';

String doctorWeekday(DateTime date) => const {
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
}[date.weekday]!;

Map<String, Map<String, String>> doctorWeeklySchedule(Doc doctor) {
  final stored = doctor.d['weeklySchedule'];
  if (stored is Map) {
    final schedule = <String, Map<String, String>>{};
    for (final day in kWeekdays) {
      final hours = stored[day];
      if (hours is! Map) continue;
      final start = '${hours['startTime'] ?? ''}';
      final end = '${hours['endTime'] ?? ''}';
      if (start.isNotEmpty && end.isNotEmpty) {
        schedule[day] = {'startTime': start, 'endTime': end};
      }
    }
    if (schedule.isNotEmpty) return schedule;
  }

  final configuredDays = doctor.l('days').map((day) => '$day').toSet();
  final days = configuredDays.isEmpty ? kWeekdays : kWeekdays.where(configuredDays.contains);
  final start = doctor.s('startTime').isEmpty ? '09:00' : doctor.s('startTime');
  final end = doctor.s('endTime').isEmpty ? '13:00' : doctor.s('endTime');
  return {
    for (final day in days) day: {'startTime': start, 'endTime': end},
  };
}

String formatDoctorTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
}

String doctorScheduleLabel(Doc doctor, {String? selectedDay}) {
  final schedule = doctorWeeklySchedule(doctor);
  final day = selectedDay ?? doctorWeekday(DateTime.now());
  final hours = schedule[day];
  return hours == null
      ? '$day · Not available'
      : '$day · ${formatDoctorTime(hours['startTime']!)}–${formatDoctorTime(hours['endTime']!)}';
}

class DoctorCardSubtitle extends StatelessWidget {
  const DoctorCardSubtitle({super.key, required this.doctor, this.selectedDay});

  final Doc doctor;
  final String? selectedDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${doctor.s('specialty')} · ${doctor.s('qualifications')}'),
        _DoctorInfoLine(
          icon: Icons.location_on_outlined,
          text: doctor.s('hospital').isEmpty ? 'Location not listed' : doctor.s('hospital'),
        ),
        _DoctorInfoLine(
          icon: Icons.access_time,
          text: doctorScheduleLabel(doctor, selectedDay: selectedDay),
        ),
      ],
    );
  }
}

class _DoctorInfoLine extends StatelessWidget {
  const _DoctorInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}
