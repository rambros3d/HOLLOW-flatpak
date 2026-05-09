import 'dart:convert';
import 'dart:io';

class RelayStatus {
  final bool licenseRequired;
  const RelayStatus({this.licenseRequired = false});
}

Future<RelayStatus> fetchRelayStatus({required String domain}) async {
  try {
    final url = 'https://$domain/relay-status';
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode != 200) {
      return const RelayStatus();
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return RelayStatus(
      licenseRequired: json['license_required'] == true,
    );
  } catch (_) {
    return const RelayStatus();
  }
}
