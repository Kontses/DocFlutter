import 'package:docflutter/auth_screen.dart';
import 'package:docflutter/qr_scanner_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'package:docflutter/downloaded_manuals_screen.dart';
import 'package:docflutter/home_page.dart';
import 'package:docflutter/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:docflutter/user_data_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final themeProvider = ThemeProvider();
  final userDataProvider = UserDataProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: userDataProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Metro Μanuals',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
         colorScheme: ColorScheme.fromSeed(
           seedColor: Colors.blue,
           brightness: Brightness.dark
         ),
         useMaterial3: true,
         brightness: Brightness.dark,
      ),
      themeMode: themeProvider.themeMode,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.light ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
          systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.light ? Brightness.dark : Brightness.light,
        ),
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, snapshot) {
            final userDataProvider = ctx.read<UserDataProvider>();

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasData) {
              userDataProvider.loadUserData(snapshot.data);
              return const MyHomePage();
            } else {
              userDataProvider.clearUserData();
              return const AuthScreen();
            }
          },
        ),
      ),
    );
  }
}
