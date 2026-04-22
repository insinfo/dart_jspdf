import 'package:test/test.dart';
import 'package:jspdf/src/pubsub.dart';

void main() {
  group('PubSub', () {
    late PubSub pubsub;

    setUp(() {
      pubsub = PubSub();
    });

    test('subscribe e publish', () {
      var called = false;
      List<dynamic>? receivedArgs;

      pubsub.subscribe('test', (args) {
        called = true;
        receivedArgs = args;
      });

      pubsub.publish('test', ['hello', 42]);

      expect(called, isTrue);
      expect(receivedArgs, equals(['hello', 42]));
    });

    test('publish sem args passa lista vazia', () {
      List<dynamic>? receivedArgs;

      pubsub.subscribe('test', (args) {
        receivedArgs = args;
      });

      pubsub.publish('test');

      expect(receivedArgs, equals([]));
    });

    test('subscribe retorna token', () {
      final token = pubsub.subscribe('test', (args) {});
      expect(token, isNotEmpty);
    });

    test('unsubscribe remove callback', () {
      var callCount = 0;

      final token = pubsub.subscribe('test', (args) {
        callCount++;
      });

      pubsub.publish('test');
      expect(callCount, equals(1));

      pubsub.unsubscribe(token);
      pubsub.publish('test');
      expect(callCount, equals(1)); // Não foi chamado novamente
    });

    test('unsubscribe retorna false para token inexistente', () {
      expect(pubsub.unsubscribe('nonexistent'), isFalse);
    });

    test('subscribe once executa uma vez', () {
      var callCount = 0;

      pubsub.subscribe('test', (args) {
        callCount++;
      }, once: true);

      pubsub.publish('test');
      pubsub.publish('test');

      expect(callCount, equals(1));
    });

    test('múltiplos subscribers no mesmo topic', () {
      var count1 = 0;
      var count2 = 0;

      pubsub.subscribe('test', (args) => count1++);
      pubsub.subscribe('test', (args) => count2++);

      pubsub.publish('test');

      expect(count1, equals(1));
      expect(count2, equals(1));
    });

    test('topics diferentes são independentes', () {
      var countA = 0;
      var countB = 0;

      pubsub.subscribe('topicA', (args) => countA++);
      pubsub.subscribe('topicB', (args) => countB++);

      pubsub.publish('topicA');

      expect(countA, equals(1));
      expect(countB, equals(0));
    });

    test('publish topic inexistente não causa erro', () {
      expect(() => pubsub.publish('nonexistent'), returnsNormally);
    });

    test('erro em callback não afeta outros subscribers', () {
      var called = false;

      pubsub.subscribe('test', (args) {
        throw Exception('Test error');
      });

      pubsub.subscribe('test', (args) {
        called = true;
      });

      pubsub.publish('test');
      expect(called, isTrue);
    });
  });
}
