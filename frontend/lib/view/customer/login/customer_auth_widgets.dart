import 'package:flutter/material.dart';

abstract final class SodamStyle {
  static const background = Colors.white;
  // 기존 화면의 공용 색상 이름을 유지해 모든 고객 화면에 같은 테마를 적용한다.
  static const green = Color(0xFF36C4CF);
  static const ink = Color(0xFF202428);
  static const muted = Color(0xFF8B9096);
  static const border = Color(0xFFEBEDF0);
  static const soft = Color(0xFFEEFAFB);
  static const field = Color(0xFFF6F7F8);
  static const pink = Color(0xFFFF6383);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSansKR',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      onPrimary: Colors.white,
      surface: background,
      onSurface: ink,
      secondary: pink,
      outline: border,
      surfaceTint: Colors.transparent,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, color: ink),
      bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: border),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: background,
      selectedColor: soft,
      side: const BorderSide(color: border),
      labelStyle: const TextStyle(
        fontFamily: 'NotoSansKR',
        color: ink,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: const TextStyle(
        fontSize: 13,
        color: muted,
        fontWeight: FontWeight.w400,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: green, width: 1.3),
      ),
      errorMaxLines: 2,
      errorStyle: const TextStyle(fontSize: 11),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: green,
        textStyle: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
    ),
  );
}

class CustomerAuthLayout extends StatelessWidget {
  const CustomerAuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.showBack = false,
    this.canPop = true,
    this.padding = const EdgeInsets.fromLTRB(26, 20, 26, 32),
  });

  final String title;
  final Widget child;
  final bool showBack;
  final bool canPop;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: canPop,
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: showBack ? 40 : null,
        leading: showBack
            ? IconButton(
                tooltip: '로그인 화면으로 돌아가기',
                onPressed: canPop ? () => Navigator.of(context).pop() : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              )
            : null,
        titleSpacing: showBack ? 0 : 16,
        title: Text(title),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

class CustomerField extends StatelessWidget {
  const CustomerField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.focusNode,
    this.isPassword = false,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final bool isPassword;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CustomerFieldLabel(label),
      const SizedBox(height: 8),
      Semantics(
        label: label,
        child: TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffix,
            suffixIconConstraints: suffix == null
                ? null
                : const BoxConstraints(minWidth: 42, minHeight: 40),
          ),
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enableSuggestions: !(isPassword || obscureText),
          enableIMEPersonalizedLearning: !(isPassword || obscureText),
          autocorrect: false,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        ),
      ),
    ],
  );
}

class CustomerPasswordToggle extends StatelessWidget {
  const CustomerPasswordToggle({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(42, 40),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    child: Text(
      visible ? '숨기기' : '보기',
      semanticsLabel: visible ? '비밀번호 숨기기' : '비밀번호 보기',
      style: const TextStyle(fontSize: 10, color: SodamStyle.muted),
    ),
  );
}

class CustomerFieldLabel extends StatelessWidget {
  const CustomerFieldLabel(
    this.text, {
    super.key,
    this.textAlign = TextAlign.center,
  });
  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: textAlign,
    style: const TextStyle(
      color: SodamStyle.ink,
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w700,
    ),
  );
}

class CustomerSubmitButton extends StatelessWidget {
  const CustomerSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 44,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: height,
    child: FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        disabledBackgroundColor: SodamStyle.green.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

class CustomerAuthError extends StatelessWidget {
  const CustomerAuthError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          message!,
          key: const Key('auth-error'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
