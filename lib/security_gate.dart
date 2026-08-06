import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:local_auth/local_auth.dart';

import 'job_profile_database.dart';

class SecurityGate extends StatefulWidget {
  const SecurityGate({super.key, required this.child});

  final Widget child;

  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<SecurityGate> with WidgetsBindingObserver {
  static const Duration _gracePeriod = Duration(minutes: 5);
  // Keep the native auth prompt short so Android does not truncate it.
  static const String _unlockReason = 'Unlock Work Hours Tracker';
  static const String _unsupportedLockMessage =
      'Swipe and None are not supported. Please enable PIN, password, pattern, or biometrics to use myWorkHoursTracker.';

  final LocalAuthentication _localAuth = LocalAuthentication();

  DateTime? _pausedAt;
  bool _isLocked = true;
  bool _isAuthenticating = false;
  bool _isShowingSecurityDialog = false;
  String? _lockScreenErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handleResume() async {
    final DateTime? pausedAt = _pausedAt;
    if (pausedAt != null) {
      final Duration backgroundDuration = DateTime.now().difference(pausedAt);
      // Compare the current clock to the saved pause timestamp; only gaps beyond the grace period relock the app.
      if (backgroundDuration >= _gracePeriod) {
        await _lockAndCloseDatabase();
      }
    }
  }

  Future<void> _lockAndCloseDatabase() async {
    await JobProfileDatabase.instance.closeDatabase();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLocked = true;
      _lockScreenErrorMessage = null;
    });
  }

  Future<void> _attemptUnlock() async {
    if (_isAuthenticating || !mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final bool deviceSupported = await _localAuth.isDeviceSupported();

      if (!mounted) {
        return;
      }

      if (!deviceSupported) {
        setState(() {
          _lockScreenErrorMessage = _unsupportedLockMessage;
        });
        return;
      }

      setState(() {
        _lockScreenErrorMessage = null;
      });

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: _unlockReason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) {
        return;
      }

      if (authenticated) {
        setState(() {
          _isLocked = false;
          _lockScreenErrorMessage = null;
        });
      }
    } on PlatformException {
      // On local_auth 2.3.0, credential/prompt failures surface as PlatformException.
      // The preflight capability check already handles the no-device-credentials case.
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _handleOpenDeviceLockPressed() async {
    if (_isAuthenticating || !mounted) {
      return;
    }

    final bool deviceSupported = await _localAuth.isDeviceSupported();

    if (!mounted) {
      return;
    }

    if (!deviceSupported) {
      setState(() {
        _lockScreenErrorMessage = _unsupportedLockMessage;
      });
      return;
    }

    setState(() {
      _lockScreenErrorMessage = null;
    });

    await _attemptUnlock();
  }

  Future<void> _openAndroidSecuritySettings() async {
    if (!mounted) {
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      await _showUnsupportedPlatformDialog();
      return;
    }

    final AndroidIntent intent = AndroidIntent(
      action: 'android.settings.SECURITY_SETTINGS',
    );
    await intent.launch();
  }

  Future<void> _showUnsupportedPlatformDialog() async {
    if (!mounted || _isShowingSecurityDialog) {
      return;
    }

    _isShowingSecurityDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Security settings unavailable'),
              content: const Text(
                'Android security settings can only be opened on an Android device.',
              ),
              actions: <Widget>[
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _isShowingSecurityDialog = false;
    }
  }

  Future<void> _showNoDeviceSecurityDialog() async {
    if (!mounted || _isShowingSecurityDialog) {
      return;
    }

    _isShowingSecurityDialog = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Device lock needed'),
              content: const Text(
                'Swipe and None are not supported. Please enable PIN, password, pattern, or biometrics to use myWorkHoursTracker.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _openAndroidSecuritySettings();
                  },
                  child: const Text('Open security settings'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _isShowingSecurityDialog = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return _LockScreen(
        isAuthenticating: _isAuthenticating,
        onUnlockPressed: _handleOpenDeviceLockPressed,
        onOpenSecuritySettingsPressed: _openAndroidSecuritySettings,
        errorMessage: _lockScreenErrorMessage,
      );
    }

    return widget.child;
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.isAuthenticating,
    required this.onUnlockPressed,
    required this.onOpenSecuritySettingsPressed,
    required this.errorMessage,
  });

  final bool isAuthenticating;
  final VoidCallback onUnlockPressed;
  final VoidCallback onOpenSecuritySettingsPressed;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_outline, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Work Hours Tracker is locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Use a device PIN, password, pattern, or biometrics to open the app. Swipe and None are not supported.',
                    textAlign: TextAlign.center,
                  ),
                  if (errorMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: isAuthenticating ? null : onUnlockPressed,
                    icon: isAuthenticating
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.key),
                    label: Text(
                      isAuthenticating ? 'Authenticating' : 'Open device lock',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: isAuthenticating
                        ? null
                        : onOpenSecuritySettingsPressed,
                    icon: const Icon(Icons.settings),
                    label: const Text('Open security settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}