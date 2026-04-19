import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../canvas/multiplayer_canvas.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // ── Design tokens (shared with LoginPage) ────────────────────────────────
  static const _bg           = Color(0xFF000000);
  static const _inputBg      = Color(0xFF313533);
  static const _inputBorder  = Color(0xFF2D3449);
  static const _dividerColor = Color(0xFF2D3449);
  static const _orColor      = Color(0xFF8083FF);
  static const _systemsGreen = Color(0xFF10B981);
  static const _globalOpsIcon= Color(0xFF8083FF);
  static const _enterpriseBg = Color(0xFF272B29);
  static const _enterpriseBorder = Color(0xFF2D3449);

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill out all fields.')),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'full_name': _fullNameController.text.trim()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signup successful! Check your email if verification is required.',
            ),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MultiplayerCanvas()),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error occurred: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Centered Signup Card ────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Card
                Container(
                  width: 440,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 36),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment(-0.8, -0.8),
                      end: Alignment(0.8, 0.8),
                      stops: [0.2148, 0.5255, 0.8042],
                      colors: [
                        Color(0xFF000000),
                        Color(0xCC333333),
                        Color(0xFF000000),
                      ],
                    ),
                    border: const Border.fromBorderSide(BorderSide(
                      color: Color(0x4D404944),
                      width: 1,
                    )),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Logo Section ──────────────────────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CUROOT',
                            style: GoogleFonts.manrope(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: const Color(0xFFE1E3E0),
                              height: 32 / 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your account',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.35,
                              color: Colors.white,
                              height: 20 / 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Form ──────────────────────────────────────────
                      _buildField(
                        label: 'FULL NAME',
                        hint: 'Jane Doe',
                        controller: _fullNameController,
                        obscure: false,
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'CORPORATE EMAIL',
                        hint: 'name@company.com',
                        controller: _emailController,
                        obscure: false,
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'PASSWORD',
                        hint: '••••••••',
                        controller: _passwordController,
                        obscure: true,
                      ),
                      const SizedBox(height: 24),

                      // ── Create Account Button ─────────────────────────
                      _buildCreateAccountButton(),
                      const SizedBox(height: 14),

                      // ── OR Divider ────────────────────────────────────
                      _buildOrDivider(),
                      const SizedBox(height: 14),

                      // ── Already have account row ──────────────────────
                      _buildSignInRow(),
                      const SizedBox(height: 20),

                      // ── Footer text ───────────────────────────────────
                      Center(
                        child: Text(
                          'By creating an account, you agree to our\nTerms of Service and Privacy Policy.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            height: 20 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── System Status Bar ─────────────────────────────────────
                const SizedBox(height: 20),
                _buildSystemStatusBar(),
              ],
            ),
          ),

          // ── Enterprise Support pill (bottom-right) ──────────────────────
          Positioned(
            bottom: 32,
            right: 32,
            child: _buildEnterpriseSupportButton(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sub-widgets
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    String? rightLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Colors.white,
                height: 16 / 12,
              ),
            ),
            if (rightLabel != null)
              Text(
                rightLabel,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 16 / 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 54,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 22 / 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: _inputBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _inputBorder, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _inputBorder, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _inputBorder, width: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateAccountButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-1, 0),
          end: Alignment(1, 0),
          colors: [Color(0xFF2D3449), Color(0xFF5153A4)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isLoading ? null : _signUp,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create Account',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Colors.white,
                          height: 24 / 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 14),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: _dividerColor, thickness: 1, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OR',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: _orColor,
                height: 15 / 10,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: _dividerColor, thickness: 1, height: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInRow() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: _inputBg,
        border: Border.all(color: _inputBorder, width: 1),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
          child: Center(
            child: Text(
              'Already have an account ? Sign in',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                height: 22 / 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatusBar() {
    return SizedBox(
      width: 440,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: green dot · SYSTEMS NOMINAL | v4.82.0-STABLE
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _systemsGreen,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'SYSTEMS NOMINAL',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white,
                    height: 15 / 10,
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 12, color: _dividerColor),
                const SizedBox(width: 16),
                Text(
                  'v4.82.0-STABLE',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 15 / 10,
                  ),
                ),
              ],
            ),
            // Right: globe + GLOBAL OPS
            Row(
              children: [
                const Icon(Icons.language,
                    color: _globalOpsIcon, size: 11.67),
                const SizedBox(width: 8),
                Text(
                  'GLOBAL OPS',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white,
                    height: 15 / 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterpriseSupportButton() {
    return Container(
      height: 42.67,
      decoration: BoxDecoration(
        color: _enterpriseBg,
        border: Border.all(color: _enterpriseBorder, width: 1),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9999),
          onTap: () {},
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.help_outline,
                    color: Colors.white, size: 14.17),
                const SizedBox(width: 12),
                Text(
                  'Enterprise Support',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white,
                    height: 16 / 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
