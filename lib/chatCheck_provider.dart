import 'package:flutter/material.dart';

class ChatCheckProvider extends ChangeNotifier {
  bool _currentChat = false;

  bool get currentChat => _currentChat;

void setisChat(bool value) {
  _currentChat = value;
  Future.microtask(() {
    notifyListeners();
  });
}


  void clearCurrentpage() {
    _currentChat = false;
    notifyListeners();
  }
}
