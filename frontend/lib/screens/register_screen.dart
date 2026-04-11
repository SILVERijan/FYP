import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend/api_service.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  String _selectedRole = 'user'; // 'user' or 'driver'

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _apiService.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(),
      role: _selectedRole,
    );
    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.black, size: 28),
              ).animate().fadeIn().slideX(begin: 0.2),
              
              const SizedBox(height: 32),
              
              Text(
                'Join the ride.',
                style: theme.textTheme.displayLarge,
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 8),
              
              Text(
                'Create your account to start tracking and traveling efficiently.',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.black54),
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
              
              const SizedBox(height: 40),

              const Text(
                'Register as',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black),
              ).animate().fadeIn(delay: 400.ms),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _RoleButton(
                      label: 'Passenger',
                      icon: Icons.person_rounded,
                      isSelected: _selectedRole == 'user',
                      onTap: () => setState(() => _selectedRole = 'user'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleButton(
                      label: 'Driver',
                      icon: Icons.directions_bus_rounded,
                      isSelected: _selectedRole == 'driver',
                      onTap: () => setState(() => _selectedRole = 'driver'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 32),
              
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 16),
              
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_open_rounded),
                ),
              ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text('Register as ${_selectedRole == 'driver' ? 'Driver' : 'Passenger'}'),
              ).animate().fadeIn(delay: 900.ms).scale(begin: const Offset(0.95, 0.95)),
              
              const SizedBox(height: 24),
              
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Login here', 
                          style: TextStyle(
                            color: theme.colorScheme.secondary, 
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 1100.ms),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(width: 8),
            Text(
              label, 
              style: TextStyle(
                fontWeight: FontWeight.w700, 
                fontSize: 14, 
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
