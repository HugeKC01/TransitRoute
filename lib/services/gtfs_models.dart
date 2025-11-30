// GTFS Models for Bangkok Public Transport
// Covers BTS, MRT, Train, Bus, Ferry

import 'package:flutter/material.dart';
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
  final List<String> linePrefixes;

  Route({
    required this.routeId,
    required this.agencyId,
    required this.shortName,
    required this.longName,
    required this.type,
    this.color,
    this.textColor,
    required this.linePrefixes,
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
  final String? shapeId;
  final Color? shapeColor;

  Trip({
    required this.tripId,
    required this.routeId,
    required this.serviceId,
    required this.headsign,
    this.directionId,
    this.shapeId,
    this.shapeColor,
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

class Faretype{
  final String fareId;
  final String agencystatus;

  Faretype({
    required this.fareId,
    required this.agencystatus,
   
  });
}

 class FareData{
  final String fareDataId;
  final String price;


  FareData({
    required this.fareDataId,
    required this.price,
  });
 }

 
// You can extend these models for more GTFS fields as needed.
