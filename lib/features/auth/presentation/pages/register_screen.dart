import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';

// ---------------------------------------------------------------------------
// RegisterScreen
// ---------------------------------------------------------------------------

class RegisterScreen extends StatefulWidget {
  final void Function(
    String username,
    String password,
    String farmName,
    String farmerName,
  ) onSignupTap;
  
  final VoidCallback onBackTap;

  const RegisterScreen({
    super.key,
    required this.onSignupTap,
    required this.onBackTap,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmerNameController = TextEditingController();
  bool _obscurePassword = true;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _farmNameController.dispose();
    _farmerNameController.dispose();
    super.dispose();
  }

  void _handleSignup() {
    HapticFeedback.lightImpact();
    widget.onSignupTap(
      _usernameController.text.trim(),
      _passwordController.text,
      _farmNameController.text.trim(),
      _farmerNameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _FarmBackground(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                _AppLogoHeader(),
              ],
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _RegisterCard(
                    usernameController: _usernameController,
                    passwordController: _passwordController,
                    farmNameController: _farmNameController,
                    farmerNameController: _farmerNameController,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    onSignupTap: _handleSignup,
                    onBackTap: widget.onBackTap,
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
                  color: Colors.white.withAlpha(46), // ~0.18 * 255
                ),
              ),
            ),
          ),
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
                    Colors.white.withAlpha(0),
                    Colors.white.withAlpha(56), // ~0.22 * 255
                    Colors.white.withAlpha(0),
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

class _AppLogoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(230), // ~0.90 * 255
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(31), // ~0.12 * 255
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
          'Register Farm',
          style: TextStyle(
            color: Colors.white.withAlpha(217), // ~0.85 * 255
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController farmNameController;
  final TextEditingController farmerNameController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onSignupTap;
  final VoidCallback onBackTap;

  const _RegisterCard({
    required this.usernameController,
    required this.passwordController,
    required this.farmNameController,
    required this.farmerNameController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSignupTap,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Color(0xF5FFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 32,
            offset: Offset(0, 8),
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
              Text(
                'Create Profile',
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
                'Enter details to register',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),

              _InputField(
                controller: farmNameController,
                hint: 'Farm Name',
                prefixIcon: Icons.home_work_outlined,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              _InputField(
                controller: farmerNameController,
                hint: 'Farmer Name',
                prefixIcon: Icons.person_outline_rounded,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              _InputField(
                controller: usernameController,
                hint: AppStrings.usernameHint,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              _InputField(
                controller: passwordController,
                hint: AppStrings.passwordHint,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSignupTap(),
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

              _PrimaryButton(
                label: 'Register Farm',
                icon: Icons.person_add_alt_1_rounded,
                onTap: onSignupTap,
              ),
              const SizedBox(height: 14),

              _SecondaryButton(
                label: 'Back to Login',
                icon: Icons.arrow_back_rounded,
                onTap: onBackTap,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

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
