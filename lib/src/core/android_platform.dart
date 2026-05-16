import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.anonlisten.hollow/platform');

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

Future<bool> isBatteryOptimized() async {
  if (!_isAndroid) return false;
  try {
    return await _channel.invokeMethod<bool>('isBatteryOptimized') ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> requestBatteryExemption() async {
  if (!_isAndroid) return;
  try {
    await _channel.invokeMethod<void>('requestBatteryExemption');
  } catch (_) {}
}

Future<void> acquireWifiLock() async {
  if (!_isAndroid) return;
  try {
    await _channel.invokeMethod<void>('acquireWifiLock');
  } catch (_) {}
}

Future<void> releaseWifiLock() async {
  if (!_isAndroid) return;
  try {
    await _channel.invokeMethod<void>('releaseWifiLock');
  } catch (_) {}
}
