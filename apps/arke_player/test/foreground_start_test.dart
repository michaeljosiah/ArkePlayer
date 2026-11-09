import 'package:arke_player/app/foreground_start.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a headless media wake does not start the writable UI until an activity resumes', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    var started = false;
    final opening = waitForFirstForeground().then((_) => started = true);
    await tester.pump();
    expect(started, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await opening;
    expect(started, isTrue);
  });

  testWidgets('an already visible activity starts without waiting for another resume', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var started = false;
    await waitForFirstForeground().then((_) => started = true);
    expect(started, isTrue);
  });

  testWidgets('later pauses do not repeat startup and a new headless engine waits independently', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var starts = 0;
    await waitForFirstForeground().then((_) => starts++);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final next = waitForFirstForeground().then((_) => starts++);
    await tester.pump();
    expect(starts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await next;
    expect(starts, 2);
  });
}
