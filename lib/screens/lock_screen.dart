import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  final _localAuth = LocalAuthentication();
  String? error;
  bool _biometricReady = false;
  bool _authenticating = false;
  bool _autoPrompted = false;
  String _biometricLabel = 'Biometric unlock';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareBiometricUnlock());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepareBiometricUnlock() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = canCheck ? await _localAuth.getAvailableBiometrics() : const <BiometricType>[];
      final ready = available.isNotEmpty;
      final label = available.contains(BiometricType.face)
          ? 'Face unlock'
          : available.contains(BiometricType.fingerprint)
              ? 'Fingerprint unlock'
              : 'Biometric unlock';

      if (!mounted) return;
      setState(() {
        _biometricReady = ready;
        _biometricLabel = label;
      });

      if (ready && !_autoPrompted) {
        _autoPrompted = true;
        await _unlockWithBiometric(auto: true);
      }
    } on PlatformException {
      if (!mounted) return;
      setState(() => _biometricReady = false);
    }
  }

  Future<void> _unlockWithBiometric({bool auto = false}) async {
    if (_authenticating) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _authenticating = true;
      if (!auto) error = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock Money King',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;
      if (authenticated) {
        context.read<AppState>().unlockWithBiometric();
        return;
      }

      if (!auto) {
        setState(() => error = 'Fingerprint not verified');
      }
    } on PlatformException {
      if (mounted && !auto) {
        setState(() => error = 'Biometric unlock is not available right now');
      }
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  void _unlockWithPasscode() {
    final ok = context.read<AppState>().unlock(_controller.text.trim());
    if (!ok) {
      setState(() => error = 'Wrong passcode');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF07111C),
              Color(0xFF0B1624),
              Color(0xFF08111A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: _glowOrb(colorScheme.primary.withOpacity(0.22)),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: _glowOrb(Colors.white.withOpacity(0.08)),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Text(
                            'SECURE ACCESS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white.withOpacity(0.80),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.2,
                                ),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary.withOpacity(0.92),
                                Color.lerp(colorScheme.primary, Colors.white, 0.16) ?? colorScheme.primary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.28),
                                blurRadius: 32,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 48),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Unlock Money King',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Use your fingerprint for instant access or enter your 4-digit passcode.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.62),
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _secureChip(Icons.shield_outlined, 'Private lock'),
                            _secureChip(Icons.fingerprint_rounded, _biometricReady ? _biometricLabel : 'Passcode unlock'),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enter passcode',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _controller,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                obscuringCharacter: '•',
                                maxLength: 4,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                onChanged: (_) {
                                  if (error != null) {
                                    setState(() => error = null);
                                  }
                                },
                                onSubmitted: (_) => _unlockWithPasscode(),
                                decoration: InputDecoration(
                                  hintText: '• • • •',
                                  counterText: '',
                                  hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.26),
                                        letterSpacing: 10,
                                      ),
                                  errorText: error,
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.05),
                                  errorStyle: const TextStyle(color: Color(0xFFFF8D8D)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _unlockWithPasscode,
                                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                                icon: const Icon(Icons.lock_open_rounded),
                                label: const Text('Unlock with passcode'),
                              ),
                              if (_biometricReady) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _authenticating ? null : () => _unlockWithBiometric(),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(54),
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                                  ),
                                  icon: _authenticating
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white.withOpacity(0.85),
                                          ),
                                        )
                                      : const Icon(Icons.fingerprint_rounded),
                                  label: Text(_authenticating ? 'Checking fingerprint…' : _biometricLabel),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Professional secure access with biometric unlock and local passcode fallback.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.48),
                                height: 1.45,
                              ),
                        ),
                      ],
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

  Widget _secureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.84)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.82),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(Color color) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 120,
              spreadRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}
