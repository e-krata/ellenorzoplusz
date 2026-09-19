import 'dart:io' show Platform;

import 'package:folio/api/login.dart';
import 'package:folio/api/providers/user_provider.dart';
import 'package:folio/models/user.dart';
import 'package:folio_mobile_ui/common/custom_snack_bar.dart';
import 'package:folio_mobile_ui/common/system_chrome.dart';
import 'package:folio_mobile_ui/common/widgets/app_logo.dart';
import 'package:folio_mobile_ui/screens/settings/privacy_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'login_screen.i18n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.back = false,
  });

  final bool back;

  @override
  State<LoginScreen> createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _demoTapCount = 0;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final brightness = Theme.of(context).brightness;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
        systemNavigationBarColor:
            Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    final topPadding = Platform.isAndroid ? 12.0 : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: -size.width * 0.45,
            right: -size.width * 0.35,
            child: Container(
              width: size.width * 1.25,
              height: size.width * 1.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(
                  alpha: 0.055,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                if (widget.back)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 8,
                        top: topPadding,
                      ),
                      child: BackButton(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: topPadding + 8,
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 460,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 22),

                          GestureDetector(
                            onTap: _handleLogoTap,
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        colorScheme.primary
                                            .withValues(
                                      alpha: 0.20,
                                    ),
                                    blurRadius: 38,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: const AppLogo(
                                size: 104,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          Text(
                            'Folio',
                            style:
                                textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 36,
                              letterSpacing: -0.7,
                              color:
                                  colorScheme.onSurface,
                            ),
                          ),

                          const SizedBox(height: 7),

                          Text(
                            'login_w_kreten'.i18n,
                            textAlign: TextAlign.center,
                            style:
                                textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.50),
                            ),
                          ),

                          const SizedBox(height: 34),

                          _InfoCard(
                            icon: Icons.cloud_outlined,
                            title: 'KRÉTA',
                            subtitle:
                                'Bejelentkezés az ujkreta szerveren',
                          ),

                          const SizedBox(height: 26),

                          AutofillGroup(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(
                                  text: 'username'.i18n,
                                ),
                                const SizedBox(height: 7),
                                _buildUsernameField(
                                  colorScheme,
                                ),

                                const SizedBox(height: 15),

                                _FieldLabel(
                                  text: 'password'.i18n,
                                ),
                                const SizedBox(height: 7),
                                _buildPasswordField(
                                  colorScheme,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 22),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed:
                                  _isLoading
                                      ? null
                                      : _login,
                              style:
                                  FilledButton.styleFrom(
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    17,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 23,
                                      height: 23,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'login'.i18n,
                                      style:
                                          const TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons
                                      .calendar_month_rounded,
                                  text:
                                      'welcome_title_1'.i18n,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons
                                      .bar_chart_rounded,
                                  text:
                                      'welcome_title_2'.i18n,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _FeatureItem(
                                  icon: Icons
                                      .assignment_rounded,
                                  text:
                                      'welcome_title_3'.i18n,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 26),

                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : _demoLogin,
                            child: Text(
                              'demo_login'.i18n,
                            ),
                          ),

                          const SizedBox(height: 6),

                          GestureDetector(
                            onTap: () =>
                                PrivacyView.show(context),
                            child: Text(
                              'privacy'.i18n,
                              textAlign: TextAlign.center,
                              style:
                                  textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.38),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameField(
    ColorScheme colorScheme,
  ) {
    return TextField(
      controller: _usernameController,
      focusNode: _usernameFocus,
      enabled: !_isLoading,
      autofillHints: const [
        AutofillHints.username,
      ],
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) {
        _passwordFocus.requestFocus();
      },
      decoration: _inputDecoration(
        colorScheme,
        prefixIcon: Icons.person_outline_rounded,
      ),
    );
  }

  Widget _buildPasswordField(
    ColorScheme colorScheme,
  ) {
    return TextField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      enabled: !_isLoading,
      autofillHints: const [
        AutofillHints.password,
      ],
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: (_) => _login(),
      decoration: _inputDecoration(
        colorScheme,
        prefixIcon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          tooltip: _obscurePassword
              ? 'Jelszó megjelenítése'
              : 'Jelszó elrejtése',
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _obscurePassword =
                        !_obscurePassword;
                  });
                },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    ColorScheme colorScheme, {
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(
        prefixIcon,
        size: 21,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor:
          colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.45,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(
            alpha: 0.10,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _login() async {
    if (_isLoading) {
      return;
    }

    final username =
        _usernameController.text.trim();
    final password =
        _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showError(
        'missing_fields'.i18n,
      );
      return;
    }

    TextInput.finishAutofillContext();

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    final result = await newLoginAPI(
      username: username,
      password: password,
      instituteCode: 'ujkreta',
      context: context,
      onLogin: (user) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          CustomSnackBar(
            context: context,
            brightness:
                Theme.of(context).brightness,
            content: Text(
              'welcome'.i18n.fill([
                user.name,
              ]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
      onSuccess: () {
        if (!mounted) {
          return;
        }

        setSystemChrome(context);

        Navigator.of(context)
            .pushReplacementNamed(
          'login_to_navigation',
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });

    switch (result) {
      case LoginState.success:
        break;

      case LoginState.missingFields:
        _showError(
          'missing_fields'.i18n,
        );
        break;

      case LoginState.invalidGrant:
        _showError(
          'invalid_grant'.i18n,
        );
        break;

      case LoginState.failed:
      default:
        _showError(
          'error'.i18n,
        );
        break;
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  void _handleLogoTap() {
    _demoTapCount++;

    if (_demoTapCount < 10) {
      return;
    }

    _demoTapCount = 0;
    _demoLogin();
  }

  void _demoLogin() {
    if (_isLoading) {
      return;
    }

    final userProvider = Provider.of<UserProvider>(
      context,
      listen: false,
    );

    final demoUser = User.demo();

    userProvider.addUser(demoUser);
    userProvider.setUser(demoUser.id);

    setSystemChrome(context);

    Navigator.of(context)
        .pushReplacementNamed(
      'login_to_navigation',
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: 3,
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface
                  .withValues(alpha: 0.58),
            ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer
            .withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary
                  .withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: colorScheme
                            .onSurface
                            .withValues(
                          alpha: 0.52,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      constraints:
          const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 6),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface
                      .withValues(alpha: 0.68),
                ),
          ),
        ],
      ),
    );
  }
}