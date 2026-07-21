import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // 後端 API 伺服器網址
  // 提示：若使用 Android 模擬器，請將 localhost 改為 10.0.2.2 才能成功連回您本機電腦
  static const String _apiUrl = 'http://localhost:8000/cgi-bin/register.py';

  // Controllers
  final _nameController = TextEditingController();
  final _userIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus Nodes for active styling
  final _nameFocusNode = FocusNode();
  final _userIdFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  // State flags
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // Animation controller for entry transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Password strength state
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    
    // Set up entry animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    // Listeners for focus nodes to trigger rebuilds for styling
    _nameFocusNode.addListener(() => setState(() {}));
    _userIdFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _phoneFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
    _confirmPasswordFocusNode.addListener(() => setState(() {}));

    // Password strength listener
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    
    _nameFocusNode.dispose();
    _userIdFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    
    _animationController.dispose();
    super.dispose();
  }

  // Live password strength calculation
  void _checkPasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    double strength = 0.0;
    
    // Length check
    if (password.length >= 6) strength += 0.3;
    if (password.length >= 10) strength += 0.1;
    
    // Contains uppercase
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    
    // Contains lowercase
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    
    // Contains digits
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.15;
    
    // Contains special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.15;

    setState(() {
      _passwordStrength = strength;
      if (strength <= 0.3) {
        _passwordStrengthText = '弱 (Weak)';
        _passwordStrengthColor = const Color(0xFFEF4444); // Red
      } else if (strength <= 0.7) {
        _passwordStrengthText = '中 (Medium)';
        _passwordStrengthColor = const Color(0xFFF59E0B); // Orange
      } else {
        _passwordStrengthText = '強 (Strong)';
        _passwordStrengthColor = const Color(0xFF10B981); // Green
      }
    });
  }

  // Helper to show error snack bar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444), // Red
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  // Handle Form Submission
  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('請先同意使用者條款與隱私權政策'),
            ],
          ),
          backgroundColor: Color(0xFFEC4899),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    // Trigger loading spinner
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: json.encode({
          'payload': {
            'user_id': _userIdController.text.trim(),
            'username': _nameController.text.trim(),
            'password': _passwordController.text,
            'email': _emailController.text.trim(),
            'phone_number': _phoneController.text.trim(),
          }
        }),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final responseData = json.decode(utf8.decode(response.bodyBytes));

        if ((response.statusCode == 200 || response.statusCode == 201) && responseData['status'] == 'Success') {
          // Show success alert
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: const Color(0xFF1E1B4B),
              title: const Column(
                children: [
                  Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 60),
                  SizedBox(height: 16),
                  Text(
                    '註冊成功！',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(
                '歡迎，${_nameController.text}！您的帳號已成功建立。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('開始體驗', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          // Show error message returned from the Python API
          final String errorMsg = responseData['msg'] ?? '註冊失敗，請重試。';
          final String errorDetail = responseData['detail'] != null ? '\n詳細原因：${responseData['detail']}' : '';
          _showErrorSnackBar('$errorMsg$errorDetail');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('連線至伺服器失敗，請確認 API 伺服器已開啟！\n錯誤原因：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Stack(
        children: [
          // Background Gradient Circles for Visual Flare
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withOpacity(0.12),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          
          // Main Body Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Painter Abstract Glowing Logo
                          const SizedBox(height: 10),
                          Center(
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: CustomPaint(
                                painter: AppLogoPainter(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Welcome Title & Subtitle
                          const Text(
                            '建立新帳號',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '與我們一起展開您的精彩旅程',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 36),

                           // Text Fields Column
                          // === 群組 A: 個人資料 (姓名、電子郵件、手機號碼) ===
                          _buildTextField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            labelText: '姓名',
                            hintText: '您的真實姓名',
                            prefixIcon: Icons.person_outline,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '請輸入姓名';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            labelText: '電子郵件',
                            hintText: 'name@example.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請輸入電子郵件';
                              }
                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value)) {
                                return '請輸入有效的電子郵件格式';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            labelText: '手機號碼',
                            hintText: '0912345678',
                            prefixIcon: Icons.phone_android_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請輸入手機號碼';
                              }
                              if (value.length < 10) {
                                return '請輸入完整的手機號碼';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32), // 稍微拉開群組間距，增強層次感

                          // === 群組 B: 帳號資訊 (帳號名稱、密碼、確認密碼) ===
                          _buildTextField(
                            controller: _userIdController,
                            focusNode: _userIdFocusNode,
                            labelText: '帳號名稱 / ID',
                            hintText: '例如：test_user_001',
                            prefixIcon: Icons.badge_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                  return '請輸入帳號名稱';
                              }
                              if (value.trim().length < 4) {
                                  return '帳號長度至少需要 4 個字元';
                              }
                              final accountRegex = RegExp(r'^(?=.*[a-zA-Z])[a-zA-Z0-9]+$');
                              if (!accountRegex.hasMatch(value.trim())) {
                                  return '帳號必須為全英文或英文搭配數字（不可含中文/符號/純數字）';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            labelText: '密碼',
                            hintText: '至少 6 個字元',
                            prefixIcon: Icons.lock_outlined,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請輸入密碼';
                              }
                              if (value.length < 6) {
                                return '密碼長度至少需要 6 個字元';
                              }
                              return null;
                            },
                          ),
                          
                          // Password Strength Indicator Bar
                          if (_passwordController.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '密碼強度:',
                                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                                      ),
                                      Text(
                                        _passwordStrengthText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _passwordStrengthColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _passwordStrength,
                                      backgroundColor: Colors.white.withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocusNode,
                            labelText: '確認密碼',
                            hintText: '再次輸入密碼',
                            prefixIcon: Icons.lock_reset_outlined,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '請再次輸入密碼';
                              }
                              if (value != _passwordController.text) {
                                return '密碼與確認密碼不相符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Terms and Conditions Custom Checkbox
                          _buildTermsCheckbox(),
                          const SizedBox(height: 30),

                          // Gradient Submit Button
                          _buildSubmitButton(),
                          const SizedBox(height: 24),

                          // Social Sign-up Separator
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '其他註冊方式',
                                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withOpacity(0.15), thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Social buttons row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton(
                                icon: Icons.g_mobiledata,
                                label: 'Google',
                                iconColor: const Color(0xFFEA4335),
                                onPressed: () {
                                  // Integrate Google Sign-in
                                },
                              ),
                              const SizedBox(width: 16),
                              _buildSocialButton(
                                icon: Icons.apple,
                                label: 'Apple',
                                iconColor: Colors.white,
                                onPressed: () {
                                  // Integrate Apple Sign-in
                                },
                              ),
                              const SizedBox(width: 16),
                              _buildSocialButton(
                                icon: Icons.code,
                                label: 'GitHub',
                                iconColor: Colors.cyan,
                                onPressed: () {
                                  // Integrate GitHub Sign-in
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 36),

                          // Already have account? Login link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '已經有帳號了嗎？',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '立即登入',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1), // Indigo primary
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Refactored custom helper method for TextFields to reduce duplication and keep styles modular
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final isFocused = focusNode.hasFocus;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.6), // Translucent slate
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: const Color(0xFF6366F1),
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: isFocused ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.4),
            fontSize: 14,
            fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
          ),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          prefixIcon: Icon(
            prefixIcon,
            color: isFocused ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.4),
            size: 22,
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.transparent,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
        ),
      ),
    );
  }

  // Terms and Conditions checkbox builder
  Widget _buildTermsCheckbox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Theme(
            data: ThemeData(
              unselectedWidgetColor: Colors.white.withOpacity(0.4),
            ),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agreeToTerms,
                activeColor: const Color(0xFF6366F1),
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _agreeToTerms = !_agreeToTerms;
                });
              },
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
                  children: [
                    const TextSpan(text: '我已閱讀並同意 '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => _showTermsDialog('服務條款', '這是平台的服務條款內容...\n\n1. 帳號安全：您應對您帳號下的所有活動負責。\n2. 使用限制：不得傳播違法、侵權或垃圾訊息。\n3. 免責聲明：系統將竭力維持穩定運作，但不對不可抗力導致的服務中斷負責。'),
                        child: const Text(
                          '服務條款',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: ' 與 '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => _showTermsDialog('隱私權政策', '這是平台的隱私權政策內容...\n\n1. 數據搜集：我們會搜集您的註冊電子郵件與名稱以提供基本個人化服務。\n2. 數據使用：所有通訊資料均經由高強度 SSL 加密進行安全防護。\n3. 用戶權利：您可以隨時申請刪除您的帳號與個人歷史記錄。'),
                        child: const Text(
                          '隱私權政策',
                          style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Interactive submit button builder
  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6366F1), // Indigo
            Color(0xFF8B5CF6), // Purple
            Color(0xFFEC4899), // Pink
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '註冊帳號',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
      ),
    );
  }

  // Social Sign-up button builder
  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: label == 'Google' ? 32 : 22),
              if (label != 'Google') const SizedBox(width: 6),
              if (label != 'Google')
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Display terms / policy dialog
  void _showTermsDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我了解了', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to build a stunning glowing abstract logo for SeniorProject
class AppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Glowing outer abstract hexagon shape
    final path = Path();
    const double radius = 32.0;
    for (int i = 0; i < 6; i++) {
      double angle = (i * 60) * 3.14159 / 180;
      double x = center.dx + radius * (i % 2 == 0 ? 1.0 : 0.8) * double.parse((1.0 * (1.0 + 0.15)).toString()) * (i == 0 || i == 3 ? 1.0 : 0.95) * (xCos(angle));
      double y = center.dy + radius * (i % 2 == 0 ? 1.0 : 0.8) * double.parse((1.0 * (1.0 + 0.15)).toString()) * (i == 0 || i == 3 ? 1.0 : 0.95) * (ySin(angle));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Purple to Pink glowing gradient for logo
    paint.shader = const LinearGradient(
      colors: [
        Color(0xFF6366F1), // Indigo
        Color(0xFFEC4899), // Pink
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawPath(path, paint);

    // Inner stylized User symbol inside the glowing shield
    final userPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF8B5CF6), // Purple
          Color(0xFF3B82F6), // Blue
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 15));

    // Head
    canvas.drawCircle(Offset(center.dx, center.dy - 6), 7, userPaint);

    // Shoulders
    final shoulderPath = Path();
    shoulderPath.moveTo(center.dx - 14, center.dy + 12);
    shoulderPath.quadraticBezierTo(
      center.dx,
      center.dy + 3,
      center.dx + 14,
      center.dy + 12,
    );
    shoulderPath.close();
    canvas.drawPath(shoulderPath, userPaint);
  }

  // Simplified manual approximation for trigonometric functions since dart:math is not strictly required
  double xCos(double radians) {
    // Basic Taylor-like or hardcoded points for standard 60-deg increments: 0, 60, 120, 180, 240, 300
    // radians: 0, pi/3, 2pi/3, pi, 4pi/3, 5pi/3
    double val = radians / 3.14159;
    if (val < 0.1) return 1.0;
    if (val > 0.3 && val < 0.4) return 0.5;
    if (val > 0.6 && val < 0.7) return -0.5;
    if (val > 0.9 && val < 1.1) return -1.0;
    if (val > 1.3 && val < 1.4) return -0.5;
    if (val > 1.6 && val < 1.7) return 0.5;
    return 1.0;
  }

  double ySin(double radians) {
    double val = radians / 3.14159;
    if (val < 0.1) return 0.0;
    if (val > 0.3 && val < 0.4) return 0.866;
    if (val > 0.6 && val < 0.7) return 0.866;
    if (val > 0.9 && val < 1.1) return 0.0;
    if (val > 1.3 && val < 1.4) return -0.866;
    if (val > 1.6 && val < 1.7) return -0.866;
    return 0.0;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
