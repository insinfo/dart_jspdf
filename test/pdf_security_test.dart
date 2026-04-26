import 'package:jspdf/jspdf.dart';
import 'package:test/test.dart';

void main() {
  group('MD5', () {
    test('matches well-known hex vectors', () {
      expect(md5HexString(''), 'd41d8cd98f00b204e9800998ecf8427e');
      expect(md5HexString('hello'), '5d41402abc4b2a76b9719d911017c592');
      expect(
          md5HexString('message digest'), 'f96b697d7cb7938d525a2f31aaf161d0');
    });
  });

  group('RC4', () {
    test('matches well-known test vector', () {
      final String encrypted = rc4('Key', 'Plaintext');

      expect(toHexString(encrypted).toUpperCase(), 'BBF316E8D940AF0AD3');
    });

    test('decrypts by applying the same key again', () {
      final String encrypted = rc4('Wiki', 'pedia');

      expect(rc4('Wiki', encrypted), 'pedia');
    });
  });

  group('PdfSecurity', () {
    test('computes revision 2 permissions and dictionary fields', () {
      final PdfSecurity security = PdfSecurity(
        permissions: const <String>['print', 'copy'],
        userPassword: 'user',
        ownerPassword: 'owner',
        fileId: '00112233445566778899aabbccddeeff',
      );

      expect(security.v, 1);
      expect(security.r, 2);
      expect(security.p, -44);
      expect(security.encryptionKey.length, 5);
      expect(security.o.length, 32);
      expect(security.u.length, 32);
      expect(
        security.encryptionDictionary(1),
        '<</Filter /Standard /V 1 /R 2 /O <${toHexString(security.o)}> /U <${toHexString(security.u)}> /P -44>>',
      );
    });

    test('encryptor is deterministic per object and generation', () {
      final PdfSecurity security = PdfSecurity(
        permissions: const <String>['print'],
        userPassword: 'user',
        ownerPassword: 'owner',
        fileId: '00112233445566778899aabbccddeeff',
      );

      final String encrypted = security.encryptObject(7, 0, 'stream data');

      expect(encrypted, security.encryptObject(7, 0, 'stream data'));
      expect(encrypted, isNot('stream data'));
      expect(security.encryptObject(8, 0, 'stream data'), isNot(encrypted));
    });

    test('rejects unsupported permissions', () {
      expect(
        () => PdfSecurity(
          permissions: const <String>['print-high'],
          fileId: '00112233445566778899aabbccddeeff',
        ),
        throwsArgumentError,
      );
    });

    test('JsPdf emits encryption dictionary and encrypted streams', () {
      final JsPdf pdf = JsPdf(
        const JsPdfOptions(
          encryption: PdfEncryptionOptions(
            userPermissions: <String>['print'],
            userPassword: 'user',
            ownerPassword: 'owner',
          ),
        ),
      )..text('secret text', 10, 10);

      final String output = pdf.output() as String;

      expect(output, contains('/Encrypt'));
      expect(output, contains('/Filter /Standard'));
      expect(output, isNot(contains('secret text')));
    });
  });
}
