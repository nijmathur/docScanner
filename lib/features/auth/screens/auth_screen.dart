import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/audit_service.dart';
import '../../home/screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isSetupMode = false;
  bool _isLoading = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  String? _errorMessage;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _checkSetupStatus();
  }

  Future<void> _checkSetupStatus() async {
    final authService = context.read<AuthService>();
    final isSetUp = await authService.isSetUp();
    final failedAttempts = await authService.getFailedAttempts();

    setState(() {
      _isSetupMode = !isSetUp;
      _failedAttempts = failedAttempts;
      _isLoading = false;
    });
  }

  Future<void> _handleSetupPin() async {
    final pin = _pinController.text;
    final confirmPin = _confirmPinController.text;

    if (pin.isEmpty || confirmPin.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter PIN in both fields';
      });
      return;
    }

    if (pin != confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match';
      });
      return;
    }

    if (pin.length != 6) {
      setState(() {
        _errorMessage = 'PIN must be exactly 6 digits';
      });
      return;
    }

    try {
      final authService = context.read<AuthService>();
      await authService.setupPIN(pin);

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Setup failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleAuthenticate() async {
    final pin = _pinController.text;

    if (pin.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your PIN';
      });
      return;
    }

    try {
      final authService = context.read<AuthService>();
      final masterKey = await authService.authenticateWithPIN(pin);

      if (masterKey != null) {
        // Log successful authentication
        final auditService = context.read<AuditService>();
        await auditService.logAuthenticationSuccess(method: 'PIN');

        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        final failedAttempts = await authService.getFailedAttempts();
        final auditService = context.read<AuditService>();
        await auditService.logAuthenticationFailure(
          method: 'PIN',
          reason: 'Incorrect PIN',
        );

        setState(() {
          _failedAttempts = failedAttempts;
          _errorMessage = 'Incorrect PIN. Attempt $_failedAttempts of 5';
        });

        _pinController.clear();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleBiometric() async {
    try {
      final authService = context.read<AuthService>();
      final isAvailable = await authService.isBiometricAvailable();

      if (!isAvailable) {
        setState(() {
          _errorMessage = 'Biometric authentication not available';
        });
        return;
      }

      final masterKey = await authService.authenticateWithBiometric(
        reason: 'Authenticate to access documents',
      );

      if (masterKey != null) {
        final auditService = context.read<AuditService>();
        await auditService.logAuthenticationSuccess(method: 'Biometric');

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Biometric authentication failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Biometric error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.document_scanner,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                _isSetupMode ? 'Set Up PIN' : 'Welcome Back',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isSetupMode
                    ? 'Create a 6-digit PIN to secure your documents'
                    : 'Enter your PIN to continue',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: _obscurePin,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  hintText: 'Enter 6-digit PIN',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePin = !_obscurePin;
                      });
                    },
                  ),
                ),
              ),
              if (_isSetupMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: _obscureConfirmPin,
                  decoration: InputDecoration(
                    labelText: 'Confirm PIN',
                    hintText: 'Re-enter PIN',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPin
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPin = !_obscureConfirmPin;
                        });
                      },
                    ),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _failedAttempts >= 5
                    ? null
                    : (_isSetupMode ? _handleSetupPin : _handleAuthenticate),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _failedAttempts >= 5
                      ? 'Too many failed attempts'
                      : (_isSetupMode ? 'Set Up PIN' : 'Unlock'),
                ),
              ),
              if (!_isSetupMode) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed:
                      _failedAttempts >= 5 ? null : _handleBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Use Biometric'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
