import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'settings_service.dart';

/// Detects phone pick-up events using the accelerometer.
/// A pick-up is defined as the device moving from a flat/resting position
/// to a significant tilt/motion, followed by stability — indicating
/// the user has lifted and oriented the phone to look at it.
class PickupDetector {
  static final PickupDetector _instance = PickupDetector._internal();
  factory PickupDetector() => _instance;
  PickupDetector._internal();

  StreamSubscription? _sub;
  final _settings = SettingsService();
  VoidCallback? _onPickup;

  double _lastMagnitude = 0;
  DateTime? _lastPickupTime;
  DateTime? _stationarySince;
  bool _armed = false;
  static const double _restThreshold = 0.65;
  static const double _motionThreshold = 1.9; // user-acceleration magnitude in m/s²
  static const Duration _stableDuration = Duration(milliseconds: 1200);
  static const Duration _cooldown = Duration(seconds: 10); // min gap between pickups

  void setOnPickupCallback(VoidCallback? callback) {
    _onPickup = callback;
  }

  void start() {
    _lastMagnitude = 0;
    _lastPickupTime = null;
    _stationarySince = null;
    _armed = false;
    _sub ??= userAccelerometerEventStream().listen((event) async {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      final delta = (magnitude - _lastMagnitude).abs();
      _lastMagnitude = magnitude;

      final now = DateTime.now();
      final isStationary = magnitude <= _restThreshold && delta <= _restThreshold;

      if (isStationary) {
        _stationarySince ??= now;
        if (!_armed && now.difference(_stationarySince!) >= _stableDuration) {
          _armed = true;
        }
        return;
      }

      _stationarySince = null;

      if (!_armed) {
        return;
      }

      if (magnitude < _motionThreshold && delta < _motionThreshold) {
        return;
      }

      if (_lastPickupTime != null && now.difference(_lastPickupTime!) <= _cooldown) {
        return;
      }

      _lastPickupTime = now;
      _armed = false;
      await _settings.recordPickup();
      _onPickup?.call();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _stationarySince = null;
    _armed = false;
  }
}
