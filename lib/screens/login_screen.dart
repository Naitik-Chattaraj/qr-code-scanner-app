import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passcodeController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorText;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final success = await _authService.login(_passcodeController.text);
    
    if (success) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _errorText = 'Invalid passcode';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/ieee-cs-logo.png', height: 100),
              const SizedBox(height: 32),
              const Text(
                'AICSSYC 2026',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ieeeDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Staff Scanner Access',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _passcodeController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Team Passcode',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ieeeBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Access Scanner', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
