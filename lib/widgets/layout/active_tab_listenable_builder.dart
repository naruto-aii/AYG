import 'package:flutter/widgets.dart';

/// タブが前面のときだけ true。無い画面では常に前面扱い。
class ShellTabActive extends InheritedWidget {
  const ShellTabActive({super.key, required this.active, required super.child});

  final bool active;

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellTabActive>();
    return scope?.active ?? true;
  }

  @override
  bool updateShouldNotify(ShellTabActive oldWidget) =>
      active != oldWidget.active;
}

/// 背面タブでは通知を受けない。前面に戻ったときに最新の状態で描き直す。
class ActiveTabListenableBuilder extends StatefulWidget {
  const ActiveTabListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
  });

  final Listenable listenable;
  final WidgetBuilder builder;

  @override
  State<ActiveTabListenableBuilder> createState() =>
      _ActiveTabListenableBuilderState();
}

class _ActiveTabListenableBuilderState
    extends State<ActiveTabListenableBuilder> {
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = ShellTabActive.of(context);
    if (active && !_listening) {
      widget.listenable.addListener(_onChange);
      _listening = true;
    } else if (!active && _listening) {
      widget.listenable.removeListener(_onChange);
      _listening = false;
    }
  }

  @override
  void didUpdateWidget(ActiveTabListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable == widget.listenable) {
      return;
    }
    if (_listening) {
      oldWidget.listenable.removeListener(_onChange);
      widget.listenable.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    if (_listening) {
      widget.listenable.removeListener(_onChange);
    }
    super.dispose();
  }

  void _onChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
