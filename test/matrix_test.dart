import 'package:test/test.dart';
import 'package:jspdf/src/matrix.dart';
import 'package:jspdf/src/geometry.dart';

void main() {
  group('PdfMatrix', () {
    test('construtor padrão é identidade', () {
      final m = PdfMatrix();
      expect(m.sx, equals(1));
      expect(m.shy, equals(0));
      expect(m.shx, equals(0));
      expect(m.sy, equals(1));
      expect(m.tx, equals(0));
      expect(m.ty, equals(0));
      expect(m.isIdentity, isTrue);
    });

    test('construtor com valores', () {
      final m = PdfMatrix(2, 0, 0, 3, 10, 20);
      expect(m.sx, equals(2));
      expect(m.sy, equals(3));
      expect(m.tx, equals(10));
      expect(m.ty, equals(20));
      expect(m.isIdentity, isFalse);
    });

    test('aliases a/b/c/d/e/f', () {
      final m = PdfMatrix(1, 2, 3, 4, 5, 6);
      expect(m.a, equals(1));
      expect(m.b, equals(2));
      expect(m.c, equals(3));
      expect(m.d, equals(4));
      expect(m.e, equals(5));
      expect(m.f, equals(6));
    });

    test('multiply', () {
      final m1 = PdfMatrix(2, 0, 0, 2, 0, 0); // Scale 2x
      final m2 = PdfMatrix(1, 0, 0, 1, 10, 20); // Translate 10,20

      final result = m1.multiply(m2);
      // m1.multiply(m2) = m2 * m1 (PDF right-multiplication)
      // newTx = m2.tx * m1.sx + m1.tx = 10 * 2 + 0 = 20
      // newTy = m2.ty * m1.sy + m1.ty = 20 * 2 + 0 = 40
      expect(result.tx, closeTo(20, 0.001));
      expect(result.ty, closeTo(40, 0.001));
      expect(result.sx, closeTo(2, 0.001));
      expect(result.sy, closeTo(2, 0.001));
    });

    test('inversed', () {
      final m = PdfMatrix(2, 0, 0, 3, 10, 20);
      final inv = m.inversed();
      final identity = m.multiply(inv);

      expect(identity.sx, closeTo(1, 0.001));
      expect(identity.sy, closeTo(1, 0.001));
      expect(identity.shy, closeTo(0, 0.001));
      expect(identity.shx, closeTo(0, 0.001));
    });

    test('applyToPoint', () {
      final m = PdfMatrix(1, 0, 0, 1, 100, 200); // Translation
      final pt = PdfPoint(10, 20);
      final result = m.applyToPoint(pt);
      expect(result.x, closeTo(110, 0.001));
      expect(result.y, closeTo(220, 0.001));
    });

    test('applyToPoint com escala', () {
      final m = PdfMatrix(2, 0, 0, 3, 0, 0); // Scale
      final pt = PdfPoint(5, 10);
      final result = m.applyToPoint(pt);
      expect(result.x, closeTo(10, 0.001));
      expect(result.y, closeTo(30, 0.001));
    });

    test('applyToRectangle', () {
      final m = PdfMatrix(2, 0, 0, 2, 0, 0);
      final rect = PdfRectangle(5, 5, 10, 20);
      final result = m.applyToRectangle(rect);
      expect(result.x, closeTo(10, 0.001));
      expect(result.y, closeTo(10, 0.001));
      expect(result.w, closeTo(20, 0.001));
      expect(result.h, closeTo(40, 0.001));
    });

    test('clone', () {
      final m = PdfMatrix(1, 2, 3, 4, 5, 6);
      final c = m.clone();
      expect(c.sx, equals(m.sx));
      expect(c.shy, equals(m.shy));
      expect(c.shx, equals(m.shx));
      expect(c.sy, equals(m.sy));
      expect(c.tx, equals(m.tx));
      expect(c.ty, equals(m.ty));

      // Mutations shouldn't affect clone
      c.sx = 99;
      expect(m.sx, equals(1));
    });

    test('decompose', () {
      final m = PdfMatrix(2, 0, 0, 3, 10, 20);
      final d = m.decompose();

      expect(d.scale.sx, closeTo(2, 0.001));
      expect(d.scale.sy, closeTo(3, 0.001));
      expect(d.translate.tx, closeTo(10, 0.001));
      expect(d.translate.ty, closeTo(20, 0.001));
    });

    test('toString gera string PDF válida', () {
      final m = PdfMatrix(1, 0, 0, 1, 0, 0);
      final s = m.toString();
      final parts = s.split(' ');
      expect(parts.length, equals(6));
    });

    test('identity estático', () {
      expect(PdfMatrix.identity.isIdentity, isTrue);
    });

    test('equality', () {
      final m1 = PdfMatrix(1, 2, 3, 4, 5, 6);
      final m2 = PdfMatrix(1, 2, 3, 4, 5, 6);
      expect(m1, equals(m2));
    });
  });

  group('PdfPoint', () {
    test('construtor e igualdade', () {
      final p1 = PdfPoint(1, 2);
      final p2 = PdfPoint(1, 2);
      expect(p1, equals(p2));
    });

    test('toString', () {
      expect(PdfPoint(3, 4).toString(), equals('PdfPoint(3.0, 4.0)'));
    });
  });

  group('PdfRectangle', () {
    test('construtor e igualdade', () {
      final r1 = PdfRectangle(1, 2, 3, 4);
      final r2 = PdfRectangle(1, 2, 3, 4);
      expect(r1, equals(r2));
    });
  });
}
