import 'dart:async';
import 'dart:math';
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

  double _lastMagnitude = 0;
  DateTime? _lastPickupTime;
  static const double _motionThreshold = 2.2; // user-acceleration magnitude in m/s²
  static const Duration _cooldown = Duration(seconds: 6); // min gap between pickups

  void start() {
    _sub ??= userAccelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      final delta = (magnitude - _lastMagnitude).abs();
      _lastMagnitude = magnitude;

      if (magnitude >= _motionThreshold || delta >= _motionThreshold) {
        final now = DateTime.now();
        if (_lastPickupTime == null || now.difference(_lastPickupTime!) > _cooldown) {
          _lastPickupTime = now;
          _settings.recordPickup();
        }
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
