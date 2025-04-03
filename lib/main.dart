import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:resourcehub/theme/theme_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:resourcehub/auth/signup.dart';
import 'package:resourcehub/auth/signin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:resourcehub/widgets/navigation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resourcehub/pages/onboarding.dart';
import 'package:resourcehub/pages/course_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  await Supabase.initialize(url: supabaseUrl!, anonKey: supabaseAnonKey!);

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;

  const MyApp({super.key, required this.hasSeenOnboarding});

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
              home:
                  hasSeenOnboarding
                      ? const AuthCheck()
                      : const OnboardingPage(),
              routes: {
                '/signup': (context) => const SignUpPage(),
                '/home': (context) => const NavigationWidget(),
                '/login': (context) => const SignInPage(),
              },
            );
          },
        );
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
    });
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      setState(() {
        _loggedIn = true;
      });
    } else {
      setState(() {
        _loggedIn = false;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else {
      return _loggedIn ? const NavigationWidget() : const SignInPage();
    }
  }
}
