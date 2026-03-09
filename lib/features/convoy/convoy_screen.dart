import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/features/auth/login_screen.dart';
import 'package:slowride/features/auth/register_screen.dart';
import 'package:slowride/features/convoy/convoy_controller.dart';
import 'package:slowride/features/convoy/convoy_room_screen.dart';
import 'package:slowride/models/convoy_model.dart';
import 'package:slowride/services/auth_service.dart';
import 'package:slowride/widgets/app_background.dart';

class ConvoyScreen extends StatefulWidget {
  const ConvoyScreen({super.key});

  @override
  State<ConvoyScreen> createState() => _ConvoyScreenState();
}

class _ConvoyScreenState extends State<ConvoyScreen> {
  final ConvoyController _controller = ConvoyController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInCodeController = TextEditingController();
  bool _showOnlyMyConvoys = false;
  int _streamKey = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _signInEmailController.dispose();
    _signInCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog(AppLocalizations l10n) async {
    _nameController.text = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF1E6BFF).withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.groups,
                      color: Color(0xFF3AA8FF),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.convoyNameDialogTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: l10n.convoyNameHint,
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E6BFF)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        l10n.convoyCreateCancel,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E6BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.of(ctx).pop();
                        await _controller.createConvoy(name: name);
                        if (mounted) setState(() => _streamKey++);
                      },
                      child: Text(l10n.convoyCreateConfirm),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareConvoy(ConvoyModel convoy) {
    final code = convoy.id.split('-').first.toUpperCase();
    Clipboard.setData(
      ClipboardData(text: 'SlowRide konvoj: "${convoy.name}" (kod: $code)'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kopierat! Dela: "${convoy.name}" kod: $code'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = AuthService.instance;

    return AppBackground(
      child: ValueListenableBuilder<bool>(
        valueListenable: authService.isLoggedIn,
        builder: (context, isLoggedIn, _) {
          if (!isLoggedIn) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.groups, size: 36, color: Colors.white70),
                      const SizedBox(height: 16),
                      Text(
                        l10n.convoyRequiresSignInTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.convoyRequiresSignInSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.login),
                            label: Text(l10n.signIn),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add_alt_1),
                            label: Text(l10n.signUp),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.convoyModeTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.convoyModeSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _showCreateDialog(l10n),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.convoyCreateButton),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  child: Row(
                    children: [
                      _FilterTab(
                        label: l10n.convoyFilterAll,
                        selected: !_showOnlyMyConvoys,
                        onTap: () => setState(() => _showOnlyMyConvoys = false),
                      ),
                      _FilterTab(
                        label: l10n.convoyFilterMine,
                        selected: _showOnlyMyConvoys,
                        onTap: () => setState(() => _showOnlyMyConvoys = true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!authService.supportsRealtimeBackend)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    l10n.convoyRealtimeBackendMissing,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: StreamBuilder<List<ConvoyModel>>(
                  key: ValueKey(_streamKey),
                  stream: _controller.watchConvoys(),
                  builder: (context, snapshot) {
                    final allConvoys = snapshot.data ?? const [];
                    final convoys = _showOnlyMyConvoys
                        ? allConvoys
                              .where((convoy) => convoy.isJoined)
                              .toList(growable: false)
                        : allConvoys;

                    if (convoys.isEmpty) {
                      return Center(
                        child: Text(
                          _showOnlyMyConvoys
                              ? l10n.convoyListEmptyMine
                              : l10n.convoyListEmpty,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: convoys.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final convoy = convoys[index];
                        final isLeader =
                            convoy.leaderId ==
                            AuthService.instance.userId.value;
                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          decoration: BoxDecoration(
                            color: convoy.isJoined
                                ? const Color(
                                    0xFF1E6BFF,
                                  ).withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: convoy.isJoined
                                  ? const Color(
                                      0xFF3AA8FF,
                                    ).withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.13),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Ikon
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E6BFF,
                                  ).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  convoy.isJoined
                                      ? Icons.groups
                                      : Icons.groups_outlined,
                                  color: convoy.isJoined
                                      ? const Color(0xFF3AA8FF)
                                      : Colors.white60,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      convoy.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 11,
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${convoy.memberCount} ${convoy.memberCount == 1 ? "medlem" : "medlemmar"}',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (isLeader) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF1E6BFF,
                                              ).withValues(alpha: 0.35),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Din',
                                              style: TextStyle(
                                                color: Color(0xFF3AA8FF),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Åtgärdsknappar
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (convoy.isJoined)
                                    IconButton(
                                      onPressed: () => _shareConvoy(convoy),
                                      icon: const Icon(
                                        Icons.ios_share,
                                        size: 18,
                                        color: Colors.white60,
                                      ),
                                      tooltip: 'Bjud in',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    height: 36,
                                    child: convoy.isJoined
                                        ? FilledButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      ConvoyRoomScreen(
                                                        convoy: convoy,
                                                      ),
                                                ),
                                              );
                                            },
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1E6BFF,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text(
                                              'Öppna',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          )
                                        : OutlinedButton(
                                            onPressed: () async {
                                              await _controller.joinConvoy(
                                                convoy: convoy,
                                              );
                                              if (mounted)
                                                setState(() => _streamKey++);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text(
                                              'Gå med',
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E6BFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
