import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../state/canvas_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasState = ref.watch(canvasProvider);
    final nodeCount = canvasState.nodes.length;
    const activeAlerts = 0;
    
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Unknown User';
    final name = user?.userMetadata?['full_name'] ?? email.split('@')[0];
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── HEADER WITH AVATAR ───────────────────────────────────────────
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8083FF), Color(0xFF2DD4BF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8083FF).withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: GoogleFonts.manrope(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF121212), width: 3),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // ── NAME & EMAIL ─────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    name.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      email,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // ── STATS ROW ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _statCard('NODES', nodeCount.toString(), Icons.hub_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('ALERTS', activeAlerts.toString(), Icons.warning_amber_rounded)),
              ],
            ),
            const SizedBox(height: 32),
            
            // ── ORGANIZATION DETAILS ─────────────────────────────────────────
            _sectionHeader('ORGANIZATION'),
            const SizedBox(height: 12),
            _infoTile(Icons.business, 'Demo Organization', 'OEM / Manufacturer'),
            _infoTile(Icons.verified_user_outlined, 'Lead Administrator', 'Full System Access'),
            
            const SizedBox(height: 24),
            
            // ── SECURITY / SETTINGS ──────────────────────────────────────────
            _sectionHeader('SECURITY'),
            const SizedBox(height: 12),
            _actionTile(Icons.lock_outline, 'Update Access Keys'),
            _actionTile(Icons.security, '2FA Protocols'),
            
            const SizedBox(height: 40),
            
            // ── LOGOUT BUTTON ────────────────────────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  // In a real app, the listener in main.dart would handle this, 
                  // but for now we can push back to login.
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'DISCONNECT SESSION',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF2DD4BF), size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Colors.white30,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(subtitle, style: GoogleFonts.manrope(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white54, size: 18),
              const SizedBox(width: 16),
              Flexible(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
