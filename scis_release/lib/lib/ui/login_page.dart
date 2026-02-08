import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/token_store.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final j = await widget.api.postJson<Map<String, dynamic>>(
        '/auth/login',
        {'userId': _user.text.trim(), 'password': _pass.text},
        auth: false,
      );

      final token = (j['accessToken'] ?? '') as String;
      final exp = (j['expiresAtUtc'] ?? '') as String;
      if (token.isEmpty) throw ApiException(500, 'Token vacío');

      await TokenStore().save(token, exp);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(api: widget.api)),
      );
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F7FB), Color(0xFFE9EEF6)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 6),
                      const Text(
                        'SCIS Demo',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),

                      // ✅ Texto agregado debajo del título
                      const SizedBox(height: 6),
                      const Text(
                        'Jehovani Chavez te da la bienvenida',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 18),
                      TextField(
                        controller: _user,
                        decoration: const InputDecoration(labelText: 'Usuario'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password'),
                      ),
                      const SizedBox(height: 16),
                      if (_err != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(_err!, style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          child: _loading
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Text('Ingresar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
