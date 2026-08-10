import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';

class GroupeScreen extends StatefulWidget {
  final int membreId;

  const GroupeScreen({super.key, required this.membreId});

  @override
  State<GroupeScreen> createState() => _GroupeScreenState();
}

class _GroupeScreenState extends State<GroupeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _donneesUser;
  final Color primaryColor = const Color(0xFF1A529B);

  @override
  void initState() {
    super.initState();
    _chargerInfosGroupe();
  }

  Future<void> _chargerInfosGroupe() async {
    try {
      final data = await ApiService.getPortefeuille(widget.membreId);
      if (mounted) {
        setState(() {
          _donneesUser = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Erreur groupe: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    int groupeId = _donneesUser?['groupe_id'] ?? 0;
    String presence = _donneesUser?['status_presence'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: Text('group_screen_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header du groupe ---
                  Card(
                    color: primaryColor.withValues(alpha: 0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.gite, size: 40, color: primaryColor),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${'solidarity_group'.tr()} #$groupeId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${'presence_status'.tr()} : $presence', style: TextStyle(color: Colors.grey[700])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('group_rules'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildRuleTile('rule_1'.tr()),
                  _buildRuleTile('rule_2'.tr()),
                  _buildRuleTile('rule_3'.tr()),
                ],
              ),
            ),
    );
  }

  Widget _buildRuleTile(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: primaryColor, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}