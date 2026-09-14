import 'package:flutter/material.dart';

import '../kit/bug_session_kit.dart';
import '../kit/bug_session_modal_context.dart';
import 'glass/glass_panel.dart';

/// Bottom sheet with an inner [Navigator] (list → detail, back restores list).
class BugSessionSheetStack extends StatefulWidget {
  const BugSessionSheetStack({
    super.key,
    required this.kit,
    required this.title,
    required this.initialRoute,
    required this.routes,
    this.initialArguments,
    this.maxHeightFactor = 0.85,
    this.titleForRoute,
  });

  final BugSessionKit kit;
  final String title;
  final String initialRoute;
  final Map<String, WidgetBuilder> routes;
  final Object? initialArguments;
  final double maxHeightFactor;
  final String Function(String routeName, String defaultTitle)? titleForRoute;

  static Future<void> show({
    required BuildContext context,
    required BugSessionKit kit,
    required String title,
    required String initialRoute,
    required Map<String, WidgetBuilder> routes,
    Object? initialArguments,
    double maxHeightFactor = 0.85,
    String Function(String routeName, String defaultTitle)? titleForRoute,
  }) {
    return kit.sheetCoordinator.runExclusive(kit, () async {
      final modalContext = requireBugSessionModalContext(
        kit.config,
        fallback: context,
      );
      await showModalBottomSheet<void>(
        context: modalContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        builder: (ctx) => BugSessionSheetStack(
          kit: kit,
          title: title,
          initialRoute: initialRoute,
          routes: routes,
          initialArguments: initialArguments,
          maxHeightFactor: maxHeightFactor,
          titleForRoute: titleForRoute,
        ),
      );
    });
  }

  @override
  State<BugSessionSheetStack> createState() => _BugSessionSheetStackState();
}

class _BugSessionSheetStackState extends State<BugSessionSheetStack> {
  final GlobalKey<NavigatorState> _innerNavKey = GlobalKey<NavigatorState>();
  String _routeTitle = '';

  @override
  void initState() {
    super.initState();
    _routeTitle = widget.title;
  }

  void _popOrCloseSheet() {
    final inner = _innerNavKey.currentState;
    if (inner != null && inner.canPop()) {
      inner.pop();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.kit.config.resolvedTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * widget.maxHeightFactor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _popOrCloseSheet();
      },
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: GlassPanel(
              theme: theme,
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _popOrCloseSheet,
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      ),
                      Expanded(
                        child: Text(
                          _routeTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Navigator(
                      key: _innerNavKey,
                      initialRoute: widget.initialRoute,
                      onGenerateRoute: (settings) {
                        final name = settings.name ?? widget.initialRoute;
                        final builder = widget.routes[name];
                        if (builder == null) {
                          return MaterialPageRoute<void>(
                            builder: (_) => const SizedBox.shrink(),
                          );
                        }
                        final args = settings.arguments ??
                            (name == widget.initialRoute
                                ? widget.initialArguments
                                : null);
                        final resolvedTitle = widget.titleForRoute?.call(
                              name,
                              widget.title,
                            ) ??
                            widget.title;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          if (_routeTitle != resolvedTitle) {
                            setState(() => _routeTitle = resolvedTitle);
                          }
                        });
                        return MaterialPageRoute<void>(
                          settings: RouteSettings(name: name, arguments: args),
                          builder: builder,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
