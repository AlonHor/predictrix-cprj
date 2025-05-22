import 'package:flutter/material.dart';

class NavigatorUtils {
  static void navigateTo(BuildContext context, Widget widget) {
    Navigator.push(
        context,
        PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget,
            transitionDuration: const Duration(milliseconds: 400),
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const curve = Curves.easeInOut;

              var scaleTween =
                  Tween(begin: 0.75, end: 1.0).chain(CurveTween(curve: curve));
              var scaleAnimation = animation.drive(scaleTween);

              var borderRadiusTween = Tween<double>(begin: 100.0, end: 0.0)
                  .chain(CurveTween(curve: curve));
              var borderRadiusAnimation = animation.drive(borderRadiusTween);

              var opacityTween = Tween<double>(begin: 0.0, end: 1.0)
                  .chain(CurveTween(curve: curve));

              var opacityAnimation = animation.drive(opacityTween);

              return ScaleTransition(
                scale: scaleAnimation,
                child: FadeTransition(
                  opacity: opacityAnimation,
                  child: AnimatedBuilder(
                    animation: borderRadiusAnimation,
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(borderRadiusAnimation.value),
                        child: child,
                      );
                    },
                    child: child,
                  ),
                ),
              );
            }));
    // MaterialPageRoute(
    //     builder: (context) => widget,
    //     settings: RouteSettings(name: widget.toStringShort())));
  }
}
