import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../canvas/multiplayer_canvas.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Design tokens from CSS spec
  static const _bg = Color(0xFF000000);
  static const _inputBg = Color(0xFF313533);
  static const _inputBorder = Color(0xFF2D3449);
  static const _labelColor = Colors.white;
  static const _orColor = Color(0xFF8083FF);
  static const _dividerColor = Color(0xFF2D3449);
  static const _systemsGreen = Color(0xFF10B981);
  static const _globalOpsIcon = Color(0xFF8083FF);
  static const _enterpriseBg = Color(0xFF272B29);
  static const _enterpriseBorder = Color(0xFF2D3449);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill out all fields.')),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
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
          // ── Centered Login Card ─────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Login Card
                Container(
                    width: 440,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
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
                        // ── Logo Section ──────────────────────────────
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
                              'Supply Chain Intelligence',
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

                        // ── Form ────────────────────────────────────────────
                        _buildEmailField(),
                        const SizedBox(height: 24),
                        _buildPasswordField(),
                        const SizedBox(height: 24),

                        // ── Sign In Button ────────────────────────────
                        _buildSignInButton(),
                        const SizedBox(height: 16),

                        // ── OR Divider ────────────────────────────────
                        _buildOrDivider(),
                        const SizedBox(height: 16),

                        // ── Sign Up / SSO Row ─────────────────────────
                        _buildSignUpRow(),
                        const SizedBox(height: 20),

                        // ── Footer text ───────────────────────────────
                        Center(
                          child: Text(
                            'Access is restricted to authorized personnel.\nBy logging in, you agree to our Data Security Protocols.',
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

                // ── System Status Bar (below card) ──────────────────
                const SizedBox(height: 20),
                _buildSystemStatusBar(),
              ],
            ),
          ),

          // ── Enterprise Support pill (bottom-right) ──────────────────
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

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CORPORATE EMAIL',
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: _labelColor,
            height: 16 / 12,
          ),
        ),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _emailController,
          hint: 'name@company.com',
          obscure: false,
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PASSWORD',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: _labelColor,
                height: 16 / 12,
              ),
            ),
            Text(
              'Forgot Access?',
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
        _buildInputField(
          controller: _passwordController,
          hint: '••••••••',
          obscure: true,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
  }) {
    return SizedBox(
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
    );
  }

  Widget _buildSignInButton() {
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
          onTap: _isLoading ? null : _signIn,
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
                        'Sign In',
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
      padding: const EdgeInsets.only(top: 8),
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

  Widget _buildSignUpRow() {
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
              MaterialPageRoute(builder: (context) => const SignupPage()),
            );
          },
          child: Center(
            child: Text(
              "Don't have an account ? Sign up",
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
            // Left: SYSTEMS NOMINAL | v4.82.0-STABLE
            Row(
              children: [
                // Green dot
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
                // Vertical divider
                Container(
                  width: 1,
                  height: 12,
                  color: _dividerColor,
                ),
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
            // Right: Globe icon + GLOBAL OPS
            Row(
              children: [
                const Icon(Icons.language, color: _globalOpsIcon, size: 11.67),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
