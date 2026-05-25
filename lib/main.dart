import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/lista_clientes_screen.dart';
import 'screens/tela_login_screen.dart';
import 'screens/vendedor_home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
        title: 'Villamor CRM',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeController.instance.mode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// ── Auth wrapper com roteamento por perfil ────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  String? _perfil;
  bool _carregandoPerfil = false;

  /// Perfis que abrem na lista de leads (visão gerencial).
  static const _perfilsListaLeads = {'admin', 'pós-venda', 'financeiro'};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Aguardando conexão com Firebase Auth
        if (snapshot.connectionState != ConnectionState.active) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;

        // Não autenticado
        if (user == null) {
          // Limpa perfil em cache quando desloga
          if (_perfil != null) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => setState(() => _perfil = null));
          }
          return const TelaLoginScreen();
        }

        // Autenticado mas ainda carregando o perfil
        if (_perfil == null) {
          if (!_carregandoPerfil) {
            _carregandoPerfil = true;
            _authService.getCurrentUserProfile().then((perfil) {
              if (mounted) {
                setState(() {
                  _perfil = perfil;
                  _carregandoPerfil = false;
                });
              }
            });
          }
          return const _LoadingScreen();
        }

        // Roteamento por perfil
        if (_perfilsListaLeads.contains(_perfil)) {
          return const ListaClientesScreen();
        }
        return const VendedorHomeScreen();
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
