import 'dart:async';
import 'package:intl/intl.dart';

class User {
  static final User _instance = User._internal();
  factory User() => _instance;
  User._internal();

  String _currentUserId = '';
  DateTime? _timestamp;
  final _controller = StreamController<Map<String, String>>.broadcast();

  Map<String, String> get currentData => {
    'userId': _currentUserId,
    'timestamp': formattedTimestamp
  };

  String get currentUserId => _currentUserId;
  String get formattedTimestamp => _timestamp != null 
      ? DateFormat('dd:MM:yyyy\'T\'HH:mm:ss').format(_timestamp!) 
      : '';
  String get currentTimestamp => DateFormat('dd:MM:yyyy\'T\'HH:mm:ss').format(DateTime.now());

  void changeUserId(String newId) {
    _currentUserId = newId;
    _timestamp = DateTime.now();
    _controller.add(currentData);
  }

  Stream<Map<String, String>> get stream => _controller.stream;

  void dispose() {
    _controller.close();
  }
}