// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your Flask server URL
static const String baseUrl = 'http://10.0.2.2:5000';
  
  static Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Store session cookie
  static String? _sessionCookie;

  static Future<void> _loadSession() async {
    if (_sessionCookie != null) return;
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('session_cookie');
  }

  static Future<void> _saveSession(String cookie) async {
    _sessionCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_cookie', cookie);
  }

  static Future<void> clearSession() async {
    _sessionCookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
  }

  static Map<String, String> _getHeaders() {
    final headers = Map<String, String>.from(_headers);
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  static void _extractAndSaveCookie(http.Response response) {
    final cookie = response.headers['set-cookie'];
    if (cookie != null && cookie.isNotEmpty) {
      _saveSession(cookie);
    }
  }

  // ==================== AUTH ====================
  
  static Future<Map<String, dynamic>> login(String email, String password) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: _getHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      _extractAndSaveCookie(response);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/signup'),
        headers: _headers,
        body: jsonEncode(data),
      );

      _extractAndSaveCookie(response);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/logout'),
        headers: _getHeaders(),
      );
      
      await clearSession();
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== 2FA ====================
  
  static Future<Map<String, dynamic>> send2FA(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/2fa/send'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verify2FA(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/2fa/verify'),
        headers: _headers,
        body: jsonEncode({'email': email, 'code': code}),
      );

      _extractAndSaveCookie(response);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== PROFILE ====================
  
  static Future<Map<String, dynamic>> getProfile() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/profile'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to load profile'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    String section, 
    Map<String, dynamic> fields
  ) async {
    await _loadSession();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/profile'),
        headers: _getHeaders(),
        body: jsonEncode({'section': section, 'fields': fields}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword(
    String newPassword, 
    String confirmPassword
  ) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/profile/password'),
        headers: _getHeaders(),
        body: jsonEncode({
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadProfilePicture(File imageFile) async {
    await _loadSession();
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/profile/picture'),
      );

      if (_sessionCookie != null) {
        request.headers['Cookie'] = _sessionCookie!;
      }

      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== TASKS ====================
  
  static Future<List<dynamic>> getTasks({
    String? search,
    String? filter,
    String? sort,
  }) async {
    await _loadSession();
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (filter != null && filter.isNotEmpty) queryParams['filter'] = filter;
      if (sort != null && sort.isNotEmpty) queryParams['sort'] = sort;

      final uri = Uri.parse('$baseUrl/api/tasks').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      print('Get tasks error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks'),
        headers: _getHeaders(),
        body: jsonEncode(taskData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateTask(String taskId, Map<String, dynamic> updates) async {
    await _loadSession();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/tasks/$taskId'),
        headers: _getHeaders(),
        body: jsonEncode(updates),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteTask(String taskId) async {
    await _loadSession();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tasks/$taskId'),
        headers: _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> archiveTask(String taskId) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks/$taskId/archive'),
        headers: _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<dynamic>> getArchivedTasks() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks/archive'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> restoreArchivedTask(String archiveId) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks/archive/$archiveId/restore'),
        headers: _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== MEETINGS ====================
  
  static Future<List<dynamic>> getMeetings() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/meetings'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createMeeting(Map<String, dynamic> meetingData) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/meetings'),
        headers: _getHeaders(),
        body: jsonEncode(meetingData),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateMeeting(int meetingId, Map<String, dynamic> updates) async {
    await _loadSession();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/meetings/$meetingId'),
        headers: _getHeaders(),
        body: jsonEncode(updates),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteMeeting(int meetingId) async {
    await _loadSession();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/meetings/$meetingId'),
        headers: _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== BUDGET ====================
  
  static Future<Map<String, dynamic>> getBudgetData() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/budget'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'categories': [], 'funds': [], 'transactions': [], 'tickets': []};
    } catch (e) {
      return {'categories': [], 'funds': [], 'transactions': [], 'tickets': []};
    }
  }

  static Future<List<dynamic>> getCategories() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/budget/categories'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createCategory(String name, double budget) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/budget/categories'),
        headers: _getHeaders(),
        body: jsonEncode({'name': name, 'budget': budget}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<List<dynamic>> getTransactions({String? start, String? end}) async {
    await _loadSession();
    try {
      final queryParams = <String, String>{};
      if (start != null) queryParams['start'] = start;
      if (end != null) queryParams['end'] = end;

      final uri = Uri.parse('$baseUrl/api/budget/transactions')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createTransaction({
    required String type,
    required String category,
    required String description,
    required double amount,
    required String date,
    File? receiptFile,
    String? receiptBase64,
  }) async {
    await _loadSession();
    try {
      if (receiptFile != null) {
        // Use multipart for file upload
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/budget/transactions'),
        );

        if (_sessionCookie != null) {
          request.headers['Cookie'] = _sessionCookie!;
        }

        request.fields['type'] = type;
        request.fields['category'] = category;
        request.fields['description'] = description;
        request.fields['amount'] = amount.toString();
        request.fields['date'] = date;

        request.files.add(
          await http.MultipartFile.fromPath('receipt', receiptFile.path),
        );

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        return jsonDecode(response.body);
      } else {
        // Use JSON with base64
        final response = await http.post(
          Uri.parse('$baseUrl/api/budget/transactions'),
          headers: _getHeaders(),
          body: jsonEncode({
            'type': type,
            'category': category,
            'description': description,
            'amount': amount,
            'date': date,
            'receipt_data_base64': receiptBase64 ?? '',
          }),
        );

        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteTransaction(int txId) async {
    await _loadSession();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/budget/transactions/$txId'),
        headers: _getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== TICKETS ====================
  
  static Future<List<dynamic>> getTickets() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/budget/tickets'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createTicketEvent({
    required String event,
    required double price,
    required int totalTickets,
  }) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/budget/tickets'),
        headers: _getHeaders(),
        body: jsonEncode({
          'event': event,
          'price': price,
          'total_tickets': totalTickets,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> recordTicketSale({
    required int ticketId,
    required String buyer,
    required int qty,
    required String date,
  }) async {
    await _loadSession();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/budget/tickets/$ticketId/sales'),
        headers: _getHeaders(),
        body: jsonEncode({
          'buyer': buyer,
          'qty': qty,
          'date': date,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== STUDENTS ====================
  
  static Future<List<dynamic>> getStudents() async {
    await _loadSession();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/students'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}