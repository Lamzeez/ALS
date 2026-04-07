import 'package:flutter_bloc/flutter_bloc.dart';

/// Debug observer that logs all BLoC state transitions.
class AlsBlocObserver extends BlocObserver {
  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    // ignore in release builds
    assert(() {
      print('${bloc.runtimeType} $transition');
      return true;
    }());
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    print('${bloc.runtimeType} Error: $error');
  }
}
