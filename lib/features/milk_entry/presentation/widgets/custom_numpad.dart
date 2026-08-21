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

  // The ordered grid — top-left to bottom-right.
  static const List<NumpadKey> _keys = [
    NumpadKey.one,
    NumpadKey.two,
    NumpadKey.three,
    NumpadKey.four,
    NumpadKey.five,
    NumpadKey.six,
    NumpadKey.seven,
    NumpadKey.eight,
    NumpadKey.nine,
    NumpadKey.decimal,
    NumpadKey.zero,
    NumpadKey.backspace,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the ideal aspect ratio so that 4 rows of buttons exactly fill
        // the available height inside this widget, preventing any cutoff.
        // We have 3 columns (2 inner spaces) and 4 rows (3 inner spaces).
        const double crossAxisSpacing = 10;
        const double mainAxisSpacing = 10;

        final double availableWidth = constraints.maxWidth;
        final double availableHeight = constraints.maxHeight;

        final double itemWidth = (availableWidth - (crossAxisSpacing * 2)) / 3;
        final double itemHeight = (availableHeight - (mainAxisSpacing * 3)) / 4;

        // Ensure we don't pass an invalid aspect ratio if constraints are strange
        final double aspectRatio = (itemHeight > 0) ? (itemWidth / itemHeight) : 1.15;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: aspectRatio,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
          ),
          itemCount: _keys.length,
          itemBuilder: (context, index) {
            final key = _keys[index];
            return _NumpadButton(
              numpadKey: key,
              onTap: () {
                HapticFeedback.lightImpact();
                onKeyTap(key);
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _NumpadButton
// A single large circular key. Numbers use a bright white circle;
// the backspace key uses a slightly tinted grey circle to visually
// distinguish it — exactly as in the mockup.
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
          // Minimum 60 px height enforced by the grid's childAspectRatio.
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            color: _isBackspace
                ? const Color(0xFFE8E8EE) // distinct tint for backspace
                : AppColors.cardWhite,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isBackspace ? 0.04 : 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
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
        color: AppColors.textDark,
        size: 26,
      );
    }

    final char = widget.numpadKey.character ?? '';

    // The decimal point is rendered smaller so it aligns optically.
    final bool isDecimal = widget.numpadKey == NumpadKey.decimal;

    return Text(
      char,
      style: TextStyle(
        color: AppColors.textDark,
        fontSize: isDecimal ? 30 : 32,
        fontWeight: FontWeight.w500,
        height: 1.0,
      ),
    );
  }
}
