import 'package:flutter/material.dart';
import '../../core/session_controller.dart';

class SessionGate extends StatelessWidget {
  const SessionGate({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: session.status == SessionStatus.loading
            ? const Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(), SizedBox(height: 16), Text('Restoring your session...'),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(session.message ?? 'Unable to restore your session.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (session.status != SessionStatus.restricted)
                  FilledButton(onPressed: session.restore, child: const Text('Try again')),
                TextButton(onPressed: session.logout, child: const Text('Go to login')),
              ]),
      ))),
    ),
  );
}
