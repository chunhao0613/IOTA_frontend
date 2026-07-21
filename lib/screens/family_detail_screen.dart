import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FamilyDetailScreen extends StatefulWidget {
  final int familyId;
  final String familyName;
  final String myRole;
  final String currentUserId;

  const FamilyDetailScreen({
    super.key,
    required this.familyId,
    required this.familyName,
    required this.myRole,
    required this.currentUserId,
  });

  @override
  State<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends State<FamilyDetailScreen> with SingleTickerProviderStateMixin {
  static const String _getMembersUrl = 'http://localhost:8000/cgi-bin/get_family_members.py';
  static const String _sendInvitationUrl = 'http://localhost:8000/cgi-bin/send_invitation.py';
  static const String _updateRoleUrl = 'http://localhost:8000/cgi-bin/update_member_role.py';
  static const String _getDevicesUrl = 'http://localhost:8000/cgi-bin/list_devices.py';
  static const String _decommissionDeviceUrl = 'http://localhost:8000/cgi-bin/decommission_device.py';
  static const String _pairDeviceUrl = 'http://localhost:8000/cgi-bin/device_pair.py';

  List<dynamic> _members = [];
  bool _isLoadingMembers = false;
  List<dynamic> _devices = [];
  List<dynamic> _auditLogs = [];
  bool _isLoadingDevices = false;
  TabController? _tabController;

  // 邀請成員 Form Controllers
  final _inviteFormKey = GlobalKey<FormState>();
  final _inviteeIdController = TextEditingController();
  String _inviteRole = 'Guest';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _fetchDevices();
    _tabController = TabController(length: widget.myRole == 'Admin' ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _inviteeIdController.dispose();
    super.dispose();
  }

  // 取得成員清單
  Future<void> _fetchMembers() async {
    setState(() {
      _isLoadingMembers = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_getMembersUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'family_id': widget.familyId,
            'user_id': widget.currentUserId,
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['status'] == 'Success') {
        setState(() {
          _members = responseData['data']['members'] ?? [];
        });
      } else {
        _showToast(responseData['msg'] ?? '讀取成員失敗', Colors.red);
      }
    } catch (e) {
      _showToast('讀取成員連線失敗: $e', Colors.red);
    } finally {
      setState(() {
        _isLoadingMembers = false;
      });
    }
  }

  // 取得設備狀態清單
  Future<void> _fetchDevices() async {
    setState(() {
      _isLoadingDevices = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_getDevicesUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'family_id': widget.familyId,
            'user_id': widget.currentUserId,
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['status'] == 'Success') {
        setState(() {
          final data = responseData['data'] ?? {};
          _devices = data['devices'] ?? [];
          _auditLogs = data['logs'] ?? [];
        });
      } else {
        _showToast(responseData['msg'] ?? '讀取設備失敗', Colors.red);
      }
    } catch (e) {
      _showToast('讀取設備連線失敗: $e', Colors.red);
    } finally {
      setState(() {
        _isLoadingDevices = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _fetchMembers(),
      _fetchDevices(),
    ]);
  }

  // 設備除役與安全解綁
  Future<void> _decommissionDevice(String deviceId) async {
    final TextEditingController reasonController = TextEditingController(text: '安全考量，進行設備除役');
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('設備除役與安全解綁', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('確定要將此設備除役嗎？除役後設備安全金鑰將被撤銷，無法再次進行資料通訊。', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '除役原因',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定除役'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse(_decommissionDeviceUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'device_id': deviceId,
            'user_id': widget.currentUserId,
            'reason': reasonController.text,
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && responseData['status'] == 'Success') {
        _showToast('設備除役成功', Colors.green);
        _fetchDevices();
      } else {
        _showToast(responseData['msg'] ?? '設備除役失敗', Colors.red);
      }
    } catch (e) {
      _showToast('設備除役失敗: $e', Colors.red);
    }
  }

  // 模擬全新設備安全配對
  Future<void> _simulatePairing() async {
    final TextEditingController idController = TextEditingController(
      text: 'lock_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'
    );
    final TextEditingController nameController = TextEditingController(text: '大門智慧指紋鎖');
    String type = 'smart_lock';

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('模擬全新設備安全配對 (UC2.1)', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '設備識別碼 (Device ID)',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '設備名稱',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: '設備類型',
                      labelStyle: TextStyle(color: Colors.white54),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'smart_lock', child: Text('智慧電子鎖 (smart_lock)')),
                      DropdownMenuItem(value: 'sensor', child: Text('溫濕度感測器 (sensor)')),
                      DropdownMenuItem(value: 'camera', child: Text('智慧攝影機 (camera)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          type = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('啟動密鑰協商配對'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse(_pairDeviceUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'device_id': idController.text,
            'device_name': nameController.text,
            'device_type': type,
            'family_id': widget.familyId,
            'owner_user_id': widget.currentUserId,
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && responseData['status'] == 'Success') {
        final data = responseData['data'];
        final ledger = data['ledger'];
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Row(
              children: [
                Icon(Icons.verified_user, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('ECDH 安全金鑰協商完成', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  Text('設備 ID: ${data['device_id']}', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('協商狀態: ${data['pairing_status']}', style: const TextStyle(color: Colors.greenAccent)),
                  const SizedBox(height: 8),
                  const Text('金鑰派生 (HKDF-SHA256):', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  Text('Session Key Hash: \n${data['session_key_hash']}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  const Text('區塊鏈稽核鏈日誌上鏈完成:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  Text('Command ID: \n${ledger['command_id']}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                  Text('Current Hash: \n${ledger['current_hash']}', style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('確定'),
              ),
            ],
          ),
        );
        _fetchDevices();
      } else {
        _showToast(responseData['msg'] ?? '配對失敗', Colors.red);
      }
    } catch (e) {
      _showToast('連線配對失敗: $e', Colors.red);
    }
  }

  // 發送加入邀請
  Future<void> _sendInvitation() async {
    if (!_inviteFormKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
    );

    try {
      final response = await http.post(
        Uri.parse(_sendInvitationUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'family_id': widget.familyId,
            'admin_uid': widget.currentUserId,
            'invitee_uid': _inviteeIdController.text.trim(),
            'role': _inviteRole,
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      Navigator.of(context).pop(); // 關閉 Loading

      if (response.statusCode == 201 && responseData['status'] == 'Success') {
        _showToast(responseData['msg'] ?? '邀請已發送！', Colors.green);
        _inviteeIdController.clear();
        setState(() {
          _inviteRole = 'Guest';
        });
      } else {
        _showToast(responseData['msg'] ?? '發送邀請失敗', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 關閉 Loading
      _showToast('連線失敗: $e', Colors.red);
    }
  }

  // 修改成員權限 (更新角色與限制條件)
  Future<void> _updateMemberRole({
    required String targetUid,
    required String targetRole,
    String? startTime,
    String? endTime,
    int? maxUses,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
    );

    try {
      final response = await http.post(
        Uri.parse(_updateRoleUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'family_id': widget.familyId,
            'admin_uid': widget.currentUserId,
            'target_uid': targetUid,
            'target_role': targetRole,
            'start_time': startTime,
            'end_time': endTime,
            'max_uses': maxUses,
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      Navigator.of(context).pop(); // 關閉 Loading

      if (response.statusCode == 200 && (responseData['status'] == 'Success' || responseData['status'] == 'Warning')) {
        _showToast(responseData['msg'] ?? '權限已更新！', Colors.green);
        _fetchMembers(); // 重新整理
      } else {
        _showToast(responseData['msg'] ?? '更新失敗', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 關閉 Loading
      _showToast('連線失敗: $e', Colors.red);
    }
  }

  // 彈出編輯角色與時效限制對話框
  void _showEditRoleDialog(Map<String, dynamic> member) {
    String selectedRole = member['role'] ?? 'Guest';
    bool isTempAccess = member['start_time'] != null || member['end_time'] != null;
    bool hasUsesLimit = member['max_uses'] != null;

    DateTime? startDate = member['start_time'] != null ? DateTime.tryParse(member['start_time']) : null;
    DateTime? endDate = member['end_time'] != null ? DateTime.tryParse(member['end_time']) : null;
    final maxUsesController = TextEditingController(text: member['max_uses']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // 挑選日期時間小工具
            Future<DateTime?> pickDateTime(DateTime? initial) async {
              final date = await showDatePicker(
                context: context,
                initialDate: initial ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (date == null) return null;

              if (!context.mounted) return null;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
              );
              if (time == null) return null;

              return DateTime(date.year, date.month, date.day, time.hour, time.minute);
            }

            String formatDateTime(DateTime? dt) {
              if (dt == null) return '未設定';
              return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Text('編輯 ${member['username']} 的權限', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 選擇角色
                    const Text('設定權限角色', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          items: ['Admin', 'Member', 'Guest', 'Technician', 'SP', 'Revoked']
                              .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() {
                                selectedRole = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 臨時權限切換
                    Row(
                      children: [
                        Checkbox(
                          value: isTempAccess,
                          activeColor: const Color(0xFF8B5CF6),
                          onChanged: (val) {
                            setStateDialog(() {
                              isTempAccess = val ?? false;
                              if (isTempAccess) {
                                startDate ??= DateTime.now();
                                endDate ??= DateTime.now().add(const Duration(days: 1));
                              }
                            });
                          },
                        ),
                        const Text('啟用臨時權限時間限制', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),

                    if (isTempAccess) ...[
                      const SizedBox(height: 8),
                      // 開始時間
                      GestureDetector(
                        onTap: () async {
                          final picked = await pickDateTime(startDate);
                          if (picked != null) {
                            setStateDialog(() {
                              startDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('開始時間: ', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                              Text(formatDateTime(startDate), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 結束時間
                      GestureDetector(
                        onTap: () async {
                          final picked = await pickDateTime(endDate);
                          if (picked != null) {
                            setStateDialog(() {
                              endDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('結束時間: ', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                              Text(formatDateTime(endDate), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 使用次數限制
                    Row(
                      children: [
                        Checkbox(
                          value: hasUsesLimit,
                          activeColor: const Color(0xFF8B5CF6),
                          onChanged: (val) {
                            setStateDialog(() {
                              hasUsesLimit = val ?? false;
                            });
                          },
                        ),
                        const Text('啟用操作次數限制', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),

                    if (hasUsesLimit) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: maxUsesController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '請輸入最大允許操作次數',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消', style: TextStyle(color: Colors.white38)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    
                    // 解析參數
                    String? startStr = isTempAccess ? formatDateTime(startDate) : null;
                    String? endStr = isTempAccess ? formatDateTime(endDate) : null;
                    int? usesLimit = hasUsesLimit ? int.tryParse(maxUsesController.text) : null;

                    _updateMemberRole(
                      targetUid: member['user_id'],
                      targetRole: selectedRole,
                      startTime: startStr,
                      endTime: endStr,
                      maxUses: usesLimit,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('更新權限', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showToast(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.myRole == 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(widget.familyName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.6),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: _tabController != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF8B5CF6),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: isAdmin
                    ? const [
                        Tab(text: '成員清單', icon: Icon(Icons.people_outline)),
                        Tab(text: '設備狀態', icon: Icon(Icons.router_outlined)),
                        Tab(text: '發送邀請', icon: Icon(Icons.person_add_alt_1_outlined)),
                      ]
                    : const [
                        Tab(text: '成員清單', icon: Icon(Icons.people_outline)),
                        Tab(text: '設備狀態', icon: Icon(Icons.router_outlined)),
                      ],
              )
            : null,
      ),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.08),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // Main body
          _tabController != null
              ? TabBarView(
                  controller: _tabController,
                  children: isAdmin
                      ? [
                          _buildMembersTab(),
                          _buildDevicesTab(),
                          _buildInviteTab(),
                        ]
                      : [
                          _buildMembersTab(),
                          _buildDevicesTab(),
                        ],
                )
              : _buildMembersTab(),
        ],
      ),
    );
  }

  // TAB A: 成員清單
  Widget _buildMembersTab() {
    if (_isLoadingMembers && _members.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: const Color(0xFF8B5CF6),
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          final String role = member['role'] ?? 'Member';
          final String userId = member['user_id'] ?? '';
          final bool isSelf = userId == widget.currentUserId;
          final bool isRevoked = role == 'Revoked';

          return Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isRevoked ? Colors.red.withOpacity(0.15) : Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Member Avatar Circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isRevoked ? Colors.red.withOpacity(0.1) : const Color(0xFF8B5CF6).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          member['username'].toString().substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isRevoked ? Colors.red : const Color(0xFFC084FC),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name and role
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                member['username'] ?? '未知用戶',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('我', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                ),
                              ]
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: $userId',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRevoked
                            ? Colors.red.withOpacity(0.15)
                            : (role == 'Admin' ? const Color(0xFF8B5CF6).withOpacity(0.2) : Colors.white.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: isRevoked
                              ? Colors.redAccent
                              : (role == 'Admin' ? const Color(0xFFC084FC) : Colors.white70),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                // 顯示限制資訊 (如果有的話)
                if (member['start_time'] != null || member['end_time'] != null || member['max_uses'] != null) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 6),
                  if (member['start_time'] != null || member['end_time'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '時效限度: ${member['start_time'] ?? 'N/A'} 至 ${member['end_time'] ?? 'N/A'}',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (member['max_uses'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Icon(Icons.numbers, size: 14, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(width: 6),
                          Text(
                            '可用次數限制: 最大 ${member['max_uses']} 次',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],

                // 屋主專屬操作按鈕 (無法操作自己)
                if (widget.myRole == 'Admin' && !isSelf) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 編輯權限按鈕
                      TextButton.icon(
                        onPressed: () => _showEditRoleDialog(member),
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF818CF8)),
                        label: const Text('編輯權限', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      // 撤銷權限按鈕
                      if (!isRevoked)
                        TextButton.icon(
                          onPressed: () {
                            // 確認撤銷
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('撤銷成員權限？', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: Text('確定要直接撤銷成員 ${member['username']} 的所有權限嗎？該動作將立即同步至地端閘道器。', style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消', style: TextStyle(color: Colors.white38))),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      _updateMemberRole(targetUid: userId, targetRole: 'Revoked');
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                    child: const Text('撤銷權限', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.block_flipped, size: 16, color: Color(0xFFEF4444)),
                          label: const Text('撤銷權限', style: TextStyle(color: Color(0xFFF87171), fontSize: 13)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // TAB: 設備狀態清單
  Widget _buildDevicesTab() {
    if (_isLoadingDevices && _devices.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    final List<Widget> items = [];

    // 1. 如果是 Admin，在最上方提供模擬配對按鈕
    if (widget.myRole == 'Admin') {
      items.add(
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF6366F1).withOpacity(0.1), const Color(0xFF8B5CF6).withOpacity(0.1)]
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
          ),
          child: ListTile(
            leading: const Icon(Icons.add_to_photos_rounded, color: Color(0xFF818CF8), size: 28),
            title: const Text('智慧設備配對與密鑰協商模擬器 (UC2.1)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('點擊以模擬 ESP32 安全配對上鏈流程', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
            onTap: _simulatePairing,
          ),
        ),
      );
    }

    // 2. 智慧設備列表標頭
    items.add(_buildSectionHeader('智慧設備清單', Icons.router_outlined, const Color(0xFF8B5CF6)));

    // 3. 設備列表內容
    if (_devices.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.router_outlined, size: 48, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
              Text('目前無已連接之智慧設備', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
            ],
          ),
        ),
      );
    } else {
      for (var device in _devices) {
        final String deviceName = device['device_name'] ?? '未命名設備';
        final String deviceId = device['device_id'] ?? 'N/A';
        final String deviceType = device['device_type'] ?? 'Other';
        final String status = device['status'] ?? 'offline';
        final String gatewayId = device['gateway_id'] ?? 'N/A';
        final String? lastUpdate = device['last_update'];

        IconData deviceIcon = Icons.devices_other_rounded;
        Color typeColor = const Color(0xFF8B5CF6);
        if (deviceType.toLowerCase().contains('lock')) {
          deviceIcon = Icons.fingerprint_rounded;
          typeColor = const Color(0xFFF59E0B);
        } else if (deviceType.toLowerCase().contains('temp') || deviceType.toLowerCase().contains('sensor')) {
          deviceIcon = Icons.thermostat_rounded;
          typeColor = const Color(0xFF10B981);
        } else if (deviceType.toLowerCase().contains('camera') || deviceType.toLowerCase().contains('cctv')) {
          deviceIcon = Icons.videocam_rounded;
          typeColor = const Color(0xFF3B82F6);
        } else if (deviceType.toLowerCase().contains('gateway')) {
          deviceIcon = Icons.router_rounded;
          typeColor = const Color(0xFFEC4899);
        }

        final bool isRevoked = status.toLowerCase() == 'revoked';
        final bool isOnline = !isRevoked && (status.toLowerCase() == 'active' || status.toLowerCase() == 'online');

        items.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRevoked
                    ? Colors.red.withOpacity(0.2)
                    : (isOnline ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(deviceIcon, color: typeColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // 狀態標籤
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRevoked 
                            ? Colors.red.withOpacity(0.2) 
                            : (isOnline ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRevoked ? 'REVOKED (已除役)' : (isOnline ? 'ON (啟用)' : 'OFF'),
                        style: TextStyle(
                          color: isRevoked 
                              ? Colors.redAccent 
                              : (isOnline ? Colors.greenAccent : Colors.amberAccent),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.router_outlined, size: 14, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(width: 6),
                        Text(
                          '對接閘道: ',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                      ],
                    ),
                    // Admin 且未除役才顯示除役按鈕
                    if (widget.myRole == 'Admin' && !isRevoked)
                      ElevatedButton.icon(
                        onPressed: () => _decommissionDevice(deviceId),
                        icon: const Icon(Icons.gavel_rounded, size: 12, color: Colors.white),
                        label: const Text('設備除役', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      )
                    else if (lastUpdate != null)
                      Text(
                        '更新: ',
                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    // 4. 區塊鏈上鏈安全日誌標頭
    items.add(const SizedBox(height: 16));
    items.add(_buildSectionHeader('區塊鏈安全稽核日誌 (Blockchain Logs)', Icons.gavel_rounded, Colors.greenAccent));

    // 5. 稽核日誌內容
    if (_auditLogs.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              '尚無設備配對上鏈之稽核紀錄',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
            ),
          ),
        ),
      );
    } else {
      for (var log in _auditLogs) {
        items.add(_buildAuditLogCard(log));
      }
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: const Color(0xFF8B5CF6),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: items,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogCard(dynamic log) {
    final String cmdId = log['command_id'] ?? 'N/A';
    final String action = log['action'] ?? 'N/A';
    final String timestampStr = log['timestamp'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(int.parse(log['timestamp'].toString()) * 1000).toString().substring(0, 19)
        : 'N/A';
    final String curHash = log['current_hash'] ?? 'N/A';
    final String prevHash = log['prev_hash'] ?? 'N/A';
    final String deviceId = log['device_id'] ?? 'N/A';
    final String operator = log['user_id'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    action,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                timestampStr,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('操作者:  | 目標設備: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),
          Text('Block Hash: ' + (curHash.length > 16 ? curHash.substring(0, 16) : curHash) + '...', style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace')),
          Text('Prev Hash:  ' + (prevHash.length > 16 ? prevHash.substring(0, 16) : prevHash) + '...', style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  // TAB B: 發送邀請
  Widget _buildInviteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        color: const Color(0xFF1E293B).withOpacity(0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _inviteFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF8B5CF6), size: 28),
                    SizedBox(width: 10),
                    Text(
                      '邀請新成員加入家庭',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '輸入您想邀請的使用者帳號 (user_id)，並指定其預設扮演的身分組。對方將會收到系統通知，於同意後正式加入您的家庭。',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 28),

                // 帳號 ID 輸入欄位
                const Text('受邀者帳號 ID', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _inviteeIdController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: const Color(0xFF8B5CF6),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '請輸入受邀者的帳號 ID';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '請輸入例如：test_user_99',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                    prefixIcon: Icon(Icons.badge_outlined, color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.03),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 身分角色選擇
                const Text('預設賦予角色身分', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _inviteRole,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      isExpanded: true,
                      items: ['Member', 'Guest', 'Technician', 'SP']
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _inviteRole = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // 送出按鈕
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _sendInvitation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('發送加入邀請', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
