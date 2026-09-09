import 'dart:convert';

class Student {
  final String id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String studentNumber;
  final String year;
  final String program;

  Student({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.studentNumber,
    required this.year,
    required this.program,
  });

  String get fullName => middleName.isEmpty
      ? '$firstName $lastName'
      : '$firstName $middleName $lastName';
  String get fileName => id;
  String get info => program;

  String toJsonString() => jsonEncode({
    'id': id,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'studentNumber': studentNumber,
    'year': year,
    'program': program,
  });

  factory Student.fromJsonString(String jsonString) {
    final map = jsonDecode(jsonString);
    return Student.fromMap(map);
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'studentNumber': studentNumber,
    'year': year,
    'program': program,
  };

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      firstName: map['firstName'],
      middleName: map['middleName'],
      lastName: map['lastName'],
      studentNumber: map['studentNumber'] ?? '',
      year: map['year'],
      program: map['program'],
    );
  }
}
