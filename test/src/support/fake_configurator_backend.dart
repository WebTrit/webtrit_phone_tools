import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request the fake backend received, kept so a test can assert on what a
/// command actually put on the wire.
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.headers,
  });

  final String method;
  final String path;
  final Map<String, String> headers;

  /// Header value by name, case insensitive; null when it was not sent.
  String? header(String name) => headers[name.toLowerCase()];
}

/// A throwaway HTTP server on the loopback interface that stands in for the
/// configurator backend, so a run can be exercised end to end without touching
/// the real deployment.
///
/// Routes are registered per path; anything else answers 404, which is how a
/// test stops a run at a chosen step.
class FakeConfiguratorBackend {
  FakeConfiguratorBackend._(this._server) {
    unawaited(_serve());
  }

  static Future<FakeConfiguratorBackend> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return FakeConfiguratorBackend._(server);
  }

  final HttpServer _server;
  final List<RecordedRequest> requests = [];
  final Map<String, Future<void> Function(HttpResponse)> _routes = {};

  /// Address to configure a client with. Carries no version segment: callers
  /// append the one the deployment they imitate uses.
  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  /// Answers [path] with [body] encoded as JSON.
  void serveJson(String path, Object? body) {
    _routes[path] = (response) async {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(body));
    };
  }

  /// Answers [path] with [body] verbatim.
  void serveBytes(String path, List<int> body) {
    _routes[path] = (response) async {
      response.headers.contentType = ContentType.binary;
      response.add(body);
    };
  }

  /// The first recorded request for [path], or null when none arrived.
  RecordedRequest? requestFor(String path) {
    for (final request in requests) {
      if (request.path == path) return request;
    }
    return null;
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final request in _server) {
      final headers = <String, String>{};
      request.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.join(', ');
      });
      requests.add(RecordedRequest(
        method: request.method,
        path: request.uri.path,
        headers: headers,
      ));

      final route = _routes[request.uri.path];
      if (route == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        await route(request.response);
      }
      await request.response.close();
    }
  }
}
