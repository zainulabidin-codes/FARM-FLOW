import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// CustomNumpad
// ---------------------------------------------------------------------------
// A self-contained grid of large circular tap targets used for numeric input.
// It does NOT hold any state — the parent drives the display value and
// receives key presses via [onKeyTap].
//
// Layout (3 columns × 4 rows):
//   [ 1 ] [ 2 ] [ 3 ]
//   [ 4 ] [ 5 ] [ 6 ]
//   [ 7 ] [ 8 ] [ 9 ]
//   [ . ] [ 0 ] [⌫ ]
// ---------------------------------------------------------------------------

/// Enumerates every key on the numpad so the parent can react cleanly
/// without parsing raw strings.
enum NumpadKey {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  decimal,
  backspace,
}

extension NumpadKeyValue on NumpadKey {
  /// Returns the character this key appends, or `null` for backspace.
  String? get character => switch (this) {
        NumpadKey.zero => '0',
        NumpadKey.one => '1',
        NumpadKey.two => '2',
        NumpadKey.three => '3',
        NumpadKey.four => '4',
        NumpadKey.five => '5',
        NumpadKey.six => '6',
        NumpadKey.seven => '7',
        NumpadKey.eight => '8',
        NumpadKey.nine => '9',
        NumpadKey.decimal => '.',
        NumpadKey.backspace => null,
      };
}

class CustomNumpad extends StatelessWidget {
  /// Called whenever the user taps any key.
  final ValueChanged<NumpadKey> onKeyTap;

  const CustomNumpad({
    super.key,
    required this.onKeyTap,
  });

  @override
  Widget build(BuildContext context) {
    const double rowGap = 10;
    const double colGap = 10;

    final rows = [
      [NumpadKey.one, NumpadKey.two, NumpadKey.three],
      [NumpadKey.four, NumpadKey.five, NumpadKey.six],
      [NumpadKey.seven, NumpadKey.eight, NumpadKey.nine],
      [NumpadKey.decimal, NumpadKey.zero, NumpadKey.backspace],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.asMap().entries.map((entry) {
        final rowIndex = entry.key;
        final rowKeys = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex < rows.length - 1 ? rowGap : 0),
          child: Row(
            children: rowKeys.asMap().entries.map((keyEntry) {
              final colIndex = keyEntry.key;
              final key = keyEntry.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: colIndex < rowKeys.length - 1 ? colGap : 0),
                  child: _NumpadButton(
                    numpadKey: key,
                    onTap: () {
                      try { HapticFeedback.lightImpact(); } catch (_) {}
                      onKeyTap(key);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// _NumpadButton
// ---------------------------------------------------------------------------
class _NumpadButton extends StatefulWidget {
  final NumpadKey numpadKey;
  final VoidCallback onTap;

  const _NumpadButton({required this.numpadKey, required this.onTap});

  @override
  State<_NumpadButton> createState() => _NumpadButtonState();
}

class _NumpadButtonState extends State<_NumpadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _scaleController.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleController.forward();
    widget.onTap();
  }

  void _onTapCancel() {
    _scaleController.forward();
  }

  bool get _isBackspace => widget.numpadKey == NumpadKey.backspace;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          height: 56,
          decoration: BoxDecoration(
            color: _isBackspace ? AppColors.backspaceBg : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: _isBackspace ? const Color(0xFFE7E5E4) : const Color(0xFFF5F5F4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkForest.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: _buildKeyContent()),
        ),
      ),
    );
  }

  Widget _buildKeyContent() {
    if (_isBackspace) {
      return const Icon(
        Icons.backspace_outlined,
        color: AppColors.darkForest,
        size: 22,
      );
    }

    final char = widget.numpadKey.character ?? '';
    final bool isDecimal = widget.numpadKey == NumpadKey.decimal;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        isDecimal ? '·' : char,
        style: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: AppColors.darkForest,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
