// GTFS Models for Bangkok Public Transport
// Covers BTS, MRT, Train, Bus, Ferry

class Agency {
  final String agencyId;
  final String name;
  final String url;
  final String timezone;
  final String? lang;
  final String? phone;
  final String? fareUrl;

  Agency({
    required this.agencyId,
    required this.name,
    required this.url,
    required this.timezone,
    this.lang,
    this.phone,
    this.fareUrl,
  });
}

class Route {
  final String routeId;
  final String agencyId;
  final String shortName;
  final String longName;
  final String type; // e.g., "BTS", "MRT", "Train", "Bus", "Ferry"
  final String? color;
  final String? textColor;

  Route({
    required this.routeId,
    required this.agencyId,
    required this.shortName,
    required this.longName,
    required this.type,
    this.color,
    this.textColor,
  });
}

class Stop {
  final String stopId;
  final String name;
  final double lat;
  final double lon;
  final String? code;
  final String? desc;
  final String? zoneId;

  Stop({
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lon,
    this.code,
    this.desc,
    this.zoneId,
  });
}

class Trip {
  final String tripId;
  final String routeId;
  final String serviceId;
  final String headsign;
  final String? directionId;

  Trip({
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    required this.headsign,
    this.directionId,
  });
}

class StopTime {
  final String tripId;
  final String arrivalTime;
  final String departureTime;
  final String stopId;
  final int stopSequence;

  StopTime({
    required this.tripId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopId,
    required this.stopSequence,
  });
}

class Calendar {
  final String serviceId;
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;
  final bool saturday;
  final bool sunday;
  final DateTime startDate;
  final DateTime endDate;

  Calendar({
    required this.serviceId,
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
    required this.startDate,
    required this.endDate,
  });
}

// You can extend these models for more GTFS fields as needed.
