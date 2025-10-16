
class UserModel {
  UserModel({
    this.uid,
    this.id,
    this.name,
    this.role,
    this.email
  });
  String? uid;
  String? id;
  String? name;
  String? role;
  String? email;


  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json["uid"] == null ? null : json["uid"],
    id: json["id"] == null ? null : json["id"],
    name: json["name"] == null ? null : json["name"],
    email: json["email"] == null ? null : json["email"],
    role: json["role"] == null ? null : json["role"],
  );

  Map<String, dynamic> toJson() => {
    "id": uid == null ? null : uid,
    "id": id == null ? null : id,
    "name": name == null ? null : name,
    "email": email == null ? null : email,
    "role": role == null ? null : role,
  };
}