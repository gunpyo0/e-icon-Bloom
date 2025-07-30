import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class EcoPost {
  final String id;
  final String description;
  final String? imageUrl;
  final String author;
  final DateTime timestamp;
  final List<EcoReview> reviews;
  
  EcoPost({
    required this.id,
    required this.description,
    this.imageUrl,
    required this.author,
    required this.timestamp,
    this.reviews = const [],
  });
  
  factory EcoPost.fromJson(Map<String, dynamic> json) {
    // 더 안전한 타입 변환
    String? imageUrl;
    try {
      var imageUrlValue = json['imageUrl'];
      if (imageUrlValue != null) {
        imageUrl = imageUrlValue.toString();
      }
    } catch (e) {
      imageUrl = null;
    }
    
    // 안전한 문자열 변환
    String getId(dynamic value) => value?.toString() ?? '';
    String getAuthor(Map<String, dynamic> json) {
      return json['author']?.toString() ?? 
             json['authorName']?.toString() ?? 
             json['uid']?.toString() ??
             'Unknown';
    }
    
    DateTime getTimestamp(Map<String, dynamic> json) {
      try {
        var timestampValue = json['timestamp'] ?? json['createdAt'] ?? json['created_at'];
        if (timestampValue != null) {
          return DateTime.tryParse(timestampValue.toString()) ?? DateTime.now();
        }
      } catch (e) {
        // 파싱 실패 시 현재 시간 반환
      }
      return DateTime.now();
    }
    
    return EcoPost(
      id: getId(json['id']),
      description: json['description']?.toString() ?? '',
      imageUrl: imageUrl,
      author: getAuthor(json),
      timestamp: getTimestamp(json),
      reviews: _parseReviews(json['reviews']),
    );
  }
  
  static List<EcoReview> _parseReviews(dynamic reviewsData) {
    try {
      if (reviewsData is List) {
        return reviewsData
            .where((r) => r is Map<String, dynamic>)
            .map((r) => EcoReview.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // 리뷰 파싱 실패 시 빈 리스트 반환
    }
    return [];
  }
  
  String get title => description.length > 50 
      ? '${description.substring(0, 50)}...' 
      : description;
  
  String get content => description;
  
  double get averageRating {
    if (reviews.isEmpty) return 0.0;
    return reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
  }
  
  // Firebase Storage URL을 다운로드 URL로 변환
  Future<String?> getImageDownloadUrl() async {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    
    // 이미 HTTP URL이면 그대로 반환
    if (imageUrl!.startsWith('http')) return imageUrl;
    
    try {
      // Storage path를 사용해서 다운로드 URL 가져오기
      final ref = FirebaseStorage.instance.ref(imageUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Failed to get download URL for $imageUrl: $e');
      return null;
    }
  }
}

class EcoReview {
  final String id;
  final String reviewer;
  final int rating;
  final String comment;
  final DateTime timestamp;
  
  EcoReview({
    required this.id,
    required this.reviewer,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });
  
  factory EcoReview.fromJson(Map<String, dynamic> json) {
    return EcoReview(
      id: json['id'] ?? '',
      reviewer: json['reviewer'] ?? 'Anonymous',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key});

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  List<EcoPost> _posts = [];
  bool _showCreatePost = false;
  bool _isLoading = true;
  String _currentUserName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPosts();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await EcoBackend.instance.myProfile();
      setState(() {
        _currentUserName = profile['displayName'] ?? 
                          profile['name'] ?? 
                          EcoBackend.instance.currentUser?.displayName ?? 
                          'User';
      });
    } catch (e) {
      // Keep default name if profile loading fails
    }
  }

  Future<void> _loadPosts() async {
    try {
      final postsData = await EcoBackend.instance.allPosts();
      final posts = postsData.map((data) => EcoPost.fromJson(data)).toList();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.green[50],
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _showCreatePost 
                ? _buildCreatePostScreen()
                : _buildPostsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (_showCreatePost)
              GestureDetector(
                onTap: () => setState(() => _showCreatePost = false),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            if (_showCreatePost) const SizedBox(width: 12),
            Icon(
              Icons.eco,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _showCreatePost ? 'work more' : 'work move',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (!_showCreatePost)
              GestureDetector(
                onTap: () => setState(() => _showCreatePost = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Create Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (_showCreatePost)
              const Icon(Icons.close, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_posts.isEmpty) {
      return const Center(
        child: Text(
          'No posts yet. Create the first post!',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return _buildPostCard(post);
        },
      ),
    );
  }

  Widget _buildPostCard(EcoPost post) {
    return GestureDetector(
      onTap: () => _showPostDetail(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Text(
                  post.author[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _formatTime(post.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.reviews.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getScoreColor(post.averageRating),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${post.averageRating.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPostImage(post),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${post.reviews.length} votes',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostScreen() {
    return CreatePostWidget(
      userName: _currentUserName,
      onPostCreated: () async {
        setState(() {
          _showCreatePost = false;
        });
        await _loadPosts(); // Reload posts after creation
      },
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 25) return Colors.green;
    if (score >= 15) return Colors.orange;
    if (score >= 5) return Colors.red;
    return Colors.grey;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildPostImage(EcoPost post) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<String?>(
          future: post.getImageDownloadUrl(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      Text('Failed to load image'),
                    ],
                  ),
                ),
              );
            }
            
            return Image.network(
              snapshot.data!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        Text('Image load failed'),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showPostDetail(EcoPost post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }
}

class CreatePostWidget extends StatefulWidget {
  final String userName;
  final VoidCallback onPostCreated;

  const CreatePostWidget({
    super.key, 
    required this.userName,
    required this.onPostCreated,
  });

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  XFile? _selectedXFile;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedXFile = pickedFile;
        if (!kIsWeb) {
          _selectedImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _createPost() async {
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the description')),
      );
      return;
    }

    try {
      final result = await EcoBackend.instance.createPost(
        description: _descriptionController.text,
        image: _selectedImage,
      );
      
      widget.onPostCreated();
      
      if (mounted) {  
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image upload area
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
            ),
            child: _selectedXFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: kIsWeb
                        ? Image.network(
                            _selectedXFile!.path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Text('Image selected (preview not available on web)'),
                              ),
                            ),
                          )
                        : Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to add photo',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          
          // Upload button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickImage,
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Upload Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Description input
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Create post button
          ElevatedButton(
            onPressed: _createPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Create Post',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final EcoPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  int? _selectedScore;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_selectedScore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a score')),
      );
      return;
    }

    try {
      await EcoBackend.instance.votePost(widget.post.id, _selectedScore!);

      setState(() {
        _selectedScore = null;
        _commentController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote submitted!')),
        );
        Navigator.of(context).pop(); // Go back to main screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit vote: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Post Details'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post content
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'by ${widget.post.author}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.post.content,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildDetailImage(widget.post),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Reviews section
                  Text(
                    'Reviews (${widget.post.reviews.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Review cards
                  ...widget.post.reviews.map((review) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green[100],
                              child: Text(
                                review.reviewer[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              review.reviewer,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getScoreColor(review.rating.toDouble()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${review.rating}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(review.comment),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          ),
          
          // Add review section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vote for this post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Score selection
                Row(
                  children: [0, 10, 20, 30].map((score) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedScore = score),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedScore == score 
                                ? Colors.green[600] 
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$score',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _selectedScore == score 
                                  ? Colors.white 
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Submit Vote',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailImage(EcoPost post) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<String?>(
          future: post.getImageDownloadUrl(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return Container(
                height: 250,
                color: Colors.grey[200],
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      Text('Failed to load image'),
                    ],
                  ),
                ),
              );
            }
            
            return Image.network(
              snapshot.data!,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        Text('Image load failed'),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 25) return Colors.green;
    if (score >= 15) return Colors.orange;
    if (score >= 5) return Colors.red;
    return Colors.grey;
  }
}