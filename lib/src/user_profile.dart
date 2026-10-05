import 'package:equatable/equatable.dart';

final class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.createdAt,
    this.nameConfirmed = true,
  });

  final String uid;
  final String name;
  final String? email;
  final DateTime createdAt;
  final bool nameConfirmed;

  @override
  List<Object?> get props => [uid, name, email, createdAt, nameConfirmed];
}
