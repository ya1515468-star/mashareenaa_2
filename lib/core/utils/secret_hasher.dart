import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// أداة تجزئة عامة لأي سر قصير يُخزَّن في طبقة بيانات Supabase (رمز PIN، كود
/// تأكيد البريد). لا يُخزَّن أي سر كنص صريح مطلقًا — فقط
/// [SecretHash.hash] بجانب [SecretHash.salt] العشوائي الخاص به.
///
/// ملاحظة أمنية: SHA-256 + ملح عشوائي كافٍ لسر يُستخدم كطبقة تحقق
/// محلي (فتح جلسة مخزّنة مسبقًا) وليس كبديل كامل عن قنوات مصادقة
/// الخادم. لا يُرسل السر أو تجزئته عبر الشبكة إلا داخل قناة Supabase
/// المشفّرة أصلًا.
class SecretHash {
  final String hash;
  final String salt;

  const SecretHash({required this.hash, required this.salt});

  static String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// ينشئ تجزئة جديدة بملح عشوائي لسر جديد (عند التسجيل).
  static SecretHash create(String plainSecret) {
    final salt = _generateSalt();
    final hash = _hashWithSalt(plainSecret, salt);
    return SecretHash(hash: hash, salt: salt);
  }

  /// يتحقق من تطابق سر مُدخَل مع تجزئة وملح مخزَّنين مسبقًا.
  static bool verify({
    required String plainSecret,
    required String storedHash,
    required String storedSalt,
  }) {
    final computed = _hashWithSalt(plainSecret, storedSalt);
    return _constantTimeEquals(computed, storedHash);
  }

  static String _hashWithSalt(String plainSecret, String salt) {
    final bytes = utf8.encode('$salt::$plainSecret');
    return sha256.convert(bytes).toString();
  }

  /// مقارنة بزمن ثابت لمنع هجمات القياس الزمني (timing attacks).
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
