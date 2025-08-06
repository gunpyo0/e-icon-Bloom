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
      color: Color.fromRGBO(244, 234, 225, 1),
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

class _PostDetailScreenState extends State<PostDetailScreen> 
    with TickerProviderStateMixin {
  int? _selectedScore;
  bool _isVoting = false;
  
  // AI 평가 애니메이션 관련
  List<AnimationController> _animationControllers = [];
  List<Animation<double>> _fadeAnimations = [];
  List<Animation<Offset>> _slideAnimations = [];
  int _currentAISpeaking = -1;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAIEvaluationSequence();
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeAnimations() {
    // 기존 컨트롤러들 정리
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    _animationControllers.clear();
    _fadeAnimations.clear();
    _slideAnimations.clear();
    
    // evaluations 데이터 확인
    final evaluations = widget.post['evaluations'];
    int aiCount = 0;
    
    if (evaluations != null && evaluations.isNotEmpty) {
      // 실제 evaluations 개수 계산
      aiCount = evaluations.keys.where((key) => 
        ['balanced', 'critical', 'supportive'].contains(key) && 
        evaluations[key] != null && 
        evaluations[key].toString().isNotEmpty
      ).length;
    }
    
    // 최소 1개, 최대 3개로 제한
    aiCount = aiCount.clamp(1, 3);
    
    // AI 개수에 맞게 애니메이션 컨트롤러 생성
    for (int i = 0; i < aiCount; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      
      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));

      final slideAnimation = Tween<Offset>(
        begin: const Offset(-0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutBack,
      ));

      _animationControllers.add(controller);
      _fadeAnimations.add(fadeAnimation);
      _slideAnimations.add(slideAnimation);
    }
  }

  void _startAIEvaluationSequence() async {
    // 0.5초 후에 AI 평가 시작
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 실제 애니메이션 컨트롤러 개수만큼 반복
    for (int i = 0; i < _animationControllers.length; i++) {
      if (mounted) {
        setState(() {
          _currentAISpeaking = i;
        });
        _animationControllers[i].forward();
        await Future.delayed(const Duration(milliseconds: 800)); // 각 AI마다 0.8초 간격
      }
    }
    
    // 모든 AI가 말을 마친 후
    if (mounted) {
      setState(() {
        _currentAISpeaking = -1;
      });
    }
  }

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
      backgroundColor: Color.fromRGBO(244, 234, 225, 1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Post Details'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // 새로고침 시 evaluations 데이터 다시 확인
                try {
                  // 포스트 데이터를 다시 가져와서 evaluations 업데이트 확인
                  final updatedPost = await EcoBackend.instance.getPostById(widget.post['id']);
                  if (mounted) {
                    setState(() {
                      // 업데이트된 포스트 데이터로 교체
                      widget.post.addAll(updatedPost);
                    });
                    
                    // 애니메이션 다시 초기화 및 시작
                    _initializeAnimations();
                    _startAIEvaluationSequence();
                    
                    // 새로고침 완료 알림
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('새로고침 완료!'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Refresh error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('새로고침 실패: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
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
                          // AI 평가 섹션 추가
                          const SizedBox(height: 24),
                          _buildAIEvaluationSection(context),
                        ],
                      ),
                    ),
                  ],
                ),
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

  Widget _buildAIEvaluationSection(BuildContext context) {
    // evaluations 데이터 확인
    final evaluations = widget.post['evaluations'];
    
    // 디버깅 로그 추가
    print('=== EVALUATIONS DEBUG ===');
    print('Post ID: ${widget.post['id']}');
    print('Evaluations: $evaluations');
    if (evaluations != null) {
      evaluations.forEach((key, value) {
        print('$key: $value');
      });
    }
    print('========================');
    
    // evaluations가 없거나 null이면 섹션을 숨김
    if (evaluations == null || evaluations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Expert Evaluation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        _buildAIEvaluators(),
      ],
    );
  }

  Widget _buildAIEvaluators() {
    final evaluations = widget.post['evaluations'];
    
    // evaluations가 없으면 빈 컨테이너 반환
    if (evaluations == null || evaluations.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // AI 평가자 정보 정의
    final aiConfigs = {
      'balanced': {
        'name': 'EcoGPT',
        'icon': Icons.eco,
        'color': Colors.green,
        'personality': 'Balanced & Analytical'
      },
      'critical': {
        'name': 'Dr. Critical',
        'icon': Icons.psychology,
        'color': Colors.red,
        'personality': 'Cynical & Critical'
      },
      'supportive': {
        'name': 'Prof. Bright',
        'icon': Icons.lightbulb,
        'color': Colors.amber,
        'personality': 'Positive & Supportive'
      },
    };
    
    // evaluations에서 실제 AI 평가 텍스트 추출
    final List<Map<String, dynamic>> aiEvaluations = [];
    
    evaluations.forEach((key, value) {
      if (aiConfigs.containsKey(key) && value != null && value.toString().isNotEmpty) {
        aiEvaluations.add({
          'type': key,
          'evaluation': value.toString(),
          'name': aiConfigs[key]!['name'],
          'icon': aiConfigs[key]!['icon'],
          'color': aiConfigs[key]!['color'],
          'personality': aiConfigs[key]!['personality'],
        });
      }
    });
    
    // 평가가 없으면 빈 컨테이너 반환
    if (aiEvaluations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: aiEvaluations.asMap().entries.map((entry) {
        final index = entry.key;
        final ai = entry.value;
        
        return Padding(
          padding: EdgeInsets.only(bottom: index < aiEvaluations.length - 1 ? 12 : 0),
          child: AnimatedBuilder(
            animation: _animationControllers[index],
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnimations[index],
                child: FadeTransition(
                  opacity: _fadeAnimations[index],
                  child: _buildAnimatedAIEvaluator(
                    ai['name'] as String,
                    ai['icon'] as IconData,
                    ai['color'] as Color,
                    ai['evaluation'] as String,
                    ai['personality'] as String,
                    index,
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnimatedAIEvaluator(String name, IconData icon, Color color, String evaluation, String personality, int index) {
    final isSpeaking = _currentAISpeaking == index;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSpeaking ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSpeaking ? color : color.withOpacity(0.3),
          width: isSpeaking ? 2 : 1,
        ),
        boxShadow: isSpeaking ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        if (isSpeaking) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Speaking...',
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      personality,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: AnimatedOpacity(
              opacity: _animationControllers[index].isCompleted ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 500),
              child: Text(
                evaluation,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: _animationControllers[index].isCompleted ? Colors.black : Colors.grey,
                ),
              ),
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