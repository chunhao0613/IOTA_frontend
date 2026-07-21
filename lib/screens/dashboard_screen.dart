import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'family_detail_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 後端 API 網址
  static const String _getFamiliesUrl = 'http://localhost:8000/cgi-bin/get_user_families.py';
  static const String _getInvitationsUrl = 'http://localhost:8000/cgi-bin/get_invitations.py';
  static const String _respondInvitationUrl = 'http://localhost:8000/cgi-bin/respond_invitation.py';

  List<dynamic> _families = [];
  List<dynamic> _invitations = [];
  bool _isLoadingFamilies = false;
  bool _isLoadingInvitations = false;
  int _activeTab = 0; // 0: 我的場域, 1: 邀請通知

  @override
  void initState() {
    super.initState();
    // 初始資料載入
    _families = widget.userData['families'] as List<dynamic>? ?? [];
    _fetchFamilies();
    _fetchInvitations();
  }

  // 取得最新家庭清單
  Future<void> _fetchFamilies() async {
    setState(() {
      _isLoadingFamilies = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_getFamiliesUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'user_id': widget.userData['user_id'],
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['status'] == 'Success') {
        setState(() {
          _families = responseData['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('取得家庭清單失敗: $e');
    } finally {
      setState(() {
        _isLoadingFamilies = false;
      });
    }
  }

  // 取得待處理邀請清單
  Future<void> _fetchInvitations() async {
    setState(() {
      _isLoadingInvitations = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_getInvitationsUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'user_id': widget.userData['user_id'],
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 && responseData['status'] == 'Success') {
        setState(() {
          _invitations = responseData['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('取得邀請清單失敗: $e');
    } finally {
      setState(() {
        _isLoadingInvitations = false;
      });
    }
  }

  // 回覆邀請 (Accept/Reject)
  Future<void> _respondToInvitation(int invitationId, String action) async {
    // 顯示載入進度條
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse(_respondInvitationUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode({
          'payload': {
            'invitation_id': invitationId,
            'user_id': widget.userData['user_id'],
            'action': action,
          }
        }),
      );

      final responseData = json.decode(utf8.decode(response.bodyBytes));
      if (!mounted) return;
      Navigator.of(context).pop(); // 關閉 Loading

      if (response.statusCode == 200 && responseData['status'] == 'Success') {
        _showToast(responseData['msg'] ?? '操作成功', Colors.green);
        // 重新整理資料
        _fetchFamilies();
        _fetchInvitations();
      } else {
        _showToast(responseData['msg'] ?? '操作失敗', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 關閉 Loading
      _showToast('連線失敗: $e', Colors.red);
    }
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

  // 登出
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('確定登出？', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('您需要重新輸入帳號與密碼才能存取主控台。', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('確定登出', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Stack(
        children: [
          // Background Glow Orbs
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withOpacity(0.08),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),

          // Main Screen
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Custom App Bar
                _buildHeader(),

                // Tab Switcher
                _buildTabSwitcher(),

                // Tab Content
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await _fetchFamilies();
                      await _fetchInvitations();
                    },
                    color: const Color(0xFF8B5CF6),
                    backgroundColor: const Color(0xFF1E293B),
                    child: _activeTab == 0 ? _buildFamiliesTab() : _buildInvitationsTab(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header Widget with Profile Info
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.userData['username'].toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '歡迎回來 👋',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userData['username'] ?? '使用者',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID: ${widget.userData['user_id']}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.userData['status'] ?? 'Active',
                        style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Logout Button
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 26),
            tooltip: '登出系統',
          ),
        ],
      ),
    );
  }

  // Tab Switcher Widget
  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabItem(0, '我的場域 / 家庭', Icons.home_work_outlined),
            ),
            Expanded(
              child: _buildTabItem(1, '邀請通知 (${_invitations.length})', Icons.mail_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.6),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: 我的場域
  Widget _buildFamiliesTab() {
    if (_isLoadingFamilies && _families.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    if (_families.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.home_outlined, size: 80, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 16),
                Text(
                  '目前沒有加入任何場域',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '請聯絡家庭管理員發送邀請給您。',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      itemCount: _families.length,
      itemBuilder: (context, index) {
        final fam = _families[index];
        final role = fam['user_role'] ?? 'Guest';
        final isAdmin = role == 'Admin';

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                // 點擊卡片，導向家庭成員與邀請細節頁面
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FamilyDetailScreen(
                      familyId: fam['family_id'] is int ? fam['family_id'] : int.parse(fam['family_id'].toString()),
                      familyName: fam['family_name'],
                      myRole: role,
                      currentUserId: widget.userData['user_id'],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    // Family Icon Block
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isAdmin ? const Color(0xFF8B5CF6).withOpacity(0.15) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAdmin ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.home_outlined,
                        color: isAdmin ? const Color(0xFFC084FC) : Colors.white70,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fam['family_name'] ?? '未命名家庭',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 14, color: isAdmin ? const Color(0xFF818CF8) : Colors.white38),
                              const SizedBox(width: 4),
                              Text(
                                '我的權限身分: ',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                              ),
                              Text(
                                role,
                                style: TextStyle(
                                  color: isAdmin ? const Color(0xFF818CF8) : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Arrow Icon
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.25),
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // TAB 2: 邀請通知
  Widget _buildInvitationsTab() {
    if (_isLoadingInvitations && _invitations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    if (_invitations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Center(
            child: Column(
              children: [
                Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 16),
                Text(
                  '目前沒有任何待確認的邀請',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      itemCount: _invitations.length,
      itemBuilder: (context, index) {
        final inv = _invitations[index];
        final invId = inv['invitation_id'] is int ? inv['invitation_id'] : int.parse(inv['invitation_id'].toString());

        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mail_rounded, color: Color(0xFF818CF8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '加入家庭邀請',
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inv['family_name'] ?? '未命名家庭',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, color: Colors.white70),
                            children: [
                              const TextSpan(text: '邀請人: '),
                              TextSpan(
                                text: '${inv['inviter_name']} (${inv['inviter_uid']})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 14, color: Colors.white70),
                            children: [
                              const TextSpan(text: '賦予角色: '),
                              TextSpan(
                                text: inv['role'] ?? 'Guest',
                                style: const TextStyle(color: Color(0xFFF472B6), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Action Buttons Row
              Row(
                children: [
                  // Reject Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respondToInvitation(invId, 'Reject'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('拒絕邀請', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Accept Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respondToInvitation(invId, 'Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('接受並加入', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
