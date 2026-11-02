import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  SharedPreferences? _prefs;
  final ValueNotifier<bool> onboardingListenable = ValueNotifier<bool>(false);

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    onboardingListenable.value = hasSeenGetStarted;
  }

  bool get hasSeenGetStarted =>
      _prefs?.getBool(AppConstants.prefHasSeenGetStarted) ?? false;

  Future<void> setHasSeenGetStarted(bool value) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefHasSeenGetStarted, value);
    if (onboardingListenable.value != value) {
      onboardingListenable.value = value;
    }
  }

  int get riwayatFilterIndex {
    final raw = _prefs?.getInt(AppConstants.prefRiwayatFilterIndex) ?? 0;
    return raw.clamp(0, 2);
  }

  Future<void> setRiwayatFilterIndex(int index) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.prefRiwayatFilterIndex, index.clamp(0, 2));
  }
}
