import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/config.dart';
import '../core/database/local_database.dart';
import '../core/services/device_service.dart';
import '../core/services/supabase_service.dart';
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
  final SupabaseService _supabaseService = SupabaseService();
  final DeviceService _deviceService = DeviceService();

  int totalParticipants = 0;
  int checkedIn = 0;
  int mealsServed = 0;
  int pendingSync = 0;
  bool isOnline = false;
  String deviceId = '';

  bool _isTestingConnection = false;
  ConnectionTestResult? _connectionResult;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final devId = await _deviceService.getDeviceId();
    if (mounted) setState(() => deviceId = devId);
    await _loadStats();
    await _testSupabase();
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

  Future<void> _testSupabase() async {
    setState(() => _isTestingConnection = true);
    final result = await _supabaseService.testConnection();
    if (!mounted) return;
    setState(() {
      _connectionResult = result;
      _isTestingConnection = false;
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
        title: const Text('Organizer Dashboard'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Sync Data',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Synchronizing with Supabase...'), duration: Duration(seconds: 1)),
              );
              await Provider.of<SyncService>(context, listen: false).syncData();
              await _loadStats();
              await _testSupabase();
            },
          ),
          IconButton(
            tooltip: 'Logout',
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
          await _testSupabase();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Device ID Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.ieeeDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.perm_device_information, color: Colors.white70),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Scanner Device',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Device ID: #$deviceId',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.success : AppColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Supabase Connection Diagnostic Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _connectionResult?.isConnected == true
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: _connectionResult?.isConnected == true
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Supabase Connection Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_isTestingConnection)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            tooltip: 'Test Connection',
                            onPressed: _testSupabase,
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      'Host: ${Config.supabaseUrl}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Key Configured: ${SupabaseService.isConfigured ? 'Yes (Active)' : 'No (Key Missing)'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SupabaseService.isConfigured ? AppColors.success : AppColors.error,
                      ),
                    ),
                    if (_connectionResult != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _connectionResult!.isConnected
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _connectionResult!.isConnected
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              size: 20,
                              color: _connectionResult!.isConnected
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _connectionResult!.isConnected
                                    ? 'Connected! Live ping: ${_connectionResult!.latencyMs}ms (${_connectionResult!.participantCount} records verified online)'
                                    : 'Connection Failed: ${_connectionResult!.errorMessage ?? 'Cannot reach host'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _connectionResult!.isConnected
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pending Offline Queue Indicator (if any)
            if (pendingSync > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$pendingSync scan(s) queued offline. They will be pushed automatically when connection stabilizes.',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Local Statistics Grid
            const Text(
              'Local Cache Counters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.4,
              children: [
                StatCard(
                  title: 'Checked In',
                  value: '$checkedIn / $totalParticipants',
                  icon: Icons.how_to_reg,
                  color: AppColors.ieeeBlue,
                ),
                StatCard(
                  title: 'Meals Redeemed',
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
