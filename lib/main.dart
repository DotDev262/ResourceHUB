import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:resourcehub/theme/theme_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:resourcehub/auth/signup.dart';
import 'package:resourcehub/auth/signin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  await Supabase.initialize(url: supabaseUrl!, anonKey: supabaseAnonKey!);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return DynamicColorBuilder(
          builder: (lightColorScheme, darkColorScheme) {
            return MaterialApp(
              title: 'Resource Hub',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.lightTheme(lightColorScheme),
              darkTheme: themeProvider.darkTheme(darkColorScheme),
              themeMode: themeProvider.themeMode,
              home: const SignUpPage(),
              routes: {
                '/signup': (context) => const SignUpPage(),
                '/home': (context) => const TempHomepage(),
                '/login': (context) => const SignInPage(),
              },
            );
          },
        );
      },
    );
  }
}

class TempHomepage extends StatelessWidget {
  const TempHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temporary Homepage')),
      body: const Center(child: Text('Welcome to the temporary homepage!')),
    );
  }
}
