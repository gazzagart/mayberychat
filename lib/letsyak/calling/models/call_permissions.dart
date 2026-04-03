/// Permission levels for call participants, derived from Matrix room power levels.
enum CallRole {
  /// Room admin (power level >= 100). All permissions.
  admin,

  /// Room moderator (power level >= 50). Can mute/kick others, start recording.
  moderator,

  /// Regular participant. Can only control own media and raise hand.
  participant,
}

/// What actions a [CallRole] is permitted to perform.
class CallPermissions {
  final CallRole role;

  const CallPermissions(this.role);

  bool get canMuteOthers =>
      role == CallRole.admin || role == CallRole.moderator;

  bool get canKickParticipants =>
      role == CallRole.admin || role == CallRole.moderator;

  bool get canStartRecording =>
      role == CallRole.admin || role == CallRole.moderator;

  bool get canStopRecording =>
      role == CallRole.admin || role == CallRole.moderator;

  bool get canLockRoom => role == CallRole.admin || role == CallRole.moderator;

  bool get canGrantScreenShare =>
      role == CallRole.admin || role == CallRole.moderator;

  /// Derive [CallRole] from a Matrix room power level.
  static CallRole roleFromPowerLevel(int powerLevel) {
    if (powerLevel >= 100) return CallRole.admin;
    if (powerLevel >= 50) return CallRole.moderator;
    return CallRole.participant;
  }
}
