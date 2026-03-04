import "package:dio/dio.dart";

import "models.dart";

class EventsApi {
  EventsApi(this._dio);

  final Dio _dio;

  Future<PaginatedResponse<EventDto>> list({
    String? query,
    List<String>? types,
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      "limit": limit,
      "offset": offset,
    };
    if (query != null && query.isNotEmpty) params["query"] = query;
    if (types != null && types.isNotEmpty) params["types"] = types.join(",");
    if (dateFrom != null) params["date_from"] = dateFrom;
    if (dateTo != null) params["date_to"] = dateTo;

    final resp = await _dio.get("/events", queryParameters: params);
    final data = resp.data as Map<String, dynamic>;
    final items = (data["items"] as List)
        .map((e) => EventDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedResponse(
        items: items, total: data["total"] as int? ?? items.length);
  }
}
