import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class YnabApiException implements Exception {
  YnabApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return 'YNAB API request failed ($statusCode): $message';
  }
}

class YnabClient {
  YnabClient(this.token, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String token;
  final http.Client _httpClient;

  static final Uri _baseUri = Uri.parse('https://api.ynab.com/v1');

  Future<List<Map<String, dynamic>>> getAccounts(String planId) async {
    final response = await _get(_endpoint('/budgets/$planId/accounts'));
    final data = _decodeJson(response.body);
    final accounts = data['data']?['accounts'];

    if (accounts is! List) {
      throw YnabApiException('Unexpected accounts response from YNAB.');
    }

    return accounts
        .whereType<Map>()
        .map((account) => Map<String, dynamic>.from(account))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getTransactions(
    String planId,
    String accountId, {
    String? sinceDate,
    String? type,
  }) async {
    final queryParameters = <String, String>{};
    if (sinceDate != null && sinceDate.isNotEmpty) {
      queryParameters['since_date'] = sinceDate;
    }
    if (type != null && type.isNotEmpty) {
      queryParameters['type'] = type;
    }

    final response = await _get(
      _endpoint(
        '/budgets/$planId/accounts/$accountId/transactions',
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      ),
    );
    final data = _decodeJson(response.body);
    final transactions = data['data']?['transactions'];

    if (transactions is! List) {
      throw YnabApiException('Unexpected transactions response from YNAB.');
    }

    return transactions
        .whereType<Map>()
        .map((transaction) => Map<String, dynamic>.from(transaction))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getCategories(String planId) async {
    final response = await _get(_endpoint('/budgets/$planId/categories'));
    final data = _decodeJson(response.body);
    final categoryGroups = data['data']?['category_groups'];

    if (categoryGroups is! List) {
      throw YnabApiException('Unexpected categories response from YNAB.');
    }

    final categories = <Map<String, dynamic>>[];
    for (final group in categoryGroups.whereType<Map>()) {
      final groupName = group['name'];
      final groupCategories = group['categories'];
      if (groupCategories is! List) continue;
      for (final category in groupCategories.whereType<Map>()) {
        categories.add({
          ...Map<String, dynamic>.from(category),
          'category_group_name': groupName,
        });
      }
    }
    return categories;
  }

  Future<Map<String, dynamic>> updateTransaction(
    String planId,
    String transactionId,
    Map<String, dynamic> fields,
  ) async {
    final response = await _put(
      _endpoint('/budgets/$planId/transactions/$transactionId'),
      body: jsonEncode({'transaction': fields}),
    );
    final data = _decodeJson(response.body);
    final transaction = data['data']?['transaction'];

    if (transaction is! Map) {
      throw YnabApiException(
        'Unexpected updated transaction response from YNAB.',
      );
    }

    return Map<String, dynamic>.from(transaction);
  }

  void close() {
    _httpClient.close();
  }

  Uri _endpoint(String path, {Map<String, String>? queryParameters}) {
    return _baseUri.replace(
      path: '${_baseUri.path}$path',
      queryParameters: queryParameters,
    );
  }

  Future<http.Response> _get(Uri uri) {
    return _send(() => _httpClient.get(uri, headers: _headers));
  }

  Future<http.Response> _put(Uri uri, {required String body}) {
    return _send(() => _httpClient.put(uri, headers: _headers, body: body));
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      throw YnabApiException(
        _extractErrorMessage(response.body),
        statusCode: response.statusCode,
      );
    } on SocketException catch (error) {
      throw YnabApiException('Network error: ${error.message}');
    } on http.ClientException catch (error) {
      throw YnabApiException('HTTP client error: ${error.message}');
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      // The server returned a malformed response.
    }

    throw YnabApiException('Could not parse JSON response from YNAB.');
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final detail = error['detail'];
          if (detail is String && detail.isNotEmpty) {
            return detail;
          }

          final name = error['name'];
          if (name is String && name.isNotEmpty) {
            return name;
          }
        }
      }
    } on FormatException {
      // Fall back to the raw response body.
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return 'No error details returned by YNAB.';
    }

    return trimmedBody;
  }

  Map<String, String> get _headers => <String, String>{
    HttpHeaders.authorizationHeader: 'Bearer $token',
    HttpHeaders.acceptHeader: 'application/json',
    HttpHeaders.contentTypeHeader: 'application/json',
  };
}
