import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/database/local_database.dart';
import '../core/services/sync_service.dart';
import '../core/services/auth_service.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocalDatabase _localDb = LocalDatabase.instance;
  int totalParticipants = 0;
  int checkedIn = 0;
  int mealsServed = 0;
  int pendingSync = 0;
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    final tParticipants = await _localDb.getTotalParticipants();
    final tCheckedIn = await _localDb.getCheckedInCount();
    final tMeals = await _localDb.getMealsServedCount();
    final queue = await _localDb.getQueue();
    final online = await syncService.isOnline();

    if (!mounted) return;
    setState(() {
      totalParticipants = tParticipants;
      checkedIn = tCheckedIn;
      mealsServed = tMeals;
      pendingSync = queue.length;
      isOnline = online;
    });
  }

  Future<void> _handleLogout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<SyncService>(context, listen: false).syncData();
              _loadStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<SyncService>(context, listen: false).syncData();
          await _loadStats();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Network Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isOnline ? AppColors.success : AppColors.error),
              ),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    color: isOnline ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOnline ? 'Online - Live Sync Active' : 'Offline - Queuing Actions',
                    style: TextStyle(
                      color: isOnline ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (pendingSync > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingSync pending',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                StatCard(
                  title: 'Total Checked In',
                  value: '$checkedIn / $totalParticipants',
                  icon: Icons.people,
                  color: AppColors.ieeeBlue,
                ),
                StatCard(
                  title: 'Meals Served',
                  value: mealsServed.toString(),
                  icon: Icons.restaurant,
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
