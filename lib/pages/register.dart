import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Color(0xFFF9F9F9),
      // appBar: AppBar(title: Text("Register")),
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
                      Text(
                        "Get Started Now",
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      SizedBox(height: 45),

                      TextField(
                        controller: nameC,
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          // fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: "Name",
                          hintStyle: const TextStyle(
                            fontFamily: "Poppins",
                            // fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFFD9D9D9),
                          ),
                          filled: true,
                          fillColor: Colors.white,

                          prefixIcon: const Icon(
                            Icons.account_circle,
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
                                    await auth.register(
                                      nameC.text,
                                      emailC.text,
                                      passC.text,
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Registrasi berhasil"),
                                      ),
                                    );

                                    // Setelah register → pindah ke login
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LoginPage(),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Gagal register")),
                                    );
                                  }
                                },
                                child: Text(
                                  "Sign Up",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),

                      SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Have an account?"),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => LoginPage()),
                              );
                            },
                            child: Text(
                              "Sign in",
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
