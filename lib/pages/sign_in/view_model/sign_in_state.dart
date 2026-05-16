import 'package:fluffychat/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:flutter/material.dart';

class SignInState {
  final PublicHomeserverData? selectedHomeserver;
  final AsyncSnapshot<List<PublicHomeserverData>> publicHomeservers;
  final List<PublicHomeserverData> filteredPublicHomeservers;
  final AsyncSnapshot<bool> loginLoading;

  const SignInState({
    this.selectedHomeserver,
    this.publicHomeservers = const AsyncSnapshot.nothing(),
    this.loginLoading = const AsyncSnapshot.nothing(),
    this.filteredPublicHomeservers = const [],
  });

  static const _keepSelectedHomeserver = Object();

  SignInState copyWith({
    Object? selectedHomeserver = _keepSelectedHomeserver,
    AsyncSnapshot<List<PublicHomeserverData>>? publicHomeservers,
    AsyncSnapshot<bool>? loginLoading,
    List<PublicHomeserverData>? filteredPublicHomeservers,
  }) {
    return SignInState(
      selectedHomeserver: identical(selectedHomeserver, _keepSelectedHomeserver)
          ? this.selectedHomeserver
          : selectedHomeserver as PublicHomeserverData?,
      publicHomeservers: publicHomeservers ?? this.publicHomeservers,
      loginLoading: loginLoading ?? this.loginLoading,
      filteredPublicHomeservers:
          filteredPublicHomeservers ?? this.filteredPublicHomeservers,
    );
  }
}
