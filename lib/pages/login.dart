import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home.dart';
import 'package:smart_train/main.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailC = TextEditingController();
  final passC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      // appBar: AppBar(title: Text("Login")),
      backgroundColor: Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 40,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 50),
                  Column(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Raleway',
                          ),
                          children: [
                            TextSpan(
                              text: "SMART-",
                              style: TextStyle(color: Colors.black),
                            ),
                            TextSpan(
                              text: "TRAIN",
                              style: TextStyle(color: Color(0xFFEB2525)),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 50),

                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Color(0xFF4CAF50),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Account Available',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Email: admin@gmail.com',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1B5E20),
                                fontFamily: 'Poppins',
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Password: admin',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1B5E20),
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),

                      TextField(
                        controller: emailC,
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          // fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: "Email",
                          hintStyle: const TextStyle(
                            fontFamily: "Poppins",
                            // fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFFD9D9D9),
                          ),
                          filled: true,
                          fillColor: Colors.white,

                          prefixIcon: const Icon(
                            Icons.email,
                            color: Color(0xFFD9D9D9), // bisa diganti
                          ),

                          // Border default saat tidak fokus
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9D9D9), // warna border normal
                              width: 1.5,
                            ),
                          ),

                          // Border saat TextField fokus
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(
                                0xFFEB2525,
                              ), // warna border ketika fokus
                              width: 2,
                            ),
                          ),

                          // Border jika error
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                          ),

                          // Border jika fokus tapi error
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),
                      TextField(
                        controller: passC,
                        obscureText: true,
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          // fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: const TextStyle(
                            fontFamily: "Poppins",
                            // fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFFD9D9D9),
                          ),
                          filled: true,
                          fillColor: Colors.white,

                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Color(0xFFD9D9D9), // bisa diganti
                          ),

                          // Border default saat tidak fokus
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFFD9D9D9), // warna border normal
                              width: 1.5,
                            ),
                          ),

                          // Border saat TextField fokus
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(
                                0xFFEB2525,
                              ), // warna border ketika fokus
                              width: 2,
                            ),
                          ),

                          // Border jika error
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                          ),

                          // Border jika fokus tapi error
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      auth.loading
                          ? CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFFEB2525),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                onPressed: () async {
                                  try {
                                    await auth.login(emailC.text, passC.text);

                                    // Setelah login → pindah ke HomePage
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const Dashboard(),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Login gagal")),
                                    );
                                  }
                                },
                                child: Text(
                                  "Login",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),

                      SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account?"),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Sign up",
                              style: TextStyle(color: Color(0xFF0F3DDE)),
                            ),
                          ),
                        ],
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
}
