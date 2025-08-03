import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bloom/data/services/eco_backend.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key});

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  List<dynamic> _posts = [];
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
      print('=== CURRENT USER PROFILE ===');
      print('Profile data: $profile');
      print('Firebase user: ${EcoBackend.instance.currentUser?.displayName}');
      print('Firebase email: ${EcoBackend.instance.currentUser?.email}');
      print('Firebase UID: ${EcoBackend.instance.currentUser?.uid}');
      print('=============================');
      
      setState(() {
        _currentUserName = profile['displayName'] ?? 
                          profile['name'] ?? 
                          EcoBackend.instance.currentUser?.displayName ?? 
                          EcoBackend.instance.currentUser?.email?.split('@')[0] ??
                          'User';
      });
    } catch (e) {
      print('Profile loading failed: $e');
    }
  }

  Future<String> _getUserDisplayName(String? authorUid, String fallbackName) async {
    if (authorUid == null || authorUid.isEmpty) {
      return fallbackName;
    }
    
    try {
      // 현재 사용자인지 확인
      if (authorUid == EcoBackend.instance.currentUser?.uid) {
        return _currentUserName.isNotEmpty ? _currentUserName : fallbackName;
      }
      
      // 다른 사용자 프로필 가져오기
      final profile = await EcoBackend.instance.anotherProfile(authorUid);
      final displayName = profile['displayName'] ?? profile['name'] ?? fallbackName;
      
      print('Got user profile for $authorUid: $displayName');
      return displayName;
    } catch (e) {
      print('Failed to get user profile for $authorUid: $e');
      return fallbackName;
    }
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await EcoBackend.instance.allPosts();
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
      color: Colors.pink[50],
      child: _showCreatePost 
          ? _buildCreatePostScreen()
          : _buildMainContent(),
    );
  }


  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildMainCard(),
          const SizedBox(height: 16),
          _buildPostsList(),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return GestureDetector(
      onTap: () => setState(() => _showCreatePost = true),
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 200,
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 20,
              top: 20,
              child: Icon(
                Icons.eco,
                color: Colors.white.withOpacity(0.3),
                size: 60,
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(50),
        child: CircularProgressIndicator(),
      );
    }
    
    if (_posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(50),
        child: Text(
          'No posts yet. Create the first post!',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    
    return Column(
      children: _posts.map((post) => _buildPostCard(post)).toList(),
    );
  }

  Widget _buildPostCard(dynamic post) {
    final String author = post['author'] ?? post['authorName'] ?? 'Unknown';
    final String? authorUid = post['authorUid'];
    final String description = post['description'] ?? '';
    final String? imageUrl = post['imageUrl'];
    final String? photoPath = post['photoPath']; // 실제 필드 이름!
    final String postId = post['id'] ?? '';
    
    print('=== POST DATA DEBUG ===');
    print('Post ID: $postId');
    print('Author: $author');  
    print('AuthorUid: $authorUid');
    print('Description: $description');
    print('ImageURL: $imageUrl');
    print('PhotoPath: $photoPath'); // 이게 실제 이미지 경로!
    print('========================');
    
    return GestureDetector(
      onTap: () => _showPostDetail(post),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // photoPath가 있으면 사용 (실제 Firebase Storage 경로)
            if ((imageUrl != null && imageUrl.isNotEmpty) || (photoPath != null && photoPath.isNotEmpty)) ...[
              _buildPostImage(imageUrl ?? photoPath!),
            ] else ...[
              // 정말로 이미지가 없을 때만 표시  
              Container(
                height: 100,
                color: Colors.grey[800],
                child: Center(
                  child: Text(
                    'No image data found',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  FutureBuilder<String>(
                    future: _getUserDisplayName(authorUid, author),
                    builder: (context, snapshot) {
                      final displayName = snapshot.data ?? author;
                      return _buildUserAvatar(displayName);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String>(
                          future: _getUserDisplayName(authorUid, author),
                          builder: (context, snapshot) {
                            final displayName = snapshot.data ?? author;
                            return Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String author) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[600],
      child: Text(
        author.isNotEmpty ? author[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildPostImage(String imageUrlOrPath) {
    print('_buildPostImage called with: $imageUrlOrPath');
    
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: FutureBuilder<String?>(
          future: _getImageDownloadUrl(imageUrlOrPath),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                color: Colors.grey[800],
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }
            
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return Container(
                height: 200,
                color: Colors.grey[800],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Image failed to load',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
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
                  color: Colors.grey[800],
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Image load error: $error');
                return Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white54,
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

  Future<String?> _getImageDownloadUrl(String imageUrlOrPath) async {
    print('=== IMAGE URL PROCESSING ===');
    print('Input: $imageUrlOrPath');
    
    if (imageUrlOrPath.isEmpty) {
      print('Empty input, returning null');
      return null;
    }
    
    // 이미 HTTP URL이면 그대로 반환
    if (imageUrlOrPath.startsWith('http')) {
      print('Already HTTP URL, returning as-is');
      return imageUrlOrPath;
    }
    
    try {
      // Firebase Storage path를 사용해서 다운로드 URL 가져오기
      print('Trying to get download URL from Storage path: $imageUrlOrPath');
      final ref = FirebaseStorage.instance.ref(imageUrlOrPath);
      final downloadUrl = await ref.getDownloadURL();
      print('Successfully got download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Failed to get download URL for $imageUrlOrPath: $e');
      return null;
    }
  }


  Widget _buildCreatePostScreen() {
    return CreatePostWidget(
      userName: _currentUserName,
      onPostCreated: () async {
        setState(() {
          _showCreatePost = false;
        });
        await _loadPosts();
      },
      onBack: () => setState(() => _showCreatePost = false),
    );
  }

  void _showPostDetail(dynamic post) {
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
  final VoidCallback? onBack;

  const CreatePostWidget({
    super.key, 
    required this.userName,
    required this.onPostCreated,
    this.onBack,
  });

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  XFile? _selectedXFile;
  final _picker = ImagePicker();
  bool _isCreating = false;

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

    // 이미지는 선택사항으로 변경 (테스트용)
    // if (_selectedXFile == null && _selectedImage == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     const SnackBar(content: Text('Please select an image')),
    //   );
    //   return;
    // }

    setState(() {
      _isCreating = true;
    });

    try {
      File? imageFile;
      
      if (_selectedXFile != null) {
        try {
          final bytes = await _selectedXFile!.readAsBytes();
          print('Selected image: ${_selectedXFile!.name}, size: ${bytes.length} bytes');
          
          if (kIsWeb) {
            // 웹에서는 XFile을 그대로 File로 변환
            imageFile = File(_selectedXFile!.path);
            print('Web: Using XFile as File: ${imageFile.path}');
          } else {
            // 모바일에서는 _selectedImage 사용
            imageFile = _selectedImage;
            print('Mobile: Using converted File');
          }
        } catch (e) {
          print('Error processing selected image: $e');
        }
      } else if (_selectedImage != null) {
        imageFile = _selectedImage;
        print('Using direct File: ${imageFile?.path}');
      }

      print('Creating post with description: ${_descriptionController.text}');
      print('Image file: $imageFile');

      if (kIsWeb && _selectedXFile != null) {
        // 웹에서는 직접 Firebase Functions와 Storage 사용
        print('Web: Using direct Firebase approach');
        
        final bytes = await _selectedXFile!.readAsBytes();
        
        // 1단계: Cloud Function 호출해서 포스트 생성 + storage path 받기
        final createResult = await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
            .httpsCallable('createPost')
            .call({'description': _descriptionController.text, 'extension': 'jpg'});
            
        final postId = createResult.data['postId'] as String;
        final storagePath = createResult.data['storagePath'] as String;
        
        print('Web: Post created - ID: $postId, Storage: $storagePath');
        
        // 2단계: Storage에 직접 업로드
        await FirebaseStorage.instance.ref(storagePath).putData(bytes);
        
        print('Web: Image uploaded successfully');
        
      } else {
        // 모바일에서는 기존 방식
        await EcoBackend.instance.createPost(
          description: _descriptionController.text,
          image: imageFile,
        );
      }
      
      print('Post created successfully');
      
      widget.onPostCreated();
      
      if (mounted) {  
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }
    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
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
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Create New Post',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
            child: _selectedXFile != null || _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: kIsWeb && _selectedXFile != null
                        ? FutureBuilder<Uint8List>(
                            future: _selectedXFile!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 250,
                                );
                              }
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                          )
                        : _selectedImage != null
                            ? Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 250,
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Text('Image selected'),
                                ),
                              ),
                  )
                : InkWell(
                    onTap: _pickImage,
                    child: Column(
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
          ),
          const SizedBox(height: 16),
          
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
          
          ElevatedButton(
            onPressed: _isCreating ? null : _createPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isCreating
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
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
  final dynamic post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  int? _selectedScore;
  bool _isVoting = false;

  Future<String> _getUserDisplayName(String? authorUid, String fallbackName) async {
    if (authorUid == null || authorUid.isEmpty) {
      return fallbackName;
    }
    
    try {
      // 현재 사용자인지 확인
      if (authorUid == EcoBackend.instance.currentUser?.uid) {
        final profile = await EcoBackend.instance.myProfile();
        return profile['displayName'] ?? 
               profile['name'] ?? 
               EcoBackend.instance.currentUser?.displayName ?? 
               EcoBackend.instance.currentUser?.email?.split('@')[0] ??
               fallbackName;
      }
      
      // 다른 사용자 프로필 가져오기
      final profile = await EcoBackend.instance.anotherProfile(authorUid);
      final displayName = profile['displayName'] ?? profile['name'] ?? fallbackName;
      
      print('Got user profile for $authorUid: $displayName');
      return displayName;
    } catch (e) {
      print('Failed to get user profile for $authorUid: $e');
      return fallbackName;
    }
  }

  Future<void> _submitVote() async {
    if (_selectedScore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a score')),
      );
      return;
    }

    setState(() {
      _isVoting = true;
    });

    try {
      await EcoBackend.instance.votePost(widget.post['id'], _selectedScore!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vote submitted!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit vote: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String author = widget.post['author'] ?? widget.post['authorName'] ?? 'Unknown';
    final String? authorUid = widget.post['authorUid'];
    final String description = widget.post['description'] ?? '';
    final String? imageUrl = widget.post['imageUrl'];
    final String? photoPath = widget.post['photoPath']; // 실제 이미지 경로

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Post Details'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        FutureBuilder<String>(
                          future: _getUserDisplayName(authorUid, author),
                          builder: (context, snapshot) {
                            final displayName = snapshot.data ?? author;
                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.green[100],
                                  child: Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if ((imageUrl != null && imageUrl.isNotEmpty) || (photoPath != null && photoPath.isNotEmpty)) ...[
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _showImagePreview(imageUrl ?? photoPath!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<String?>(
                                future: _getImageDownloadUrl(imageUrl ?? photoPath!),
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
                                        child: Icon(Icons.broken_image, size: 64),
                                      ),
                                    );
                                  }
                                  
                                  return Image.network(
                                    snapshot.data!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 200,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: Icon(Icons.broken_image, size: 64),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
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
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVoting ? null : _submitVote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isVoting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
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

  Future<String?> _getImageDownloadUrl(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    
    if (imageUrl.startsWith('http')) return imageUrl;
    
    try {
      final ref = FirebaseStorage.instance.ref(imageUrl);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Failed to get download URL for $imageUrl: $e');
      return null;
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: FutureBuilder<String?>(
                      future: _getImageDownloadUrl(imageUrl),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator(color: Colors.white);
                        }
                        
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 64, color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          );
                        }
                        return InteractiveViewer(
                          child: Image.network(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 64, color: Colors.white),
                                  SizedBox(height: 16),
                                  Text(
                                    'Image load failed',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}