// SRS Section 2.3: User Classes - Citizens, Municipal Authorities, System Administrators
enum UserRole { citizen, authority, administrator }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.authority:
        return 'Authority';
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.citizen:
      default:
        return 'Citizen';
    }
  }

  // SRS Section 3.1: RBAC permissions
  bool get canReportIssues => this == UserRole.citizen || this == UserRole.authority;
  bool get canManageIssues => this == UserRole.authority || this == UserRole.administrator;
  bool get canViewAuditLogs => this == UserRole.administrator;
  bool get canManageUsers => this == UserRole.administrator;
}
