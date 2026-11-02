// lib/app/transitions.dart
//
// Spec §5.5: page transitions use the `animations` package's shared-axis
// pattern; every transition collapses to an instant swap when motion is
// reduced (MediaQuery.disableAnimations, which app.dart sets from both the OS
// flag and the in-app Motion setting).
//
// - Pushed routes: horizontal shared axis (via ThemeData.pageTransitionsTheme).
// - Modal-like routes (zen, search): scaled shared axis ([scaledAxisPage]).
// - Redirect targets (home / onboarding / lock): fade through ([fadeThroughPage]).
// - Shell branch switches: fade through ([AnimatedBranchContainer]).

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streakin/core/design/motion.dart';
import 'package:streakin/core/design/tokens.dart';

/// Default page transition for every MaterialPage route.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _sharedAxis = SharedAxisPageTransitionsBuilder(
    transitionType: SharedAxisTransitionType.horizontal,
  );

  @override
  Duration get transitionDuration => AppDurations.pageTransition;

  @override
  Duration get reverseTransitionDuration => AppDurations.pageTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _sharedAxis.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Fade-through page for top-level redirect targets.
Page<void> fadeThroughPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.name,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: context.colors.bg,
        child: child,
      );
    },
  );
}

/// Scaled shared-axis page for modal-like full-screen routes.
Page<void> scaledAxisPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: state.name,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.scaled,
        fillColor: context.colors.bg,
        child: child,
      );
    },
  );
}

/// Branch container for StatefulShellRoute that keeps every branch alive
/// (state + scroll position preserved, like IndexedStack) but fades the newly
/// selected branch in. Inactive branches are offstage with tickers disabled.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppCurves.enter,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.985,
    end: 1,
  ).animate(_fade);

  @override
  void didUpdateWidget(AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _branch(i, widget.children[i]),
      ],
    );
  }

  Widget _branch(int index, Widget child) {
    final active = index == widget.currentIndex;
    // Same widget structure for every branch so element state is never lost
    // when a branch becomes active / inactive.
    return Offstage(
      offstage: !active,
      child: TickerMode(
        enabled: active,
        child: FadeTransition(
          opacity: active ? _fade : kAlwaysCompleteAnimation,
          child: ScaleTransition(
            scale: active ? _scale : kAlwaysCompleteAnimation,
            child: child,
          ),
        ),
      ),
    );
  }
}
