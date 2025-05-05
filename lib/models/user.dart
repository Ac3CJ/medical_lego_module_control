import 'dart:async';
import 'package:intl/intl.dart';

class User {
  static final User _instance = User._internal();
  factory User() => _instance;
  User._internal();

  String _currentUserId = '';
  DateTime? _timestamp;
  final _controller = StreamController<Map<String, String>>.broadcast();

  String get currentUserId => _currentUserId;
  String get formattedTimestamp => _timestamp != null 
      ? DateFormat('dd:MM:yyyy\'T\'HH:mm:ss').format(_timestamp!) 
      : '';

  void setUserId(String newId) {
    _currentUserId = newId;
    _timestamp = DateTime.now();
    _controller.add({
      'userId': _currentUserId,
      'timestamp': formattedTimestamp
    });
  }

  Stream<Map<String, String>> get stream => _controller.stream;

  void dispose() {
    _controller.close();
  }
}