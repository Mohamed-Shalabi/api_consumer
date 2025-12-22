final class Post {
  const Post({
    required this.userId,
    required this.id,
    required this.title,
    required this.body,
  });

  final int userId;
  final int id;
  final String title;
  final String body;

  static Post fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return Post(
      userId: (map['userId'] as num?)?.toInt() ?? 0,
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'id': id, 'title': title, 'body': body};
  }
}

final class PostCreateRequest {
  const PostCreateRequest({
    required this.userId,
    required this.title,
    required this.body,
  });

  final int userId;
  final String title;
  final String body;

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'title': title, 'body': body};
  }
}

final class PostUpdateRequest {
  const PostUpdateRequest({required this.title, required this.body});

  final String title;
  final String body;

  Map<String, dynamic> toJson() {
    return {'title': title, 'body': body};
  }
}
