import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = StateProvider<String>((_) => 'en');

const _m = <String, Map<String, String>>{
  'en': {
    'home': 'Home', 'visits': 'Visits', 'alerts': 'Alerts', 'profile': 'Profile', 'doctors': 'Doctors', 'hospitals': 'Hospitals',
    'pharmacy': 'Pharmacy', 'labs': 'Lab Tests', 'blood': 'Blood', 'ambulance': 'Ambulance', 'prescriptions': 'Prescriptions',
    'records': 'Records', 'reminders': 'Medicine', 'tracker': 'Tracker', 'articles': 'Health Tips', 'support': 'Support',
    'sos': 'Emergency SOS', 'orders': 'My Orders', 'labbookings': 'Test Bookings', 'welcome': 'Hello', 'signin': 'Sign in',
  },
  'bn': {
    'home': 'হোম', 'visits': 'অ্যাপয়েন্টমেন্ট', 'alerts': 'নোটিফিকেশন', 'profile': 'প্রোফাইল', 'doctors': 'ডাক্তার', 'hospitals': 'হাসপাতাল',
    'pharmacy': 'ফার্মেসি', 'labs': 'ল্যাব টেস্ট', 'blood': 'রক্তদান', 'ambulance': 'অ্যাম্বুলেন্স', 'prescriptions': 'প্রেসক্রিপশন',
    'records': 'মেডিকেল রেকর্ড', 'reminders': 'ওষুধ', 'tracker': 'হেলথ ট্র্যাকার', 'articles': 'স্বাস্থ্য তথ্য', 'support': 'সাপোর্ট',
    'sos': 'জরুরি সাহায্য', 'orders': 'আমার অর্ডার', 'labbookings': 'টেস্ট বুকিং', 'welcome': 'আসসালামু আলাইকুম', 'signin': 'সাইন ইন',
  },
};

String tr(WidgetRef ref, String key) => _m[ref.watch(localeProvider)]?[key] ?? _m['en']![key] ?? key;
