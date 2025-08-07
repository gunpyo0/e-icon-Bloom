import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;


  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      await EcoBackend.instance.signInWithGoogle();
      
      // Debug user info after successful Google login
      final user = EcoBackend.instance.currentUser;
      print('=== GOOGLE LOGIN SUCCESS DEBUG ===');
      print('UID: ${user?.uid}');
      print('Email: ${user?.email}');
      print('DisplayName: ${user?.displayName}');
      print('===================================');
      
      // Auto league participation after successful login
      await EcoBackend.instance.ensureUserInLeague();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google login failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 100),
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'BLOOM',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your digital garden for loving the environment',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 80),
              // Google Sign In Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Icon(
                  Icons.account_circle,
                  color: _isLoading ? Colors.grey : Colors.white,
                  size: 24,
                ),
                label: _isLoading 
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign in with Google',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}