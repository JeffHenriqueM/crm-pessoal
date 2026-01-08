// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'services/auth_service.dart';
import 'screens/lista_clientes_screen.dart';
import 'screens/tela_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM Pessoal',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.indigo,
        brightness: Brightness.dark,
        // Você pode customizar mais o tema escuro aqui
      ),
      themeMode: ThemeMode.system, // Usa o tema do sistema (claro ou escuro)
      home: const AuthWrapper(), // Nosso novo "porteiro",
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Se a conexão está ativa, esperando dados
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          // Se não há usuário logado, mostra a tela de login
          if (user == null) {
            return const TelaLoginScreen();
          }
          // Se há um usuário logado, mostra a tela principal
          return const ListaClientesScreen();
        }
        // Enquanto espera a conexão, mostra uma tela de carregamento
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
