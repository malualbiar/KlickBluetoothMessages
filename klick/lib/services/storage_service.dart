import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bluetooth_device.dart';

class StorageService {
  static const String _keyOnboarding = 'klick_onboarding_completed';
  static const String _keyUserName = 'klick_user_name';
  static const String _keyContacts = 'klick_saved_contacts';
  static const String _keyMessages = 'klick_saved_messages';
  static const String _keyPendingQueue = 'klick_pending_queue';
  static const String _keyShowHardwareButtons = 'klick_show_hardware_buttons';

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('StorageService init error: $e');
    }
  }

  // Onboarding Status
  Future<bool> isOnboardingComplete() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs?.getBool(_keyOnboarding) ?? false;
  }

  Future<void> setOnboardingComplete(bool completed) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_keyOnboarding, completed);
  }

  // Hardware Buttons Toggle Setting
  Future<bool> getShowHardwareButtons() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs?.getBool(_keyShowHardwareButtons) ?? false;
  }

  Future<void> setShowHardwareButtons(bool show) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool(_keyShowHardwareButtons, show);
  }

  // User Name / Callsign
  Future<String?> getUserName() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs?.getString(_keyUserName);
  }

  Future<void> setUserName(String name) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyUserName, name);
  }

  // Contacts
  Future<List<KlickDevice>> loadContacts() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_keyContacts);
      if (raw == null || raw.isEmpty) return [];

      final decoded = json.decode(raw) as List<dynamic>;
      return decoded
          .map((item) => KlickDevice.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('StorageService loadContacts error: $e');
      return [];
    }
  }

  Future<void> saveContacts(List<KlickDevice> devices) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final list = devices.map((d) => d.toJson()).toList();
      await _prefs?.setString(_keyContacts, json.encode(list));
    } catch (e) {
      debugPrint('StorageService saveContacts error: $e');
    }
  }

  // Messages by device endpoint id
  Future<Map<String, List<KlickMessage>>> loadMessages() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_keyMessages);
      if (raw == null || raw.isEmpty) return {};

      final decoded = json.decode(raw) as Map<String, dynamic>;
      final Map<String, List<KlickMessage>> map = {};
      decoded.forEach((key, val) {
        if (val is List) {
          map[key] = val
              .map((item) => KlickMessage.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      });
      return map;
    } catch (e) {
      debugPrint('StorageService loadMessages error: $e');
      return {};
    }
  }

  Future<void> saveMessages(Map<String, List<KlickMessage>> messages) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final Map<String, dynamic> map = {};
      messages.forEach((key, list) {
        map[key] = list.map((m) => m.toJson()).toList();
      });
      await _prefs?.setString(_keyMessages, json.encode(map));
    } catch (e) {
      debugPrint('StorageService saveMessages error: $e');
    }
  }

  // Outgoing Pending Message Queue (for offline auto-resend)
  Future<Map<String, List<KlickMessage>>> loadPendingQueue() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_keyPendingQueue);
      if (raw == null || raw.isEmpty) return {};

      final decoded = json.decode(raw) as Map<String, dynamic>;
      final Map<String, List<KlickMessage>> map = {};
      decoded.forEach((key, val) {
        if (val is List) {
          map[key] = val
              .map((item) => KlickMessage.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      });
      return map;
    } catch (e) {
      debugPrint('StorageService loadPendingQueue error: $e');
      return {};
    }
  }

  Future<void> savePendingQueue(Map<String, List<KlickMessage>> pending) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final Map<String, dynamic> map = {};
      pending.forEach((key, list) {
        map[key] = list.map((m) => m.toJson()).toList();
      });
      await _prefs?.setString(_keyPendingQueue, json.encode(map));
    } catch (e) {
      debugPrint('StorageService savePendingQueue error: $e');
    }
  }
}
