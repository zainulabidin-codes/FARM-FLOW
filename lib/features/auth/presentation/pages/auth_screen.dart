import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';

// ---------------------------------------------------------------------------
// AuthScreen
// ---------------------------------------------------------------------------
// Pure UI — no business logic here. All user actions are surfaced via
// the [onLoginTap] and [onSignupTap] callbacks so the navigation/business
// layer (wired in Task 7) can respond without touching this widget.
// ---------------------------------------------------------------------------

class AuthScreen extends StatefulWidget {
  /// Called when the user taps "Login".
  /// Receives the current values of the username and password fields.
  final void Function(String username, String password) onLoginTap;

  /// Called when the user taps "Create Farm Profile".
  final VoidCallback onSignupTap;

  const AuthScreen({
    super.key,
    required this.onLoginTap,
    required this.onSignupTap,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Entry animation for the card sliding up from the bottom.
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    // Start the animation after the first frame so the hero background
    // is already painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    HapticFeedback.lightImpact();
    widget.onLoginTap(
      _usernameController.text.trim(),
      _passwordController.text,
    );
  }

  void _handleSignup() {
    HapticFeedback.lightImpact();
    widget.onSignupTap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove the scaffold's own background so our gradient shows through.
      backgroundColor: Colors.transparent,
      // Resize to avoid the keyboard pushing the card up awkwardly.
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── (1) Background gradient — mimics the lush farm meadow ────────
          _FarmBackground(),

          // ── (2) Top logo + "Welcome Back" text above the card ───────────
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                _AppLogoHeader(),
                // The rest of the space is taken by the scrollable card.
              ],
            ),
          ),

          // ── (3) Animated card ─────────────────────────────────────
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _AuthCard(
                    usernameController: _usernameController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    onLoginTap: _handleLogin,
                    onSignupTap: _handleSignup,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FarmBackground
// Renders a layered gradient that evokes a sunlit green farm field, as seen
// in the visual mockup (sky → horizon haze → rich meadow green).
// ---------------------------------------------------------------------------
class _FarmBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.35, 0.60, 1.0],
          colors: [
            Color(0xFFB8D8E8), // soft sky blue
            Color(0xFFD6E8C8), // pale horizon haze
            Color(0xFF6AAF5A), // mid meadow green
            Color(0xFF3E8B2A), // deep grass green
          ],
        ),
      ),
      child: Stack(
        children: [
          // Subtle oval "sun glow" at the top centre.
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          // Light fog band at the horizon.
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppLogoHeader
// Displays the tractor/farm icon and "FarmSync / DairyFarm Pro" branding
// that appears above the login card in the mockup.
// ---------------------------------------------------------------------------
class _AppLogoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Shield-style icon background.
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.agriculture_rounded,
            color: AppColors.deepGreen,
            size: 40,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Welcome Back',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _AuthCard
// The frosted-glass card that holds all login inputs and action buttons.
// ---------------------------------------------------------------------------
class _AuthCard extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onLoginTap;
  final VoidCallback onSignupTap;

  const _AuthCard({
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onLoginTap,
    required this.onSignupTap,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      // Respect the soft keyboard insets.
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xF5FFFFFF), // ~96% white — "frosted" feel
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Logo icon inside the card ────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.sageTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.agriculture_rounded,
                  color: AppColors.deepGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────────────
              Text(
                AppStrings.welcomeTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appTagline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),

              // ── Username field ───────────────────────────────────────────
              _InputField(
                controller: usernameController,
                hint: AppStrings.usernameHint,
                prefixIcon: Icons.person_outline_rounded,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              // ── Password field ───────────────────────────────────────────
              _InputField(
                controller: passwordController,
                hint: AppStrings.passwordHint,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onLoginTap(),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textGrey,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              const SizedBox(height: 28),

              // ── Login button (filled, deep green) ────────────────────────
              _PrimaryButton(
                label: AppStrings.loginButton,
                icon: Icons.login_rounded,
                onTap: onLoginTap,
              ),
              const SizedBox(height: 14),

              // ── Create Farm Profile button (outlined) ────────────────────
              _SecondaryButton(
                label: AppStrings.createFarmButton,
                icon: Icons.person_add_alt_1_rounded,
                onTap: onSignupTap,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _InputField — reusable styled text field
// ---------------------------------------------------------------------------
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: Colors.grey[600]),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PrimaryButton — filled deep-green pill button
// ---------------------------------------------------------------------------
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SecondaryButton — outlined pill button
// ---------------------------------------------------------------------------
class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          side: const BorderSide(color: AppColors.deepGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
