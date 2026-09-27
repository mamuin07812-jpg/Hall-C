import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAccount {
  final String email;
  final String password;
  final String name;
  final String role;
  final String uid;

  const SavedAccount({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    required this.uid,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'name': name,
      'role': role,
      'uid': uid,
    };
  }

  factory SavedAccount.fromJson(
      Map<String, dynamic> json,
      ) {
    return SavedAccount(
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      uid: json['uid']?.toString() ?? '',
    );
  }
}

class AccountManager {
  AccountManager._();

  static final AccountManager instance =
  AccountManager._();

  static const String _accountsKey =
      'classroomhub_saved_accounts';

  final FlutterSecureStorage _storage =
  const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<List<SavedAccount>> getAccounts() async {
    try {
      final raw = await _storage.read(
        key: _accountsKey,
      );

      if (raw == null || raw.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => SavedAccount.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .where(
            (account) => account.email.isNotEmpty,
      )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccount(
      SavedAccount account,
      ) async {
    final accounts = await getAccounts();

    final index = accounts.indexWhere(
          (item) =>
      item.email.toLowerCase() ==
          account.email.toLowerCase(),
    );

    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }

    await _writeAccounts(accounts);
  }

  Future<void> removeAccount(
      String email,
      ) async {
    final accounts = await getAccounts();

    accounts.removeWhere(
          (item) =>
      item.email.toLowerCase() ==
          email.toLowerCase(),
    );

    await _writeAccounts(accounts);
  }

  Future<void> clearAccounts() async {
    await _storage.delete(
      key: _accountsKey,
    );
  }

  Future<void> _writeAccounts(
      List<SavedAccount> accounts,
      ) async {
    final encoded = jsonEncode(
      accounts
          .map(
            (account) => account.toJson(),
      )
          .toList(),
    );

    await _storage.write(
      key: _accountsKey,
      value: encoded,
    );
  }
}