import 'package:flutter/material.dart';
import '../models/router_profile.dart';
import '../services/se06_api.dart';
import 'dashboard_screen.dart';
import 'huawei_test_screen.dart';

class LoginScreen extends StatefulWidget {
  final RouterProfile profile;

  const LoginScreen({
    super.key,
    required this.profile,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the router password.'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      if (widget.profile.routerType == RouterType.suncommSe06Pro) {
        final api = Se06Api(
          routerIp: widget.profile.currentIp,
        );

        await api.login(
          username,
          password,
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              api: api,
            ),
          ),
        );
      } else if (widget.profile.routerType == RouterType.huaweiEg8145v5) {
        // Kept as a safe fallback for any older navigation path.
        // The normal Huawei flow now skips this generic login screen.
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HuaweiTestScreen(
              routerIp: widget.profile.currentIp,
            ),
          ),
        );
      } else {
        throw Exception(
          '${widget.profile.routerTypeName} API is not implemented yet.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.profile.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.profile.routerTypeName),
            const SizedBox(height: 6),
            Text(widget.profile.currentIp),
            const SizedBox(height: 30),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
