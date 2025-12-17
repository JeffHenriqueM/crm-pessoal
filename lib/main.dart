// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // NECESSÁRIO
import 'firebase_options.dart'; // CRIADO PELO 'flutterfire configure'
import 'screens/lista_clientes_screen.dart'; // NOVO IMPORT


void main() async { // O 'async' é obrigatório!
  // 1. Inicialização obrigatória do Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicialização do Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
// ... (O resto do seu código MyApp)
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM Pessoal',
      // 1. ATIVAR O DARK MODE
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system, // Escolhe entre light/dark baseado na configuração do Mac/SO
      debugShowCheckedModeBanner: false,
      home: const ListaClientesScreen(),
    );
  }
}