import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../common/custom_app_bar.dart';

class TransactionScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const TransactionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: CustomAppBar(title: title, trailing: trailing),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: scaffoldBg,
              child: Opacity(
                opacity: 0.4,
                child: Image.asset(
                  'assets/images/bg_curve.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
