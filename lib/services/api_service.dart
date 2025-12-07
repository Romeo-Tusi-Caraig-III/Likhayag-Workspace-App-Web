// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API service for mobile app - Token-based authentication
/// Fixed version with proper token management
class ApiService {
  // ==================== CONFIGURATION ====================
  
  static const String baseUrl = 'http://10.0.2.2:5000';
  static const Duration timeoutDuration = Duration(seconds: 30);
  
  static final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ==================== STATE MANAGEMENT ====================
  
  /// Cached authentication token
  static String? _authToken;
  
  /// Network connectivity status
  static bool _isOnline = true;
  
  /// SharedPreferences key for token storage
  static const String _tokenKey = 'auth_token';
  
  /// Flag to prevent multiple simultaneous loads
  static bool _isLoadingToken = false;

  // ==================== TOKEN MANAGEMENT (FIXED) ====================
  
  /// Load token from persistent storage - SYNCHRONIZED
  static Future<void> _loadToken() async {
    // If already loaded or currently loading, skip
    if (_authToken != null || _isLoadingToken) return;
    
    _isLoadingToken = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      
      if (token != null && token.isNotEmpty) {
        _authToken = token;
        print('📦 Token loaded: ${token.substring(0, min(20, token.length))}...');
      } else {
        print('ℹ️ No saved token found');
      }
    } catch (e) {
      print('❌ Failed to load token: $e');
    } finally {
      _isLoadingToken = false;
    }
  }

  /// Save token to persistent storage - IMMEDIATE
  static Future<void> _saveToken(String token) async {
    try {
      print('💾 Saving token: ${token.substring(0, min(20, token.length))}...');
      
      // Set in memory immediately
      _authToken = token;
      
      // Save to storage
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(_tokenKey, token);
      
      if (saved) {
        print('✅ Token saved successfully');
        
        // Verify it was saved
        final verified = prefs.getString(_tokenKey);
        if (verified == token) {
          print('✅ Token verified in storage');
        } else {
          print('⚠️ Token verification failed!');
        }
      } else {
        print('❌ Failed to save token to storage');
      }
    } catch (e) {
      print('❌ Failed to save token: $e');
    }
  }

  /// Clear token from memory and storage
  static Future<void> clearToken() async {
    try {
      _authToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      print('🗑️ Token cleared');
    } catch (e) {
      print('❌ Failed to clear token: $e');
    }
  }

  /// Get current token (loads if needed)
  static Future<String?> getToken() async {
    if (_authToken == null) {
      await _loadToken();
    }
    return _authToken;
  }

  /// Check if user has valid token
  static Future<bool> hasValidToken() async {
    if (_authToken == null) {
      await _loadToken();
    }
    return _authToken != null && _authToken!.isNotEmpty;
  }

  // ==================== HEADERS (FIXED) ====================
  
  /// Get headers with authentication token if available
  static Future<Map<String, String>> _getHeaders() async {
    // Load token if not in memory
    if (_authToken == null) {
      await _loadToken();
    }
    
    final headers = Map<String, String>.from(_defaultHeaders);
    
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
      print('🔑 Request with token: ${_authToken!.substring(0, min(20, _authToken!.length))}...');
    } else {
      print('⚠️ Request without token - this may fail if auth is required');
    }
    
    return headers;
  }

  // ==================== ERROR HANDLING ====================
  
  static String _getErrorMessage(dynamic error) {
    if (error is SocketException) {
      _isOnline = false;
      return 'No internet connection. Please check your network.';
    } else if (error is TimeoutException) {
      return 'Connection timeout. Please try again.';
    } else if (error is HttpException) {
      return 'Server error. Please try again later.';
    } else if (error is FormatException) {
      return 'Invalid response from server.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    print('📡 Response: $statusCode - Body length: ${response.body.length}');
    
    try {
      final body = response.body.isNotEmpty 
          ? jsonDecode(response.body) 
          : <String, dynamic>{};

      if (statusCode >= 200 && statusCode < 300) {
        _isOnline = true;
        if (body is Map) {
          return Map<String, dynamic>.from(body);
        } else {
          return {'success': true, 'data': body};
        }
      }

      if (statusCode == 401) {
        clearToken();
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
          'requiresAuth': true,
        };
      } else if (statusCode == 403) {
        return {
          'success': false,
          'message': 'Access forbidden. Insufficient permissions.',
        };
      } else if (statusCode == 404) {
        return {
          'success': false,
          'message': 'Resource not found.',
        };
      } else if (statusCode == 409) {
        return body is Map 
            ? Map<String, dynamic>.from(body)
            : {'success': false, 'message': 'Conflict error'};
      } else if (statusCode >= 500) {
        return {
          'success': false,
          'message': 'Server error. Please try again later.',
        };
      }

      if (body is Map) {
        return Map<String, dynamic>.from(body);
      } else {
        return {
          'success': false,
          'message': 'Request failed with status $statusCode',
        };
      }
    } catch (e) {
      print('❌ Response parsing error: $e');
      return {
        'success': false,
        'message': 'Failed to parse server response',
        'statusCode': statusCode,
      };
    }
  }

  /// Extract and save token from response - WAIT for save to complete
  static Future<void> _extractAndSaveToken(Map<String, dynamic> responseBody) async {
    final token = responseBody['token'];
    if (token != null && token.toString().isNotEmpty) {
      await _saveToken(token.toString());
      print('✅ Token extracted and saved from response');
    }
  }

  // ==================== CONNECTIVITY ====================
  
  static Future<bool> checkConnectivity() async {
    try {
      print('🔍 Checking connectivity to $baseUrl...');
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      
      _isOnline = response.statusCode == 200;
      print('${_isOnline ? "✅" : "❌"} Server ${_isOnline ? "online" : "offline"}');
      return _isOnline;
    } catch (e) {
      _isOnline = false;
      print('❌ Connectivity check failed: $e');
      return false;
    }
  }

  static bool get isOnline => _isOnline;

  // ==================== AUTHENTICATION (FIXED) ====================
  
  /// Login with email and password
  static Future<Map<String, dynamic>> login(String email, String password) async {
    // Clear any existing token
    await clearToken();
    
    try {
      print('🔐 Logging in: $email');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/login'),
            headers: _defaultHeaders,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(timeoutDuration);

      print('📡 Login response status: ${response.statusCode}');
      print('📡 Login response body: ${response.body}');
      
      final result = _handleResponse(response);

      // If login successful, extract and save token - WAIT for completion
      if (result['success'] == true) {
        await _extractAndSaveToken(result);
        
        // Verify token was saved by reloading
        _authToken = null; // Clear memory cache
        await _loadToken();
        
        if (_authToken == null || _authToken!.isEmpty) {
          print('❌ CRITICAL: Token not saved properly');
          return {
            'success': false,
            'message': 'Authentication failed. Please try again.',
          };
        }
        
        print('✅ Login successful with token saved and verified');
      } else {
        print('❌ Login failed: ${result['message']}');
      }

      return result;
    } catch (e) {
      print('❌ Login error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Register new user account
  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    try {
      print('📝 Signing up: ${data['email']}');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/signup'),
            headers: _defaultHeaders,
            body: jsonEncode(data),
          )
          .timeout(timeoutDuration);

      final result = _handleResponse(response);

      // If signup successful with verification, save token
      if (result['success'] == true && result.containsKey('token')) {
        await _extractAndSaveToken(result);
        print('✅ Signup successful with auto-login');
      }

      return result;
    } catch (e) {
      print('❌ Signup error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Logout current user
  static Future<Map<String, dynamic>> logout() async {
    try {
      print('👋 Logging out');
      
      final headers = await _getHeaders();
      final response = await http
          .post(Uri.parse('$baseUrl/api/logout'), headers: headers)
          .timeout(timeoutDuration);

      await clearToken();
      
      return _handleResponse(response);
    } catch (e) {
      await clearToken();
      print('ℹ️ Logout completed (with error): $e');
      return {
        'success': true,
        'message': 'Logged out',
      };
    }
  }

  // ==================== TWO-FACTOR AUTHENTICATION ====================
  
  static Future<Map<String, dynamic>> send2FA(String email) async {
    try {
      print('📧 Sending 2FA code to: $email');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/2fa/send'),
            headers: _defaultHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ 2FA send error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> verify2FA(String email, String code) async {
    try {
      print('✅ Verifying 2FA code for: $email');
      
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/2fa/verify'),
            headers: _defaultHeaders,
            body: jsonEncode({
              'email': email,
              'code': code,
            }),
          )
          .timeout(timeoutDuration);

      final result = _handleResponse(response);
      
      if (result['success'] == true) {
        await _extractAndSaveToken(result);
      }

      return result;
    } catch (e) {
      print('❌ 2FA verify error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> resend2FA(String email) async {
    return send2FA(email);
  }

  // ==================== PROFILE ====================
  
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      print('👤 Fetching profile');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/profile'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get profile error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    String section,
    Map<String, dynamic> fields,
  ) async {
    try {
      print('📝 Updating profile section: $section');
      
      final headers = await _getHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/profile'),
            headers: headers,
            body: jsonEncode({
              'section': section,
              'fields': fields,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Update profile error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    try {
      print('📸 Uploading profile picture');
      
      await _loadToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/profile/picture'),
      );

      if (_authToken != null && _authToken!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_authToken';
      }

      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(timeoutDuration);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Upload picture error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== TASKS ====================
  
  static Future<List<dynamic>> getTasks({
    String? search,
    String? filter,
    String? sort,
  }) async {
    try {
      print('📋 Fetching tasks');
      
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (filter != null && filter.isNotEmpty) queryParams['filter'] = filter;
      if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;

      final uri = Uri.parse('$baseUrl/api/tasks').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final tasks = jsonDecode(response.body) as List;
        print('✅ Fetched ${tasks.length} tasks');
        return tasks;
      } else {
        final result = _handleResponse(response);
        print('❌ Get tasks failed: ${result['message']}');
        return [];
      }
    } catch (e) {
      print('❌ Get tasks error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    try {
      print('➕ Creating task: ${taskData['title']}');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/tasks'),
            headers: headers,
            body: jsonEncode(taskData),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Create task error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> updateTask(
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('📝 Updating task: $taskId');
      
      final headers = await _getHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/tasks/$taskId'),
            headers: headers,
            body: jsonEncode(updates),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Update task error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> deleteTask(String taskId) async {
    try {
      print('🗑️ Deleting task: $taskId');
      
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/tasks/$taskId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Delete task error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== MEETINGS ====================
  
  static Future<List<dynamic>> getMeetings() async {
    try {
      print('📅 Fetching meetings');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/meetings'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final meetings = jsonDecode(response.body) as List;
        print('✅ Fetched ${meetings.length} meetings');
        return meetings;
      } else {
        print('❌ Get meetings failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Get meetings error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createMeeting(
    Map<String, dynamic> meetingData,
  ) async {
    try {
      print('➕ Creating meeting: ${meetingData['title']}');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/meetings'),
            headers: headers,
            body: jsonEncode(meetingData),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Create meeting error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> updateMeeting(
    int meetingId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('📝 Updating meeting: $meetingId');
      
      final headers = await _getHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/meetings/$meetingId'),
            headers: headers,
            body: jsonEncode(updates),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Update meeting error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  static Future<Map<String, dynamic>> deleteMeeting(int meetingId) async {
    try {
      print('🗑️ Deleting meeting: $meetingId');
      
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/meetings/$meetingId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Delete meeting error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== BUDGET ====================
  
  static Future<Map<String, dynamic>> getBudgetData() async {
    try {
      print('💰 Fetching budget data');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/budget'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Budget data fetched');
        return data;
      }
      return {
        'categories': [],
        'funds': [],
        'transactions': [],
        'tickets': [],
      };
    } catch (e) {
      print('❌ Get budget error: $e');
      return {
        'categories': [],
        'funds': [],
        'transactions': [],
        'tickets': [],
      };
    }
  }

  static Future<Map<String, dynamic>> createTransaction({
    required String type,
    required String category,
    required String description,
    required double amount,
    required String date,
    File? receiptFile,
  }) async {
    try {
      print('💳 Creating transaction: $description');
      
      await _loadToken();
      
      if (receiptFile != null) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/budget/transactions'),
        );

        if (_authToken != null && _authToken!.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $_authToken';
        }

        request.fields['type'] = type;
        request.fields['category'] = category;
        request.fields['description'] = description;
        request.fields['amount'] = amount.toString();
        request.fields['date'] = date;

        request.files.add(
          await http.MultipartFile.fromPath('receipt', receiptFile.path),
        );

        final streamedResponse = await request.send().timeout(timeoutDuration);
        final response = await http.Response.fromStream(streamedResponse);

        return _handleResponse(response);
      } else {
        final headers = await _getHeaders();
        final response = await http
            .post(
              Uri.parse('$baseUrl/api/budget/transactions'),
              headers: headers,
              body: jsonEncode({
                'type': type,
                'category': category,
                'description': description,
                'amount': amount,
                'date': date,
              }),
            )
            .timeout(timeoutDuration);

        return _handleResponse(response);
      }
    } catch (e) {
      print('❌ Create transaction error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== STUDENTS ====================
  
  /// Get all students
  static Future<List<dynamic>> getStudents() async {
    try {
      print('👥 Fetching students');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/students'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final students = jsonDecode(response.body) as List;
        print('✅ Fetched ${students.length} students');
        return students;
      } else {
        print('❌ Get students failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Get students error: $e');
      return [];
    }
  }

  /// Get budget categories
  static Future<List<dynamic>> getCategories() async {
    try {
      print('📂 Fetching categories');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/budget/categories'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final categories = jsonDecode(response.body) as List;
        print('✅ Fetched ${categories.length} categories');
        return categories;
      }
      return [];
    } catch (e) {
      print('❌ Get categories error: $e');
      return [];
    }
  }

  /// Create budget category
  static Future<Map<String, dynamic>> createCategory(
    String name,
    double budget,
  ) async {
    try {
      print('➕ Creating category: $name');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/budget/categories'),
            headers: headers,
            body: jsonEncode({'name': name, 'budget': budget}),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Create category error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Update budget category
  static Future<Map<String, dynamic>> updateCategory(
    int categoryId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('📝 Updating category: $categoryId');
      
      final headers = await _getHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/budget/categories/$categoryId'),
            headers: headers,
            body: jsonEncode(updates),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Update category error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Delete budget category
  static Future<Map<String, dynamic>> deleteCategory(int categoryId) async {
    try {
      print('🗑️ Deleting category: $categoryId');
      
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/budget/categories/$categoryId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Delete category error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Get transactions with optional date range
  static Future<List<dynamic>> getTransactions({
    String? start,
    String? end,
  }) async {
    try {
      print('💳 Fetching transactions');
      
      final queryParams = <String, String>{};
      if (start != null) queryParams['start'] = start;
      if (end != null) queryParams['end'] = end;

      final uri = Uri.parse('$baseUrl/api/budget/transactions')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final transactions = jsonDecode(response.body) as List;
        print('✅ Fetched ${transactions.length} transactions');
        return transactions;
      }
      return [];
    } catch (e) {
      print('❌ Get transactions error: $e');
      return [];
    }
  }

  /// Delete transaction
  static Future<Map<String, dynamic>> deleteTransaction(int txId) async {
    try {
      print('🗑️ Deleting transaction: $txId');
      
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/budget/transactions/$txId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Delete transaction error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== TICKETS ====================
  
  /// Get all ticket events
  static Future<List<dynamic>> getTickets() async {
    try {
      print('🎫 Fetching tickets');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/budget/tickets'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final tickets = jsonDecode(response.body) as List;
        print('✅ Fetched ${tickets.length} ticket events');
        return tickets;
      }
      return [];
    } catch (e) {
      print('❌ Get tickets error: $e');
      return [];
    }
  }

  /// Create ticket event
  static Future<Map<String, dynamic>> createTicketEvent({
    required String event,
    required double price,
    required int totalTickets,
  }) async {
    try {
      print('➕ Creating ticket event: $event');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/budget/tickets'),
            headers: headers,
            body: jsonEncode({
              'event': event,
              'price': price,
              'total_tickets': totalTickets,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Create ticket event error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Update ticket event
  static Future<Map<String, dynamic>> updateTicketEvent(
    int ticketId,
    Map<String, dynamic> updates,
  ) async {
    try {
      print('📝 Updating ticket event: $ticketId');
      
      final headers = await _getHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/api/budget/tickets/$ticketId'),
            headers: headers,
            body: jsonEncode(updates),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Update ticket event error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Delete ticket event
  static Future<Map<String, dynamic>> deleteTicketEvent(int ticketId) async {
    try {
      print('🗑️ Deleting ticket event: $ticketId');
      
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/budget/tickets/$ticketId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Delete ticket event error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Record ticket sale
  static Future<Map<String, dynamic>> recordTicketSale({
    required int ticketId,
    required String buyer,
    required int qty,
    required String date,
  }) async {
    try {
      print('💰 Recording ticket sale for event: $ticketId');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/budget/tickets/$ticketId/sales'),
            headers: headers,
            body: jsonEncode({
              'buyer': buyer,
              'qty': qty,
              'date': date,
            }),
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Record ticket sale error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== BUDGET ARCHIVES ====================
  
  /// Get budget archives with optional type filter
  static Future<List<dynamic>> getBudgetArchives({String? type}) async {
    try {
      print('📦 Fetching budget archives');
      
      final queryParams = <String, String>{};
      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse('$baseUrl/api/budget/archives')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final archives = jsonDecode(response.body) as List;
        print('✅ Fetched ${archives.length} budget archives');
        return archives;
      }
      return [];
    } catch (e) {
      print('❌ Get budget archives error: $e');
      return [];
    }
  }

  /// Restore budget archive
  static Future<Map<String, dynamic>> restoreBudgetArchive(int archiveId) async {
    try {
      print('♻️ Restoring budget archive: $archiveId');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/budget/archives/$archiveId/restore'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Restore budget archive error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== TASK ARCHIVES ====================
  
  /// Get single task details
  static Future<Map<String, dynamic>> getTask(String taskId) async {
    try {
      print('📋 Fetching task: $taskId');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tasks/$taskId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get task error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Archive task
  static Future<Map<String, dynamic>> archiveTask(String taskId) async {
    try {
      print('📦 Archiving task: $taskId');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/tasks/$taskId/archive'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Archive task error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Get archived tasks
  static Future<List<dynamic>> getArchivedTasks() async {
    try {
      print('📦 Fetching archived tasks');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tasks/archive'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final archives = jsonDecode(response.body) as List;
        print('✅ Fetched ${archives.length} archived tasks');
        return archives;
      }
      return [];
    } catch (e) {
      print('❌ Get archived tasks error: $e');
      return [];
    }
  }

  /// Restore archived task
  static Future<Map<String, dynamic>> restoreArchivedTask(String archiveId) async {
    try {
      print('♻️ Restoring archived task: $archiveId');
      
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/tasks/archive/$archiveId/restore'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Restore task error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// Get task statistics
  static Future<Map<String, dynamic>> getTaskStats() async {
    try {
      print('📊 Fetching task stats');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/tasks/stats'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get task stats error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== MEETINGS DETAILS ====================
  
  /// Get single meeting details
  static Future<Map<String, dynamic>> getMeeting(int meetingId) async {
    try {
      print('📅 Fetching meeting: $meetingId');
      
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/meetings/$meetingId'),
            headers: headers,
          )
          .timeout(timeoutDuration);

      return _handleResponse(response);
    } catch (e) {
      print('❌ Get meeting error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // ==================== UTILITY ====================
  
  static Future<bool> testConnection() async {
    return checkConnectivity();
  }

  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': 'Failed to fetch debug info'};
    } catch (e) {
      return {'error': _getErrorMessage(e)};
    }
  }
}