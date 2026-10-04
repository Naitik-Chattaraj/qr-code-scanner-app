import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/meal_sessions.dart';
import '../core/database/local_database.dart';
import '../core/models/participant.dart';
import '../core/services/device_service.dart';
import '../core/services/supabase_service.dart';
import '../core/services/sync_service.dart';
import '../core/services/auth_service.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';

const List<Map<String, String>> mealSessionDetails = [
  {'id': 'OCT_08_DINNER', 'label': 'Oct 8 — Dinner', 'day': 'Oct 8', 'meal': 'Dinner'},
  {'id': 'OCT_09_BREAKFAST', 'label': 'Oct 9 — Breakfast', 'day': 'Oct 9', 'meal': 'Breakfast'},
  {'id': 'OCT_09_LUNCH', 'label': 'Oct 9 — Lunch', 'day': 'Oct 9', 'meal': 'Lunch'},
  {'id': 'OCT_09_DINNER', 'label': 'Oct 9 — Dinner', 'day': 'Oct 9', 'meal': 'Dinner'},
  {'id': 'OCT_10_BREAKFAST', 'label': 'Oct 10 — Breakfast', 'day': 'Oct 10', 'meal': 'Breakfast'},
  {'id': 'OCT_10_LUNCH', 'label': 'Oct 10 — Lunch', 'day': 'Oct 10', 'meal': 'Lunch'},
  {'id': 'OCT_10_DINNER', 'label': 'Oct 10 — Dinner', 'day': 'Oct 10', 'meal': 'Dinner'},
  {'id': 'OCT_11_BREAKFAST', 'label': 'Oct 11 — Breakfast', 'day': 'Oct 11', 'meal': 'Breakfast'},
  {'id': 'OCT_11_LUNCH', 'label': 'Oct 11 — Lunch', 'day': 'Oct 11', 'meal': 'Lunch'},
];

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
  
  List<Map<String, dynamic>> sessionsBreakdown = [];
  List<Participant> allParticipants = [];
  Map<String, List<String>> participantRedemptions = {};
  
  String searchQuery = '';
  String statusFilter = 'ALL';
  bool _isLoading = true;
  String? _actionLoadingId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final devId = await _deviceService.getDeviceId();
    if (mounted) setState(() => deviceId = devId);
    await _loadStats();
    if (mounted) {
      Provider.of<SyncService>(context, listen: false).syncData().then((_) {
        if (mounted) _loadStats();
      });
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final syncService = Provider.of<SyncService>(context, listen: false);
    final tParticipants = await _localDb.getTotalParticipants();
    final tCheckedIn = await _localDb.getCheckedInCount();
    final tMeals = await _localDb.getMealsServedCount();
    final queue = await _localDb.getQueue();
    final online = await syncService.isOnline();
    
    final breakdownData = await _localDb.getMealSessionBreakdown();
    
    final pList = await _localDb.getAllParticipants();
    
    final db = await _localDb.database;
    final allReds = await db.query('meal_redemptions');
    Map<String, List<String>> pReds = {};
    for (var r in allReds) {
      final pid = r['participant_id'] as String;
      final session = r['meal_session'] as String;
      pReds.putIfAbsent(pid, () => []).add(session);
    }

    if (!mounted) return;
    setState(() {
      totalParticipants = tParticipants;
      checkedIn = tCheckedIn;
      mealsServed = tMeals;
      pendingSync = queue.length;
      isOnline = online;
      
      allParticipants = pList;
      participantRedemptions = pReds;
      
      sessionsBreakdown = mealSessionDetails.map((s) {
        final match = breakdownData.firstWhere(
          (b) => b['meal_session'] == s['id'], 
          orElse: () => {'count': 0}
        );
        final count = match['count'] as int;
        return {
          ...s,
          'count': count,
          'percentOfRegistered': checkedIn > 0 ? ((count / checkedIn) * 100).round() : 0,
        };
      }).toList();
      
      _isLoading = false;
    });
  }

  Future<void> _handleLogout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _manualCheckIn(Participant p) async {
    setState(() => _actionLoadingId = 'desk-${p.participantId}');
    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      final isOnline = await syncService.isOnline();
      
      if (isOnline) {
        await _supabaseService.registerAttendee(
          participantId: p.participantId,
          name: p.name,
          email: p.email,
          mobile: p.mobileNumber,
          organization: p.organization,
          eventId: p.eventId,
        );
      } else {
        await _localDb.addToQueue('register_attendee', {
          'p_id': p.participantId,
          'p_name': p.name,
          'p_email': p.email,
          'p_mobile': p.mobileNumber,
          'p_org': p.organization,
          'p_event_id': p.eventId,
        });
      }
      
      final updatedP = Participant(
        participantId: p.participantId,
        eventId: p.eventId,
        name: p.name,
        email: p.email,
        mobileNumber: p.mobileNumber,
        organization: p.organization,
        isRegistered: true,
        registeredAt: p.registeredAt ?? DateTime.now().toUtc().toIso8601String(),
        scannedAt: DateTime.now().toUtc().toIso8601String(),
        scannedBy: 'dashboard-manual',
        dinnerStatus: p.dinnerStatus,
        dinnerScannedAt: p.dinnerScannedAt,
      );
      await _localDb.updateParticipant(updatedP);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully checked in ${p.name}!')),
        );
      }
      await _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoadingId = null);
      }
    }
  }

  void _showRedeemDialog(Participant p) {
    String selectedSession = MealSessions.sessions.first;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              backgroundColor: AppColors.neutral900,
              title: Text('Manual Meal Override\n${p.name}', style: const TextStyle(color: Colors.white, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${p.participantId}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  const Text('Select Meal Session:', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.neutral950,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.neutral800),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSession,
                        dropdownColor: AppColors.neutral900,
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: MealSessions.sessions.map((s) {
                          final isRedeemed = (participantRedemptions[p.participantId] ?? []).contains(s);
                          final label = mealSessionDetails.firstWhere((ms) => ms['id'] == s)['label'];
                          return DropdownMenuItem(
                            value: s,
                            child: Text('$label ${isRedeemed ? "(Redeemed)" : ""}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setStateSB(() => selectedSession = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _manualRedeemMeal(p, selectedSession);
                  },
                  child: const Text('Confirm Redemption', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _manualRedeemMeal(Participant p, String session) async {
    setState(() => _actionLoadingId = 'meal-${p.participantId}');
    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      final isOnline = await syncService.isOnline();
      
      if (isOnline) {
        await _supabaseService.verifyMealAccess(participantId: p.participantId, sessionName: session);
      } else {
        await _localDb.addToQueue('verify_meal_access', {
          'p_id': p.participantId,
          'p_session': session,
        });
      }
      
      await _localDb.addMealRedemption(
        DateTime.now().millisecondsSinceEpoch.toString(),
        p.participantId,
        session,
        'dashboard-manual',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meal $session granted for ${p.name}!')),
        );
      }
      await _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionLoadingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredParticipants = allParticipants.where((p) {
      final q = searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          p.mobileNumber.toLowerCase().contains(q) ||
          p.participantId.toLowerCase().contains(q) ||
          p.organization.toLowerCase().contains(q);
      
      if (!matchesSearch) return false;
      
      if (statusFilter == 'REGISTERED') return p.isRegistered;
      if (statusFilter == 'NOT_REGISTERED') return !p.isRegistered;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.neutral950,
      appBar: AppBar(
        title: const Text('Organizer Dashboard'),
        backgroundColor: AppColors.neutral950,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<SyncService>(context, listen: false).syncData();
          await _loadStats();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Device ID Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.neutral900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral800),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.ieeeBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.ieeeBlue.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.perm_device_information, color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assigned Scanner Device',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                      color: isOnline ? AppColors.success.withValues(alpha: 0.2) : AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOnline ? AppColors.success.withValues(alpha: 0.4) : AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.success : AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline ? AppColors.success : AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

            // Section 2: Real-Time Counters & Aggregate Metrics
            const Text(
              'Aggregate Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
                  title: 'Total Tickets',
                  value: totalParticipants.toString(),
                  icon: Icons.people,
                  color: Colors.purple,
                ),
                StatCard(
                  title: 'Desk Check-Ins',
                  value: '$checkedIn (${totalParticipants > 0 ? ((checkedIn / totalParticipants) * 100).round() : 0}%)',
                  icon: Icons.check_circle,
                  color: AppColors.ieeeBlue,
                ),
                StatCard(
                  title: 'Total Meals',
                  value: mealsServed.toString(),
                  icon: Icons.restaurant,
                  color: AppColors.warning,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Section 3: Live Breakdown of Meals
            const Text(
              'Multi-Day Meal Breakdown (Oct 8 - 11)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: sessionsBreakdown.length,
              itemBuilder: (context, index) {
                final s = sessionsBreakdown[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.neutral900.withValues(alpha: 0.6),
                    border: Border.all(color: AppColors.neutral800),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(s['day'], style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          Text('${s['count']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(s['meal'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Turnout', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          Text('${s['percentOfRegistered']}%', style: const TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: (s['percentOfRegistered'] as num) / 100,
                        backgroundColor: AppColors.neutral800,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      )
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Section 4: Manual Search Fallback
            const Text(
              'Manual Search & Guest Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, email, phone, ID...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.neutral900,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${allParticipants.length})'),
                    selected: statusFilter == 'ALL',
                    onSelected: (val) => setState(() => statusFilter = 'ALL'),
                    selectedColor: AppColors.neutral800,
                    backgroundColor: AppColors.neutral900,
                    labelStyle: TextStyle(color: statusFilter == 'ALL' ? Colors.white : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Checked-In ($checkedIn)'),
                    selected: statusFilter == 'REGISTERED',
                    onSelected: (val) => setState(() => statusFilter = 'REGISTERED'),
                    selectedColor: AppColors.ieeeBlue.withValues(alpha: 0.3),
                    backgroundColor: AppColors.neutral900,
                    labelStyle: TextStyle(color: statusFilter == 'REGISTERED' ? AppColors.info : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Pending (${totalParticipants - checkedIn})'),
                    selected: statusFilter == 'NOT_REGISTERED',
                    onSelected: (val) => setState(() => statusFilter = 'NOT_REGISTERED'),
                    selectedColor: AppColors.error.withValues(alpha: 0.3),
                    backgroundColor: AppColors.neutral900,
                    labelStyle: TextStyle(color: statusFilter == 'NOT_REGISTERED' ? AppColors.error : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (filteredParticipants.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No participants found.', style: TextStyle(color: AppColors.textSecondary))))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredParticipants.length > 50 ? 50 : filteredParticipants.length, // Limit to 50 for perf
                separatorBuilder: (context, index) => const Divider(color: AppColors.neutral800),
                itemBuilder: (context, index) {
                  final p = filteredParticipants[index];
                  final isActing = _actionLoadingId == 'desk-${p.participantId}' || _actionLoadingId == 'meal-${p.participantId}';
                  final mealsRedeemedCount = participantRedemptions[p.participantId]?.length ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('ID: ${p.participantId} • ${p.organization}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              if (p.mobileNumber.isNotEmpty)
                                Text('📞 ${p.mobileNumber}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (p.isRegistered)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.ieeeBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Checked In', style: TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.neutral800, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Pending', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                    child: Text('$mealsRedeemedCount / 9 meals', style: const TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: p.isRegistered ? AppColors.neutral800 : AppColors.ieeeBlue,
                                foregroundColor: p.isRegistered ? AppColors.textSecondary : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                minimumSize: const Size(90, 30),
                              ),
                              onPressed: p.isRegistered || isActing ? null : () => _manualCheckIn(p),
                              child: Text(p.isRegistered ? 'Registered' : 'Check In Desk', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !p.isRegistered ? AppColors.neutral800 : AppColors.warning,
                                foregroundColor: !p.isRegistered ? AppColors.textSecondary : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                minimumSize: const Size(90, 30),
                              ),
                              onPressed: !p.isRegistered || isActing ? null : () => _showRedeemDialog(p),
                              child: const Text('Redeem Meal...', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
