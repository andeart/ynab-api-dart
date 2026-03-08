import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:ynab_api_dart/ynab_client.dart';

void main() {
  group('YnabApiException', () {
    test('includes the status code when present', () {
      final exception = YnabApiException('Budget not found', statusCode: 404);

      expect(
        exception.toString(),
        'YNAB API request failed (404): Budget not found',
      );
    });

    test('returns only the message when no status code is present', () {
      final exception = YnabApiException('Network error');

      expect(exception.toString(), 'Network error');
    });
  });

  group('YnabClient', () {
    test('getAccounts parses account rows and sends headers', () async {
      late http.Request request;
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((incomingRequest) async {
          request = incomingRequest;
          return http.Response(
            jsonEncode({
              'data': {
                'accounts': [
                  {
                    'id': 'account-1',
                    'name': 'Checking',
                    'type': 'checking',
                    'balance': 1500,
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final accounts = await client.getAccounts('plan-123');

      expect(accounts, hasLength(1));
      expect(accounts.single['name'], 'Checking');
      expect(
        request.url.toString(),
        'https://api.ynab.com/v1/budgets/plan-123/accounts',
      );
      expect(
        request.headers[HttpHeaders.authorizationHeader],
        'Bearer test-token',
      );
      expect(request.headers[HttpHeaders.acceptHeader], 'application/json');

      client.close();
    });

    test('getAccounts throws on an unexpected response shape', () async {
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'data': {'accounts': {}},
            }),
            200,
          );
        }),
      );

      await expectLater(
        client.getAccounts('plan-123'),
        throwsA(
          isA<YnabApiException>().having(
            (error) => error.message,
            'message',
            'Unexpected accounts response from YNAB.',
          ),
        ),
      );

      client.close();
    });

    test('getTransactions includes optional query parameters', () async {
      late http.Request request;
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((incomingRequest) async {
          request = incomingRequest;
          return http.Response(
            jsonEncode({
              'data': {
                'transactions': [
                  {'id': 'txn-1', 'date': '2026-03-01', 'amount': -1200},
                ],
              },
            }),
            200,
          );
        }),
      );

      final transactions = await client.getTransactions(
        'plan-123',
        'account-456',
        sinceDate: '2026-03-01',
        type: 'uncategorized',
      );

      expect(transactions, hasLength(1));
      expect(
        request.url.toString(),
        'https://api.ynab.com/v1/budgets/plan-123/accounts/account-456/transactions'
        '?since_date=2026-03-01&type=uncategorized',
      );

      client.close();
    });

    test('getTransactions throws on an unexpected response shape', () async {
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'data': {'transactions': {}},
            }),
            200,
          );
        }),
      );

      await expectLater(
        client.getTransactions('plan-123', 'account-456'),
        throwsA(
          isA<YnabApiException>().having(
            (error) => error.message,
            'message',
            'Unexpected transactions response from YNAB.',
          ),
        ),
      );

      client.close();
    });

    test('updateTransaction wraps fields in a transaction payload', () async {
      late http.Request request;
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((incomingRequest) async {
          request = incomingRequest;
          return http.Response(
            jsonEncode({
              'data': {
                'transaction': {
                  'id': 'txn-1',
                  'date': '2026-03-01',
                  'amount': -1200,
                },
              },
            }),
            200,
          );
        }),
      );

      final transaction = await client.updateTransaction('plan-123', 'txn-1', {
        'memo': 'Updated memo',
        'approved': true,
      });

      expect(request.method, 'PUT');
      expect(
        request.url.toString(),
        'https://api.ynab.com/v1/budgets/plan-123/transactions/txn-1',
      );
      expect(jsonDecode(request.body), {
        'transaction': {'memo': 'Updated memo', 'approved': true},
      });
      expect(transaction['id'], 'txn-1');

      client.close();
    });

    test('updateTransaction throws on an unexpected response shape', () async {
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'data': {'transaction': []},
            }),
            200,
          );
        }),
      );

      await expectLater(
        client.updateTransaction('plan-123', 'txn-1', {'memo': 'test'}),
        throwsA(
          isA<YnabApiException>().having(
            (error) => error.message,
            'message',
            'Unexpected updated transaction response from YNAB.',
          ),
        ),
      );

      client.close();
    });

    test('throws an API exception with parsed error detail', () async {
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((_) async {
          return http.Response(
            jsonEncode({
              'error': {'detail': 'Budget not found'},
            }),
            404,
          );
        }),
      );

      await expectLater(
        client.getAccounts('missing-plan'),
        throwsA(
          isA<YnabApiException>()
              .having((error) => error.message, 'message', 'Budget not found')
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );

      client.close();
    });

    test(
      'falls back to a default error message for an empty error body',
      () async {
        final client = YnabClient(
          'test-token',
          httpClient: MockClient((_) async => http.Response('   ', 500)),
        );

        await expectLater(
          client.getAccounts('plan-123'),
          throwsA(
            isA<YnabApiException>().having(
              (error) => error.message,
              'message',
              'No error details returned by YNAB.',
            ),
          ),
        );

        client.close();
      },
    );

    test('converts client exceptions into YNAB API exceptions', () async {
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((_) async {
          throw http.ClientException('Connection reset');
        }),
      );

      await expectLater(
        client.getAccounts('plan-123'),
        throwsA(
          isA<YnabApiException>().having(
            (error) => error.message,
            'message',
            'HTTP client error: Connection reset',
          ),
        ),
      );

      client.close();
    });

    test('converts socket exceptions into YNAB API exceptions', () async {
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((_) async {
          throw const SocketException('Connection refused');
        }),
      );

      await expectLater(
        client.getAccounts('plan-123'),
        throwsA(
          isA<YnabApiException>().having(
            (error) => error.message,
            'message',
            'Network error: Connection refused',
          ),
        ),
      );

      client.close();
    });

    test('throws when a success response contains malformed JSON', () async {
      final client = YnabClient(
        'test-token',
        httpClient: MockClient((_) async => http.Response('not json', 200)),
      );

      await expectLater(
        client.getAccounts('plan-123'),
        throwsA(
          isA<YnabApiException>().having(
            (error) => error.message,
            'message',
            'Could not parse JSON response from YNAB.',
          ),
        ),
      );

      client.close();
    });
  });
}
