import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/calculations.dart';
import '../core/theme.dart';

/// AI rep counter — uses the device camera + Google ML Kit Pose to count
/// push-ups in real time. Android-only (ML Kit Pose has no web support).
class PoseCounterScreen extends StatefulWidget {
  const PoseCounterScreen({super.key});

  @override
  State<PoseCounterScreen> createState() => _PoseCounterScreenState();
}

class _PoseCounterScreenState extends State<PoseCounterScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  CameraDescription? _selected;
  PoseDetector? _detector;

  bool _initializing = true;
  String? _initError;
  bool _busy = false;

  int _reps = 0;
  String _phase = 'up'; // 'up' | 'down'
  double? _lastAngle;
  bool _personVisible = false;
  DateTime? _startedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  Future<void> _setup() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      setState(() {
        _initError =
            'Rep Counter works on Android only (uses on-device ML Kit Pose).';
        _initializing = false;
      });
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _initError = 'No camera found on this device.';
          _initializing = false;
        });
        return;
      }
      _selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _camera = CameraController(
        _selected!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );
      await _camera!.initialize();

      _detector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );

      await _camera!.startImageStream(_onFrame);
      _startedAt = DateTime.now();

      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Camera init failed: $e';
          _initializing = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _camera;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      c.stopImageStream().catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      if (!c.value.isStreamingImages) {
        c.startImageStream(_onFrame).catchError((_) {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _camera;
    if (c != null && c.value.isStreamingImages) {
      c.stopImageStream().catchError((_) {});
    }
    c?.dispose();
    _detector?.close();
    super.dispose();
  }

  // ── Frame → InputImage → Pose ──────────────────────────────
  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _detector == null || _selected == null) return;
    _busy = true;
    try {
      final input = _toInputImage(image, _selected!);
      if (input == null) return;
      final poses = await _detector!.processImage(input);
      if (poses.isEmpty) {
        if (_personVisible && mounted) {
          setState(() => _personVisible = false);
        }
        return;
      }
      _processPose(poses.first);
    } catch (_) {
      // ignore frame errors
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription cam) {
    final rotation =
        InputImageRotationValue.fromRawValue(cam.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) return null;
    // NV21 on Android is delivered as a single plane.
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ── Push-up rep counter ────────────────────────────────────
  void _processPose(Pose pose) {
    double? leftAngle, rightAngle;
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final le = pose.landmarks[PoseLandmarkType.leftElbow];
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final re = pose.landmarks[PoseLandmarkType.rightElbow];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];

    if (_isConfident(ls) && _isConfident(le) && _isConfident(lw)) {
      leftAngle = _angle(ls!, le!, lw!);
    }
    if (_isConfident(rs) && _isConfident(re) && _isConfident(rw)) {
      rightAngle = _angle(rs!, re!, rw!);
    }

    final visible = leftAngle != null || rightAngle != null;
    if (!visible) {
      if (_personVisible && mounted) {
        setState(() => _personVisible = false);
      }
      return;
    }

    // Use the more bent arm (smaller angle); requires both arms to bend
    // together if both are detected — guards against half-rep cheats.
    final angle = (leftAngle != null && rightAngle != null)
        ? math.max(leftAngle, rightAngle)
        : (leftAngle ?? rightAngle!);

    String newPhase = _phase;
    if (angle < 95) {
      newPhase = 'down';
    } else if (angle > 155) {
      newPhase = 'up';
    }

    final repFired = _phase == 'down' && newPhase == 'up';
    if (mounted) {
      setState(() {
        _personVisible = true;
        _lastAngle = angle;
        _phase = newPhase;
        if (repFired) _reps++;
      });
    }
  }

  bool _isConfident(PoseLandmark? l) =>
      l != null && (l.likelihood >= 0.5);

  double _angle(PoseLandmark a, PoseLandmark b, PoseLandmark c) =>
      angleBetween(a.x, a.y, b.x, b.y, c.x, c.y);

  // ── Actions ────────────────────────────────────────────────
  void _reset() {
    setState(() {
      _reps = 0;
      _phase = 'up';
      _startedAt = DateTime.now();
    });
  }

  Future<void> _save() async {
    if (_saving || _reps == 0) return;
    setState(() => _saving = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _saving = false);
      return;
    }
    final started = _startedAt ?? DateTime.now();
    final mins =
        math.max(1, DateTime.now().difference(started).inMinutes);
    // Rough push-up calorie estimate: ~0.32 kcal per rep for an average adult.
    final cals = (_reps * 0.32).round();
    final today = DateTime.now().toIso8601String().split('T')[0];
    try {
      await supabase.from('workout_logs').insert({
        'user_id': user.id,
        'name': 'Push-ups ($_reps reps)',
        'duration_minutes': mins,
        'calories_burned': cals,
        'workout_date': today,
      });
      // Surface in the friends feed.
      try {
        await supabase.from('activities').insert({
          'user_id': user.id,
          'type': 'workout',
          'title': 'Push-ups',
          'detail': '$_reps reps · counted by AI',
        });
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved $_reps push-ups',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ));
        context.go('/stats');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _initializing
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _initError != null
              ? _buildErrorScreen()
              : _buildCameraScreen(),
    );
  }

  Widget _buildErrorScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            _backButton(),
            const Spacer(),
            const Icon(Icons.videocam_off_rounded,
                color: Colors.white24, size: 56),
            const SizedBox(height: 16),
            Text(_initError ?? 'Camera error',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.inter(color: Colors.white60, fontSize: 14)),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraScreen() {
    final camera = _camera!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview (fills the screen, cover crop).
        Center(
          child: AspectRatio(
            aspectRatio: camera.value.aspectRatio,
            child: CameraPreview(camera),
          ),
        ),

        // Top overlay: back + tip
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _backButton(),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _personVisible
                          ? 'Person detected — go!'
                          : 'Frame your full body in the camera',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom overlay: counter + controls
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Text('$_reps',
                            style: GoogleFonts.bebasNeue(
                                color: AppTheme.primary,
                                fontSize: 72,
                                height: 1,
                                letterSpacing: 2)),
                        Text('PUSH-UPS',
                            style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4)),
                        const SizedBox(height: 10),
                        _phaseChip(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _pillButton(
                        label: 'Reset',
                        icon: Icons.restart_alt_rounded,
                        color: Colors.white24,
                        onTap: _reset,
                      ),
                      const SizedBox(width: 14),
                      _pillButton(
                        label: _saving ? 'Saving…' : 'Save',
                        icon: Icons.check_rounded,
                        color: _reps > 0 && !_saving
                            ? AppTheme.primary
                            : Colors.white12,
                        filled: true,
                        onTap: _reps > 0 && !_saving ? _save : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return GestureDetector(
      onTap: () => context.go('/home'),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }

  Widget _phaseChip() {
    final isDown = _phase == 'down';
    final label = !_personVisible
        ? 'NO POSE'
        : isDown
            ? 'DOWN'
            : 'UP';
    final color = !_personVisible
        ? Colors.white38
        : isDown
            ? const Color(0xFFFF2D55)
            : const Color(0xFFA3F900);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          if (_lastAngle != null) ...[
            const SizedBox(width: 8),
            Text('${_lastAngle!.toStringAsFixed(0)}°',
                style: GoogleFonts.inter(
                    color: Colors.white54, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: filled ? color : Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(filled ? 1 : 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: filled ? Colors.white : color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.inter(
                    color: filled ? Colors.white : color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
