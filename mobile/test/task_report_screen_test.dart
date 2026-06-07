import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/tasks/task_report_screen.dart';

void main() {
  testWidgets('soumet texte, minutes et photos collectées', (tester) async {
    String? gotText;
    int? gotMinutes;
    List<String>? gotPhotos;

    await tester.pumpWidget(MaterialApp(
      home: TaskReportScreen(
        pickPhoto: () async => '/tmp/photo.jpg',
        onSubmit: (text, minutes, photos) async {
          gotText = text; gotMinutes = minutes; gotPhotos = photos;
        },
      ),
    ));

    await tester.enterText(find.byKey(const Key('report_text')), 'travail fait');
    await tester.enterText(find.byKey(const Key('report_minutes')), '90');
    await tester.tap(find.byKey(const Key('add_photo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit_report')));
    await tester.pump();

    expect(gotText, 'travail fait');
    expect(gotMinutes, 90);
    expect(gotPhotos, ['/tmp/photo.jpg']);
  });
}
