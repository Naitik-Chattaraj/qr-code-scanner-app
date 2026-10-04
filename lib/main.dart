import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/services/supabase_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Check auth
  final authService = AuthService();
  final isAuth = await authService.isAuthenticated();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => SyncService()..initialize(), dispose: (_, service) => service.dispose()),
      ],
      child: MyApp(initialAuth: isAuth),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool initialAuth;
  
  const MyApp({super.key, required this.initialAuth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AICSSYC Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00629B)),
        useMaterial3: true,
      ),
      home: initialAuth ? const HomeScreen() : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
