enum Role {
  werewolf, // 狼人
  villager, // 平民
}

extension RoleExtension on Role {
  String get displayName {
    switch (this) {
      case Role.werewolf:
        return '狼人';
      case Role.villager:
        return '平民';
    }
  }
}
