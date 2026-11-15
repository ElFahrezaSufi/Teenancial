import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/feen_catalog.dart';
import '../../providers/belajar_provider.dart';
import '../../providers/target_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_colors.dart';
import 'feen_avatar.dart';

class FeenFab extends StatefulWidget {
  const FeenFab({super.key});

  @override
  State<FeenFab> createState() => _FeenFabState();
}

class _FeenFabState extends State<FeenFab> with SingleTickerProviderStateMixin {
  static bool _initialHintShown = false;

  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  Timer? _showTimer;
  Timer? _hideTimer;
  Timer? _levelUpTimer;
  Timer? _moodRefreshTimer;

  bool _showHint = false;
  int? _lastKnownLevel;
  bool _isCelebratingLevelUp = false;
  String? _lastBubbleText;

  @override
  void initState() {
    super.initState();
    if (!_initialHintShown) {
      _initialHintShown = true;
      _triggerBubble(delay: const Duration(milliseconds: 900));
    }
    _moodRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  void _triggerBubble({Duration delay = Duration.zero}) {
    _showTimer?.cancel();
    _hideTimer?.cancel();

    void showAndScheduleHide() {
      if (!mounted) return;
      setState(() => _showHint = true);
      _hideTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showHint = false);
      });
    }

    if (delay == Duration.zero) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => showAndScheduleHide());
    } else {
      _showTimer = Timer(delay, showAndScheduleHide);
    }
  }

  void _checkLevelUp(int currentLevel) {
    if (_lastKnownLevel != null && currentLevel > _lastKnownLevel!) {
      _isCelebratingLevelUp = true;
      _levelUpTimer?.cancel();
      _levelUpTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() => _isCelebratingLevelUp = false);
        }
      });
    }
    _lastKnownLevel = currentLevel;
  }

  ({FeenPose pose, String bubble}) _resolveMood({
    required BelajarProvider belajar,
    required TargetProvider target,
    required TransactionProvider tx,
  }) {
    if (_isCelebratingLevelUp) {
      return (pose: FeenPose.levelup, bubble: 'Yeay, naik level!');
    }
    if (tx.isRecentlySpent) {
      return (pose: FeenPose.alert, bubble: 'Hati-hati boros ya!');
    }
    if (tx.isRecentlyDebt) {
      return (pose: FeenPose.alert, bubble: 'Jangan lupa lunasi utangnya!');
    }
    if (belajar.isRecentlyLearned) {
      return (pose: FeenPose.learning, bubble: 'Keren, baru siap belajar!');
    }
    if (target.isRecentlySaved) {
      return (pose: FeenPose.saving, bubble: 'Mantap, tabungan nambah!');
    }
    return (pose: FeenPose.normal, bubble: 'Tanya aku!');
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _levelUpTimer?.cancel();
    _moodRefreshTimer?.cancel();
    _bob.dispose();
    super.dispose();
  }

  Widget _buildHintBubble(String text) {
    const border = BorderSide(color: primaryGreen, width: 1.5);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _showHint ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 156),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.fromBorderSide(border),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 3,
                softWrap: true,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 11,
                  height: 1.25,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 34),
              child: Transform.translate(
                offset: const Offset(0, -5),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: cardBg,
                      border: Border(right: border, bottom: border),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final belajar = context.watch<BelajarProvider>();
    final target = context.watch<TargetProvider>();
    final tx = context.watch<TransactionProvider>();

    _checkLevelUp(user.level);

    final mood = _resolveMood(
      belajar: belajar,
      target: target,
      tx: tx,
    );

    if (_lastBubbleText != null && _lastBubbleText != mood.bubble) {
      _triggerBubble();
    }
    _lastBubbleText = mood.bubble;

    return Semantics(
      button: true,
      label: 'Tanya Feen, asisten keuangan. Ketuk untuk membuka chat',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _bob,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -4 * _bob.value),
                child: child,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  FeenAvatar(
                    level: user.level,
                    pose: mood.pose,
                    equipped: user.feenEquipped,
                    size: 66,
                  ),
                  Positioned(
                    bottom: 64,
                    left: -86,
                    right: -6,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: _buildHintBubble(mood.bubble),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryGreen, width: 1),
                ),
                child: const Text(
                  'Tanya Feen',
                  style: TextStyle(
                    color: primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
