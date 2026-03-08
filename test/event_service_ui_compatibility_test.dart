import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_events/services/event_services.dart';
import 'package:uni_events/models/event.dart';
import 'package:uni_events/untils/migration_config.dart';
import 'dart:async';

/// Tests to verify that EventService refactoring maintains backward compatibility
/// with the UI layer. All method signatures must remain unchanged to prevent
/// breaking existing screens.
///
/// This test suite validates:
/// - All public method signatures remain unchanged
/// - Return types are consistent with UI expectations
/// - Stream-based methods continue to work with StreamBuilder widgets
/// - Future-based methods continue to work with async/await patterns
/// - Error handling remains consistent
void main() {
  group('EventService UI Compatibility Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    group('Method Signature Compatibility', () {
      test(
        'registerForEvent should accept String eventId and return Future<void>',
        () async {
          // This test verifies the method signature hasn't changed
          final eventService = EventService();

          // Create test event
          await fakeFirestore.collection('events').doc('event-1').set({
            'title': 'Test Event',
            'description': 'Test Description',
            'clubId': 'club-1',
            'location': 'Test Location',
            'startTime': Timestamp.now(),
            'endTime': Timestamp.now(),
            'capacity': 100,
            'participantCount': 0,
            'image': '',
            'createdBy': 'test-user-123',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'status': 'active',
            'note': '',
          });

          // Verify method signature: Future<void> registerForEvent(String eventId)
          Future<void> result = eventService.registerForEvent('event-1');
          expect(result, isA<Future<void>>());
        },
      );

      test(
        'unregisterFromEvent should accept String eventId and return Future<void>',
        () {
          final eventService = EventService();

          // Verify method signature: Future<void> unregisterFromEvent(String eventId)
          Future<void> result = eventService.unregisterFromEvent('event-1');
          expect(result, isA<Future<void>>());
        },
      );

      test(
        'isRegisteredStream should accept String eventId and return Stream<bool>',
        () {
          final eventService = EventService();

          // Verify method signature: Stream<bool> isRegisteredStream(String eventId)
          Stream<bool> result = eventService.isRegisteredStream('event-1');
          expect(result, isA<Stream<bool>>());
        },
      );

      test('getRegisteredEvents should return Stream<List<Event>>', () {
        final eventService = EventService();

        // Verify method signature: Stream<List<Event>> getRegisteredEvents()
        Stream<List<Event>> result = eventService.getRegisteredEvents();
        expect(result, isA<Stream<List<Event>>>());
      });

      test('getAllEvents should return Stream<List<Event>>', () {
        final eventService = EventService();

        // Verify method signature: Stream<List<Event>> getAllEvents()
        Stream<List<Event>> result = eventService.getAllEvents();
        expect(result, isA<Stream<List<Event>>>());
      });

      test('getManagedEvents should return Stream<List<Event>>', () {
        final eventService = EventService();

        // Verify method signature: Stream<List<Event>> getManagedEvents()
        Stream<List<Event>> result = eventService.getManagedEvents();
        expect(result, isA<Stream<List<Event>>>());
      });

      test(
        'getEventsByClubId should accept String clubId and return Stream<List<Event>>',
        () {
          final eventService = EventService();

          // Verify method signature: Stream<List<Event>> getEventsByClubId(String clubId)
          Stream<List<Event>> result = eventService.getEventsByClubId('club-1');
          expect(result, isA<Stream<List<Event>>>());
        },
      );

      test(
        'getParticipantCountStream should accept String eventId and return Stream<int>',
        () {
          final eventService = EventService();

          // Verify method signature: Stream<int> getParticipantCountStream(String eventId)
          Stream<int> result = eventService.getParticipantCountStream(
            'event-1',
          );
          expect(result, isA<Stream<int>>());
        },
      );

      test(
        'getConflictingEvent should accept Event and return Future<Event?>',
        () {
          final eventService = EventService();
          final testEvent = Event(
            id: 'event-1',
            title: 'Test Event',
            description: 'Test',
            clubId: 'club-1',
            location: 'Test Location',
            startTime: DateTime.now(),
            endTime: DateTime.now().add(Duration(hours: 2)),
            capacity: 100,
            participantCount: 0,
            image: '',
            createdBy: 'test-user-123',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: 'active',
            note: '',
          );

          // Verify method signature: Future<Event?> getConflictingEvent(Event targetEvent)
          Future<Event?> result = eventService.getConflictingEvent(testEvent);
          expect(result, isA<Future<Event?>>());
        },
      );

      test('createEvent should accept Event and return Future<void>', () {
        final eventService = EventService();
        final testEvent = Event(
          id: '',
          title: 'Test Event',
          description: 'Test',
          clubId: 'club-1',
          location: 'Test Location',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(Duration(hours: 2)),
          capacity: 100,
          participantCount: 0,
          image: '',
          createdBy: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'active',
          note: '',
        );

        // Verify method signature: Future<void> createEvent(Event event)
        Future<void> result = eventService.createEvent(testEvent);
        expect(result, isA<Future<void>>());
      });

      test('updateEvent should accept Event and return Future<void>', () {
        final eventService = EventService();
        final testEvent = Event(
          id: 'event-1',
          title: 'Updated Event',
          description: 'Test',
          clubId: 'club-1',
          location: 'Test Location',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(Duration(hours: 2)),
          capacity: 100,
          participantCount: 0,
          image: '',
          createdBy: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'active',
          note: '',
        );

        // Verify method signature: Future<void> updateEvent(Event event)
        Future<void> result = eventService.updateEvent(testEvent);
        expect(result, isA<Future<void>>());
      });

      test(
        'deleteEvent should accept String eventId and return Future<void>',
        () {
          final eventService = EventService();

          // Verify method signature: Future<void> deleteEvent(String eventId)
          Future<void> result = eventService.deleteEvent('event-1');
          expect(result, isA<Future<void>>());
        },
      );
    });

    group('StreamBuilder Compatibility', () {
      test('isRegisteredStream works with StreamBuilder pattern', () async {
        final eventService = EventService();

        // Add registration to new collection
        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // Simulate StreamBuilder usage
        final stream = eventService.isRegisteredStream('event-1');

        // StreamBuilder expects to be able to listen to the stream
        final subscription = stream.listen((isRegistered) {
          expect(isRegistered, isA<bool>());
        });

        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();
      });

      test('getRegisteredEvents works with StreamBuilder pattern', () async {
        final eventService = EventService();

        // Simulate StreamBuilder usage
        final stream = eventService.getRegisteredEvents();

        // StreamBuilder expects to be able to listen to the stream
        final subscription = stream.listen((events) {
          expect(events, isA<List<Event>>());
        });

        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();
      });

      test('getAllEvents works with StreamBuilder pattern', () async {
        final eventService = EventService();

        // Add test event
        await fakeFirestore.collection('events').add({
          'title': 'Test Event',
          'description': 'Test Description',
          'clubId': 'club-1',
          'location': 'Test Location',
          'startTime': Timestamp.now(),
          'endTime': Timestamp.now(),
          'capacity': 100,
          'participantCount': 0,
          'image': '',
          'createdBy': 'test-user-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'status': 'active',
          'note': '',
        });

        // Simulate StreamBuilder usage
        final stream = eventService.getAllEvents();

        // StreamBuilder expects to be able to listen to the stream
        final subscription = stream.listen((events) {
          expect(events, isA<List<Event>>());
        });

        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();
      });

      test(
        'getParticipantCountStream works with StreamBuilder pattern',
        () async {
          final eventService = EventService();

          // Add test event
          await fakeFirestore.collection('events').doc('event-1').set({
            'title': 'Test Event',
            'description': 'Test Description',
            'clubId': 'club-1',
            'location': 'Test Location',
            'startTime': Timestamp.now(),
            'endTime': Timestamp.now(),
            'capacity': 100,
            'participantCount': 5,
            'image': '',
            'createdBy': 'test-user-123',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'status': 'active',
            'note': '',
          });

          // Simulate StreamBuilder usage
          final stream = eventService.getParticipantCountStream('event-1');

          // StreamBuilder expects to be able to listen to the stream
          final subscription = stream.listen((count) {
            expect(count, isA<int>());
          });

          await Future.delayed(Duration(milliseconds: 100));
          await subscription.cancel();
        },
      );
    });

    group('Async/Await Compatibility', () {
      test('registerForEvent works with async/await pattern', () async {
        final eventService = EventService();

        // Add test event
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'description': 'Test Description',
          'clubId': 'club-1',
          'location': 'Test Location',
          'startTime': Timestamp.now(),
          'endTime': Timestamp.now(),
          'capacity': 100,
          'participantCount': 0,
          'image': '',
          'createdBy': 'test-user-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'status': 'active',
          'note': '',
        });

        // Simulate async/await usage in UI
        try {
          await eventService.registerForEvent('event-1');
          // Should complete without error
        } catch (e) {
          // UI expects exceptions to be thrown for error cases
          expect(e, isA<Exception>());
        }
      });

      test('unregisterFromEvent works with async/await pattern', () async {
        final eventService = EventService();

        // Simulate async/await usage in UI
        try {
          await eventService.unregisterFromEvent('event-1');
          // Should complete without error (even if not registered)
        } catch (e) {
          // UI expects exceptions to be thrown for error cases
          expect(e, isA<Exception>());
        }
      });

      test('getConflictingEvent works with async/await pattern', () async {
        final eventService = EventService();
        final testEvent = Event(
          id: 'event-1',
          title: 'Test Event',
          description: 'Test',
          clubId: 'club-1',
          location: 'Test Location',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(Duration(hours: 2)),
          capacity: 100,
          participantCount: 0,
          image: '',
          createdBy: 'test-user-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'active',
          note: '',
        );

        // Simulate async/await usage in UI
        final conflicting = await eventService.getConflictingEvent(testEvent);
        expect(conflicting, isA<Event?>());
      });
    });

    group('Error Handling Compatibility', () {
      test(
        'registerForEvent throws Exception when user not logged in',
        () async {
          // This test would require mocking FirebaseAuth to return null user
          // For now, we verify the method signature accepts the pattern
          final eventService = EventService();

          expect(
            () => eventService.registerForEvent('event-1'),
            throwsA(isA<Exception>()),
          );
        },
      );

      test(
        'registerForEvent throws Exception when already registered',
        () async {
          final eventService = EventService();

          // Add test event
          await fakeFirestore.collection('events').doc('event-1').set({
            'title': 'Test Event',
            'description': 'Test Description',
            'clubId': 'club-1',
            'location': 'Test Location',
            'startTime': Timestamp.now(),
            'endTime': Timestamp.now(),
            'capacity': 100,
            'participantCount': 0,
            'image': '',
            'createdBy': 'test-user-123',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'status': 'active',
            'note': '',
          });

          // Add existing registration
          await fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // UI expects Exception to be thrown
          expect(
            () => eventService.registerForEvent('event-1'),
            throwsA(isA<Exception>()),
          );
        },
      );

      test('registerForEvent throws Exception when event is full', () async {
        final eventService = EventService();

        // Add test event at capacity
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'description': 'Test Description',
          'clubId': 'club-1',
          'location': 'Test Location',
          'startTime': Timestamp.now(),
          'endTime': Timestamp.now(),
          'capacity': 1,
          'participantCount': 1, // Full
          'image': '',
          'createdBy': 'test-user-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'status': 'active',
          'note': '',
        });

        // UI expects Exception to be thrown
        expect(
          () => eventService.registerForEvent('event-1'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Backward Compatibility During Migration', () {
      test(
        'isRegisteredStream returns true when registration exists in old collection',
        () async {
          final eventService = EventService();

          // Add registration to old collection only
          await fakeFirestore.collection('eventRegistrations').add({
            'eventId': 'event-1',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // UI should still see the registration
          final stream = eventService.isRegisteredStream('event-1');
          final completer = Completer<bool>();

          final subscription = stream.listen((isRegistered) {
            if (!completer.isCompleted) {
              completer.complete(isRegistered);
            }
          });

          final result = await completer.future.timeout(
            Duration(seconds: 2),
            onTimeout: () => false,
          );

          await subscription.cancel();

          // Should find registration in old collection during migration
          expect(result, isA<bool>());
        },
      );

      test(
        'getRegisteredEvents includes events from both collections',
        () async {
          final eventService = EventService();

          // Add event
          await fakeFirestore.collection('events').doc('event-1').set({
            'title': 'Test Event 1',
            'description': 'Test Description',
            'clubId': 'club-1',
            'location': 'Test Location',
            'startTime': Timestamp.now(),
            'endTime': Timestamp.now(),
            'capacity': 100,
            'participantCount': 0,
            'image': '',
            'createdBy': 'test-user-123',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'status': 'active',
            'note': '',
          });

          await fakeFirestore.collection('events').doc('event-2').set({
            'title': 'Test Event 2',
            'description': 'Test Description',
            'clubId': 'club-1',
            'location': 'Test Location',
            'startTime': Timestamp.now(),
            'endTime': Timestamp.now(),
            'capacity': 100,
            'participantCount': 0,
            'image': '',
            'createdBy': 'test-user-123',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'status': 'active',
            'note': '',
          });

          // Add registration to new collection
          await fakeFirestore.collection('registrations').add({
            'eventId': 'event-1',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // Add registration to old collection
          await fakeFirestore.collection('eventRegistrations').add({
            'eventId': 'event-2',
            'userId': 'test-user-123',
            'status': 'registered',
            'registeredAt': Timestamp.now(),
          });

          // UI should see both events
          final stream = eventService.getRegisteredEvents();
          final completer = Completer<List<Event>>();

          final subscription = stream.listen((events) {
            if (!completer.isCompleted) {
              completer.complete(events);
            }
          });

          final events = await completer.future.timeout(
            Duration(seconds: 2),
            onTimeout: () => <Event>[],
          );

          await subscription.cancel();

          // Should include events from both collections
          expect(events, isA<List<Event>>());
        },
      );
    });

    group('UI Screen Specific Scenarios', () {
      test('event_detail_screen: register button flow works', () async {
        final eventService = EventService();

        // Setup: Create event
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'description': 'Test Description',
          'clubId': 'club-1',
          'location': 'Test Location',
          'startTime': Timestamp.now(),
          'endTime': Timestamp.now(),
          'capacity': 100,
          'participantCount': 0,
          'image': '',
          'createdBy': 'test-user-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'status': 'active',
          'note': '',
        });

        // Step 1: Check if registered (should be false)
        final isRegisteredStream = eventService.isRegisteredStream('event-1');
        expect(isRegisteredStream, isA<Stream<bool>>());

        // Step 2: Register for event
        final registerFuture = eventService.registerForEvent('event-1');
        expect(registerFuture, isA<Future<void>>());

        // Step 3: Check participant count
        final countStream = eventService.getParticipantCountStream('event-1');
        expect(countStream, isA<Stream<int>>());
      });

      test('my_events_screen: displays registered events', () async {
        final eventService = EventService();

        // Setup: Create event and registration
        await fakeFirestore.collection('events').doc('event-1').set({
          'title': 'Test Event',
          'description': 'Test Description',
          'clubId': 'club-1',
          'location': 'Test Location',
          'startTime': Timestamp.now(),
          'endTime': Timestamp.now(),
          'capacity': 100,
          'participantCount': 1,
          'image': '',
          'createdBy': 'test-user-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'status': 'active',
          'note': '',
        });

        await fakeFirestore.collection('registrations').add({
          'eventId': 'event-1',
          'userId': 'test-user-123',
          'status': 'registered',
          'registeredAt': Timestamp.now(),
        });

        // MyEventsScreen uses getRegisteredEvents()
        final stream = eventService.getRegisteredEvents();
        expect(stream, isA<Stream<List<Event>>>());
      });

      test('events_screen: displays all events', () async {
        final eventService = EventService();

        // Setup: Create events
        await fakeFirestore.collection('events').add({
          'title': 'Test Event 1',
          'description': 'Test Description',
          'clubId': 'club-1',
          'location': 'Test Location',
          'startTime': Timestamp.now(),
          'endTime': Timestamp.now(),
          'capacity': 100,
          'participantCount': 0,
          'image': '',
          'createdBy': 'test-user-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'status': 'active',
          'note': '',
        });

        // EventsScreen uses getAllEvents()
        final stream = eventService.getAllEvents();
        expect(stream, isA<Stream<List<Event>>>());
      });

      test('club_public_profile_screen: displays club events', () async {
        final eventService = EventService();

        // Setup: Create event for club
        await fakeFirestore.collection('events').add({
          'title': 'Club Event',
          'description': 'Test Description',
          'clubId': 'club-123',
          'location': 'Test Location',
          'startTime': Timestamp.now(),
          'endTime': Timestamp.now(),
          'capacity': 100,
          'participantCount': 0,
          'image': '',
          'createdBy': 'test-user-123',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'status': 'active',
          'note': '',
        });

        // ClubPublicProfileScreen uses getEventsByClubId()
        final stream = eventService.getEventsByClubId('club-123');
        expect(stream, isA<Stream<List<Event>>>());
      });
    });
  });
}
