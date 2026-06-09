import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Streams today's step count from the device's hardware step sensor.
///
/// The Android sensor returns the cumulative steps since the last reboot,
/// so we keep a per-day baseline in [SharedPreferences] (key
/// `steps_baseline_YYYY-MM-DD`) and subtract it to derive "today's"
/// count. The baseline is established lazily on the first reading of
/// each day. A reboot during the day is detected by the cumulative
/// counter dropping below the baseline; in that case the baseline is
/// reset to the new low value so subsequent counting stays correct.
///
/// Only Android has been wired up — iOS support is feasible (CMPedometer)
/// but is out of scope for this build. On the web/desktop the service
/// silently does nothing.
class StepsService {
  StepsService._();
  static final StepsService instance = StepsService._();

  /// Today's steps. The UI subscribes via [ValueListenableBuilder].
  final ValueNotifier<int> todaySteps = ValueNotifier<int>(0);

  /// True once a permission denial / sensor error has occurred — lets
  /// the UI show a friendly fallback instead of leaving the user
  /// staring at zero.
  final ValueNotifier<bool> unavailable = ValueNotifier<bool>(false);

  StreamSubscription<StepCount>? _sub;
  bool _started = false;

  /// Starts listening to the sensor. Safe to call multiple times.
  Future<void> start() async {
    if (_started) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      unavailable.value = true;
      return;
    }

    // ACTIVITY_RECOGNITION is required on Android 10+.
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      unavailable.value = true;
      return;
    }

    _started = true;
    _sub = Pedometer.stepCountStream.listen(
      _onEvent,
      onError: (_) => unavailable.value = true,
      cancelOnError: false,
    );
  }

  Future<void> _onEvent(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'steps_baseline_${_today()}';
    var baseline = prefs.getInt(key);

    if (baseline == null) {
      // First reading of the day → adopt the current cumulative count
      // as our baseline. Today's count starts at zero and grows from
      // every step taken after this moment.
      await prefs.setInt(key, event.steps);
      baseline = event.steps;
    } else if (event.steps < baseline) {
      // Device rebooted (cumulative counter restarted from 0).
      // Re-anchor the baseline so we keep counting from here.
      await prefs.setInt(key, event.steps);
      baseline = event.steps;
    }

    todaySteps.value = (event.steps - baseline).clamp(0, 1 << 30);
  }

  String _today() => DateTime.now().toIso8601String().split('T')[0];

  void stop() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
