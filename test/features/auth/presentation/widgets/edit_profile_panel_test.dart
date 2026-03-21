import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/edit_profile_panel.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets('EditProfilePanel loads and updates profile form', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuthRepository();
    final snackBars = _RecordingSnackBarDispatcher();

    await _pumpPanel(tester, repository: repository, snackBars: snackBars);

    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    final firstNameField = tester.widget<TextFormField>(fields.at(0));
    final lastNameField = tester.widget<TextFormField>(fields.at(1));
    expect(firstNameField.controller?.text, 'Alice');
    expect(lastNameField.controller?.text, 'Example');

    await tester.enterText(fields.at(0), 'Alice Updated');
    await tester.enterText(fields.at(1), 'Example Updated');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Profile'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdateInput, isNotNull);
    expect(repository.lastUpdateInput?.firstName, 'Alice Updated');
    expect(repository.lastUpdateInput?.lastName, 'Example Updated');
    expect(repository.lastUpdateInput?.personRowVersion, 7);
    expect(repository.fetchOwnProfileCalls, greaterThanOrEqualTo(2));
    expect(snackBars.messages, contains('Profile updated successfully.'));
  });

  testWidgets('EditProfilePanel shows load error and retries', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuthRepository()
      ..fetchQueue = <Result<OwnProfileEntity>>[
        const Result<OwnProfileEntity>.failure(
          UnexpectedFailure('load failed'),
        ),
        const Result<OwnProfileEntity>.success(
          OwnProfileEntity(
            userId: 'u-1',
            personId: 'p-1',
            personRowVersion: 7,
            firstName: 'Alice',
            lastName: 'Example',
          ),
        ),
      ];

    await _pumpPanel(tester, repository: repository);
    await tester.pumpAndSettle();

    expect(find.text('load failed'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Save Profile'), findsOneWidget);
    expect(repository.fetchOwnProfileCalls, 2);
  });

  testWidgets('EditProfilePanel shows save failure and validates input', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuthRepository()
      ..updateResult = const Result<void>.failure(
        UnexpectedFailure('update failed'),
      );
    final snackBars = _RecordingSnackBarDispatcher();
    await _pumpPanel(tester, repository: repository, snackBars: snackBars);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Field cannot be empty.'), findsOneWidget);

    await tester.enterText(fields.first, 'Alice Updated');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Profile'));
    await tester.pumpAndSettle();

    expect(snackBars.messages, contains('update failed'));
  });

  testWidgets('EditProfilePanel cancel action is wired', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpPanel(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  required _FakeAuthRepository repository,
  _RecordingSnackBarDispatcher? snackBars,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
        appNavigatorProvider.overrideWith((Ref ref) => _FakeAppNavigator()),
        snackBarDispatcherProvider.overrideWith(
          (Ref ref) => snackBars ?? _RecordingSnackBarDispatcher(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: EditProfilePanel())),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  int fetchOwnProfileCalls = 0;
  List<Result<OwnProfileEntity>> fetchQueue = <Result<OwnProfileEntity>>[];
  Result<OwnProfileEntity> fetchResult = const Result<OwnProfileEntity>.success(
    OwnProfileEntity(
      userId: 'u-1',
      personId: 'p-1',
      personRowVersion: 7,
      firstName: 'Alice',
      lastName: 'Example',
    ),
  );
  Result<void> updateResult = const Result<void>.success(null);
  UpdateOwnProfileInput? lastUpdateInput;

  @override
  Result<AuthSession?> currentSession() {
    return const Result<AuthSession?>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u-1',
        roles: <String>['com.vorsocomputing.mugen.acp:authenticated'],
      ),
    );
  }

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    return const Result<bool>.success(true);
  }

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    return const Result<AuthSession>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u-1',
        roles: <String>[],
      ),
    );
  }

  @override
  Future<Result<void>> logout() async => const Result<void>.success(null);

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<OwnProfileEntity>> fetchOwnProfile() async {
    fetchOwnProfileCalls += 1;
    if (fetchQueue.isNotEmpty) {
      return fetchQueue.removeAt(0);
    }
    return fetchResult;
  }

  @override
  Future<Result<void>> updateOwnProfile(UpdateOwnProfileInput input) async {
    lastUpdateInput = input;
    return updateResult;
  }
}

class _FakeAppNavigator extends AppNavigator {}

class _RecordingSnackBarDispatcher extends SnackBarDispatcher {
  final List<String> messages = <String>[];

  @override
  void show(AppNavigator navigator, String content) {
    messages.add(content);
  }
}
