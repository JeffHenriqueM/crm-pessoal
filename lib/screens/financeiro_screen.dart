import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/aba_financeiro.dart';

class FinanceiroScreen extends StatefulWidget {
  final String userProfile;
  const FinanceiroScreen({super.key, this.userProfile = ''});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  final AuthService _authService = AuthService();

  String _userProfile = '';

  @override
  void initState() {
    super.initState();
    if (widget.userProfile.isNotEmpty) {
      _userProfile = widget.userProfile;
    } else {
      _authService.getCurrentUserProfile().then((perfil) {
        if (!mounted) return;
        setState(() => _userProfile = perfil);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Financeiro'),
      ),
      // AbaFinanceiro carrega suas próprias baixas via FirestoreService
      // internamente — não depende de clientes e não precisa de StreamBuilder
      // aqui, o que eliminava uma query desnecessária que causava crash.
      body: AbaFinanceiro(
        clientes: const [],
        userProfile: _userProfile,
      ),
    );
  }
}
