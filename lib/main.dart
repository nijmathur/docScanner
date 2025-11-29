import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'core/services/auth_service.dart';
import 'core/services/database_service.dart';
import 'core/services/encryption_service.dart';
import 'core/services/audit_service.dart';

void main() {
  runApp(const DocScannerApp());
}

class DocScannerApp extends StatelessWidget {
  const DocScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<EncryptionService>(
          create: (_) => EncryptionService(),
        ),
        Provider<AuthService>(
          create: (context) => AuthService(
            encryptionService: context.read<EncryptionService>(),
          ),
        ),
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
        ),
        ProxyProvider<DatabaseService, AuditService>(
          update: (context, dbService, _) => AuditService(
            databaseService: dbService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Secure Document Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const AppInitializer(),
      ),
    );
  }
}

/// App initializer - checks authentication and routes to appropriate screen
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final authService = context.read<AuthService>();

    // Check if app is set up
    final isSetUp = await authService.isSetUp();

    if (isSetUp) {
      // Check for session timeout
      final hasTimedOut = await authService.hasSessionTimedOut();
      setState(() {
        _isAuthenticated = !hasTimedOut;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isAuthenticated ? const HomeScreen() : const AuthScreen();
  }
}
