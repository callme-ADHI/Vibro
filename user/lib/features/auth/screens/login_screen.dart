import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../presentation/pages/main_shell.dart';
import '../../../../presentation/pages/connected/connected_main_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true;
  bool _obscurePassword = true;

  DateTime? _selectedDob;
  String? _selectedUserType;

  // Colors based on theme guidelines
  final Color _primaryNavy = const Color(0xFF0A192F);
  final Color _bgWhite = const Color(0xFFFFFFFF);
  final Color _errorRed = const Color(0xFFD32F2F);
  final Color _greyText = const Color(0xFF5A5A5A);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Pick DOB function
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), 
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryNavy, 
              onPrimary: Colors.white,
              onSurface: Colors.black, 
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  void _submitForm() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      if (!_isLogin) {
        if (_selectedDob == null) {
          _showErrorSnackBar('Please select your Date of Birth.');
          return;
        }
        if (_selectedUserType == null) {
          _showErrorSnackBar('Please select a User Type.');
          return;
        }
      }

      ref.read(authControllerProvider.notifier).authenticateUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _isLogin ? "" : _nameController.text.trim(),
        dob: _selectedDob ?? DateTime.now(), // Ignored on login
        userType: _selectedUserType ?? 'deaf', // Ignored on login
        isLogin: _isLogin,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: _errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      // Show errors
      if (next.error != null && next.error != previous?.error) {
        _showErrorSnackBar(next.error!);
      }

      // Route on successful auth using userType carried in state — no DB race
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        if (next.userType == 'connected') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ConnectedMainShell()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        }
      }
    });

    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: _bgWhite,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Icon(Icons.graphic_eq_rounded, size: 60, color: _primaryNavy),
                   const SizedBox(height: 16),
                  
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create an Account',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryNavy),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Sign in to continue using Vibro_v6.' : 'Please enter your details to register.',
                    style: TextStyle(fontSize: 16, color: _greyText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  if (!_isLogin) ...[
                    _buildLabel('Full Name'),
                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(fontSize: 18),
                      decoration: _inputDecoration('Enter your full name'),
                      validator: (value) {
                        if (!_isLogin && (value == null || value.trim().isEmpty)) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  _buildLabel('Email Address'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDecoration('Enter your email'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&\'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  _buildLabel('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                    style: const TextStyle(fontSize: 18),
                    decoration: _inputDecoration('Enter your password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: _primaryNavy,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Password is required';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  if (!_isLogin) ...[
                    _buildLabel('Date of Birth'),
                    InkWell(
                      onTap: () => _pickDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDob == null
                                  ? 'Select your Date of Birth'
                                  : '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}',
                              style: TextStyle(
                                fontSize: 18,
                                color: _selectedDob == null ? Colors.grey.shade600 : Colors.black87,
                              ),
                            ),
                            Icon(Icons.calendar_month, color: _primaryNavy),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildLabel('User Type'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUserType,
                          hint: const Text('Select your role', style: TextStyle(fontSize: 18)),
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down, color: _primaryNavy),
                          items: const [
                            DropdownMenuItem(value: 'deaf', child: Text('Deaf User', style: TextStyle(fontSize: 18))),
                            DropdownMenuItem(value: 'connected', child: Text('Connected User', style: TextStyle(fontSize: 18))),
                          ],
                          onChanged: (value) => setState(() => _selectedUserType = value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],

                  if (_isLogin) const SizedBox(height: 24),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryNavy,
                        foregroundColor: _bgWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Text(
                              _isLogin ? 'Log In' : 'Register',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: TextStyle(fontSize: 16, color: _greyText),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _formKey.currentState?.reset();
                          });
                        },
                        child: Text(
                          _isLogin ? 'Sign Up' : 'Log In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryNavy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _primaryNavy)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryNavy, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _errorRed, width: 2)),
    );
  }
}
