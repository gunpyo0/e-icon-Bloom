import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _showErrorSnackBar('이용약관에 동의해주세요.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('=== SIGNUP PROCESS START ===');
      print('Email: ${_emailController.text.trim()}');
      print('Name: ${_nameController.text.trim()}');
      print('============================');
      
      // 1단계: 회원가입 (백엔드 signIn 함수 사용 - 실제로는 회원가입 기능)
      print('Step 1: Creating user account with profile...');
      final userCredential = await EcoBackend.instance.signIn(
        _nameController.text.trim(),     // displayName
        _emailController.text.trim(),    // email
        _passwordController.text,        // password
      );
      
      print('Step 1 completed. User: ${userCredential.user?.uid}');
      print('Profile automatically created in Firestore');

      // 2단계: 자동 리그 참가
      print('Step 2: Joining league...');
      try {
        await EcoBackend.instance.ensureUserInLeague();
        print('Step 2 completed. League joined.');
      } catch (e) {
        print('Step 2 warning: League join failed: $e');
        // 리그 참가 실패도 치명적이지 않으므로 계속 진행
      }

      print('=== SIGNUP PROCESS SUCCESS ===');
      
      if (mounted) {
        _showSuccessSnackBar('회원가입이 완료되었습니다!');
        // 메인 화면으로 이동
        context.go('/');
      }
    } catch (e) {
      print('=== SIGNUP ERROR DEBUG ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Error string: ${e.toString()}');
      print('==========================');
      
      if (mounted) {
        _showErrorSnackBar('회원가입 실패: ${_getErrorMessage(e.toString())}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  String _getErrorMessage(String error) {
    if (error.contains('email-already-in-use')) {
      return '이미 사용 중인 이메일입니다.';
    } else if (error.contains('weak-password')) {
      return '비밀번호가 너무 약합니다.';
    } else if (error.contains('invalid-email')) {
      return '유효하지 않은 이메일 형식입니다.';
    } else if (error.contains('operation-not-allowed')) {
      return '이메일 회원가입이 비활성화되어 있습니다.';
    } else if (error.contains('network-request-failed')) {
      return '네트워크 연결을 확인해주세요.';
    } else if (error.contains('too-many-requests')) {
      return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
    }
    return '오류가 발생했습니다: $error';
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.brown),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 헤더 섹션
                _buildHeaderSection(),
                
                const SizedBox(height: 40),
                
                // 폼 섹션
                _buildFormSection(),
                
                const SizedBox(height: 24),
                
                // 회원가입 버튼
                _buildSignUpButton(),
                
                const SizedBox(height: 24),
                
                // 로그인 링크
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.eco,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '환경을 위한\n첫 걸음을 시작하세요',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.brown.shade800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bloom에서 친환경 생활을 배우고 실천해보세요',
          style: TextStyle(
            fontSize: 16,
            color: Colors.brown.shade600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Column(
      children: [
        // 이름 입력
        _buildTextField(
          controller: _nameController,
          label: '이름',
          hint: '사용하실 이름을 입력하세요',
          prefixIcon: Icons.person_outline,
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return '이름을 입력해주세요';
            }
            if (value!.length < 2) {
              return '이름은 2글자 이상 입력해주세요';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // 이메일 입력
        _buildTextField(
          controller: _emailController,
          label: '이메일',
          hint: 'example@email.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return '이메일을 입력해주세요';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
              return '올바른 이메일 형식이 아닙니다';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // 비밀번호 입력
        _buildTextField(
          controller: _passwordController,
          label: '비밀번호',
          hint: '6자 이상의 비밀번호를 입력하세요',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return '비밀번호를 입력해주세요';
            }
            if (value!.length < 6) {
              return '비밀번호는 6자 이상 입력해주세요';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // 비밀번호 확인
        _buildTextField(
          controller: _confirmPasswordController,
          label: '비밀번호 확인',
          hint: '비밀번호를 다시 입력하세요',
          prefixIcon: Icons.lock_outline,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return '비밀번호 확인을 입력해주세요';
            }
            if (value != _passwordController.text) {
              return '비밀번호가 일치하지 않습니다';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 20),
        
        // 이용약관 동의
        _buildTermsCheckbox(),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.brown.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(prefixIcon, color: Colors.green.shade600),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade400, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
          activeColor: Colors.green.shade600,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
            child: Text(
              '이용약관 및 개인정보처리방침에 동의합니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.brown.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : _signUpWithEmail,
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    '회원가입',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }


  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '이미 계정이 있으신가요? ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () => context.pop(), // 로그인 화면으로 돌아가기
          child: Text(
            '로그인',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}