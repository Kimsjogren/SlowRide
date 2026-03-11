import 'package:flutter/material.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/features/auth/register_screen.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/widgets/app_background.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = AuthService.instance;

    return AppBackground(
      child: ValueListenableBuilder<bool>(
        valueListenable: authService.isLoggedIn,
        builder: (context, isLoggedIn, _) {
          return ValueListenableBuilder<String?>(
            valueListenable: authService.userName,
            builder: (context, userName, _) {
              final email = authService.userEmail.value;
              final displayName = userName ?? 'SlowRider';

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isLoggedIn ? Icons.person : Icons.person_outline,
                        size: 48,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Namn / inloggad status
                    if (isLoggedIn) ...[
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ] else
                      Text(
                        l10n.profileNotSignedIn,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 28),

                    // Info-kort
                    _InfoCard(
                      children: [
                        if (!isLoggedIn) ...[
                          _InfoRow(
                            icon: Icons.info_outline,
                            text: l10n.profileSignInInConvoyHint,
                          ),
                        ] else ...[
                          _InfoRow(
                            icon: Icons.check_circle_outline,
                            text: 'Inloggad',
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Statistik-kort
                    _InfoCard(
                      title: 'Statistik',
                      children: [
                        _StatRow(label: 'Körda konvojer', value: '—'),
                        _StatRow(label: 'Totalt avstånd', value: '— km'),
                        _StatRow(label: 'Hastighetsöverträdelser', value: '—'),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Logga in / Skapa konto (ej inloggad)
                    if (!isLoggedIn) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: Text(AppLocalizations.of(context)!.signIn),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E6BFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.white70,
                          ),
                          label: const Text(
                            'Skapa konto',
                            style: TextStyle(color: Colors.white70),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Logga ut-knapp
                    if (isLoggedIn)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: authService.signOut,
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          label: Text(
                            l10n.signOut,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white60),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
