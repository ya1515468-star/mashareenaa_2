class RoomPermissionsEntity {
  final bool kickMembers;
  final bool muteMembers;
  final bool banMembers;
  final bool unbanMembers;
  final bool assignRoles;
  final bool removeRoles;
  final bool editProfiles;

  const RoomPermissionsEntity({
    this.kickMembers = false,
    this.muteMembers = false,
    this.banMembers = false,
    this.unbanMembers = false,
    this.assignRoles = false,
    this.removeRoles = false,
    this.editProfiles = false,
  });

  factory RoomPermissionsEntity.fromJson(Map<String, dynamic> json) {
    return RoomPermissionsEntity.fromMap(json);
  }

  factory RoomPermissionsEntity.fromMap(Map<String, dynamic> map) {
    return RoomPermissionsEntity(
      kickMembers: map['kick_members'] == true,
      muteMembers: map['mute_members'] == true,
      banMembers: map['ban_members'] == true,
      unbanMembers: map['unban_members'] == true,
      assignRoles: map['assign_roles'] == true,
      removeRoles: map['remove_roles'] == true,
      editProfiles: map['edit_profiles'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'kick_members': kickMembers,
      'mute_members': muteMembers,
      'ban_members': banMembers,
      'unban_members': unbanMembers,
      'assign_roles': assignRoles,
      'remove_roles': removeRoles,
      'edit_profiles': editProfiles,
    };
  }
}
