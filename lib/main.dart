import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'firebase_options_staging.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'screens/recepcao_screen.dart';
import 'screens/staging_login_screen.dart';
import 'screens/tela_login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/main_shell.dart';

// ── Ambiente ──────────────────────────────────────────────────────────────────
// Compilar para staging:  --dart-define=ENV=staging
// Compilar para produção: sem flag (ou --dart-define=ENV=prod)
const _env = String.fromEnvironment('ENV', defaultValue: 'prod');
const kIsStaging = _env == 'staging';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final options = kIsStaging
      ? StagingFirebaseOptions.currentPlatform
      : DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: options);
  await ThemeController.instance.initialize();
  runApp(const VillamorCrmApp());
}

class VillamorCrmApp extends StatelessWidget {
  const VillamorCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (_, __) => MaterialApp(
        title: kIsStaging ? '[STAGING] Villamor CRM' : 'Villamor CRM',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeController.instance.mode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        home: kIsStaging ? const StagingLoginScreen() : const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// ── Auth wrapper ──────────────────────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  String? _perfil;
  String? _currentUserName;
  bool _carregandoPerfil = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;

        // Não autenticado
        if (user == null) {
          if (_perfil != null) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() {
                  _perfil = null;
                  _currentUserName = null;
                }));
          }
          return const TelaLoginScreen();
        }

        // Autenticado — carregando perfil + nome
        if (_perfil == null) {
          if (!_carregandoPerfil) {
            _carregandoPerfil = true;
            _authService.getCurrentUserProfileAndName().then((info) {
              if (mounted) {
                setState(() {
                  _perfil           = info['perfil'] as String;
                  _currentUserName  = info['nome']   as String?;
                  _carregandoPerfil = false;
                });
              }
            });
          }
          return const _LoadingScreen();
        }

        // Inicializa Web Push após login confirmado
        PushNotificationService().initialize();

        // Perfil recepção → shell dedicado sem sidebar CRM
        if (_perfil == 'recepcao') {
          return RecepcaoShell(currentUserId: user.uid);
        }

        // Demais perfis → MainShell completo
        return MainShell(
          userProfile:     _perfil!,
          currentUserId:   user.uid,
          currentUserName: _currentUserName,
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
