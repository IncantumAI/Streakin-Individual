// lib/shared/widgets/async_value_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streakin/shared/widgets/error_state.dart';
import 'package:streakin/shared/widgets/skeleton.dart';

/// Standard loading / error / data presentation for an [AsyncValue].
/// Loading defaults to a skeleton list; errors to [ErrorState] with retry.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.compactError = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  final bool compactError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => loading ?? const SkeletonList(),
      error: (e, st) => compactError
          ? ErrorState.inline(error: e, stackTrace: st, onRetry: onRetry)
          : ErrorState(error: e, stackTrace: st, onRetry: onRetry),
    );
  }
}
