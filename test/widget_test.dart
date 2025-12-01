// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:route/main.dart';

void main() {
  testWidgets('Route planner shell renders key controls', (tester) async {
    final view = tester.view;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Flutter Demo Home Page'), findsOneWidget);
    expect(find.text('Plan route'), findsOneWidget);
    expect(find.byIcon(Icons.route), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byType(SearchBar), findsOneWidget);
  });
}
