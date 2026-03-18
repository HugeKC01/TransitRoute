import 'dart:io';

void main() {
  // Routes
  final routeFile = File('assets/gtfs_data/ferry_route.txt');
  final routesLines = routeFile.readAsLinesSync().toList();
  
  final tsbUStops = ['F_NS', 'F_N30', 'F_N24', 'F_N22', 'F_N21', 'F_N18', 'F_N15', 'F_N12', 'F_N10', 'F_N8', 'F_N7', 'F_N5', 'F_N4', 'F_N3', 'F_CAT', 'F_CEN'];
  final tsbCStops = ['F_N12', 'F_N10', 'F_N9', 'F_ARUN', 'F_N7', 'F_N5', 'F_ICON', 'F_CEN', 'F_WW', 'F_SC'];

  if (!routesLines.any((l) => l.startsWith('F_TSB_U,'))) {
    var uJoined = tsbUStops.toList()..sort();
    routesLines.add('F_TSB_U,TSB,Urban,Thai Smile Boat Urban Line,4,6F2C91,FFFFFF,${uJoined.join(",")}');
  }
  if (!routesLines.any((l) => l.startsWith('F_TSB_C,'))) {
    var cJoined = tsbCStops.toList()..sort();
    routesLines.add('F_TSB_C,TSB,City,Thai Smile Boat City Line,4,007736,FFFFFF,${cJoined.join(",")}');
  }
  routeFile.writeAsStringSync(routesLines.join('\n') + '\n');


  // Trips
  final tripsFile = File('assets/gtfs_data/trips.txt');
  var tripsLines = tripsFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();

  tripsLines.removeWhere((l) => l.startsWith('F_TSB'));

  // Urban Line 
  tripsLines.add('F_TSB_U,WKD,F_TSB_U_TRIP1,Sathorn,1,,');
  tripsLines.add('F_TSB_U,WKD,F_TSB_U_TRIP2,Phra Nang Klao,0,,');
  tripsLines.add('F_TSB_U,SAT,F_TSB_U_TRIP1_SAT,Sathorn,1,,');
  tripsLines.add('F_TSB_U,SAT,F_TSB_U_TRIP2_SAT,Phra Nang Klao,0,,');
  tripsLines.add('F_TSB_U,SUN,F_TSB_U_TRIP1_SUN,Sathorn,1,,');
  tripsLines.add('F_TSB_U,SUN,F_TSB_U_TRIP2_SUN,Phra Nang Klao,0,,');

  // City Line
  tripsLines.add('F_TSB_C,WKD,F_TSB_C_TRIP1,Siam Charoennakhon,1,,');
  tripsLines.add('F_TSB_C,WKD,F_TSB_C_TRIP2,Phra Pinklao,0,,');
  tripsLines.add('F_TSB_C,SAT,F_TSB_C_TRIP1_SAT,Siam Charoennakhon,1,,');
  tripsLines.add('F_TSB_C,SAT,F_TSB_C_TRIP2_SAT,Phra Pinklao,0,,');
  tripsLines.add('F_TSB_C,SUN,F_TSB_C_TRIP1_SUN,Siam Charoennakhon,1,,');
  tripsLines.add('F_TSB_C,SUN,F_TSB_C_TRIP2_SUN,Phra Pinklao,0,,');

  // City Line Weekend Extra
  tripsLines.add('F_TSB_C,SAT,F_TSB_C_TRIP3_SAT,Phra Pinklao (Shuttle),0,,');
  tripsLines.add('F_TSB_C,SUN,F_TSB_C_TRIP3_SUN,Phra Pinklao (Shuttle),0,,');
  tripsLines.add('F_TSB_C,SAT,F_TSB_C_TRIP4_SAT,Sathorn (Shuttle),1,,');
  tripsLines.add('F_TSB_C,SUN,F_TSB_C_TRIP4_SUN,Sathorn (Shuttle),1,,');

  tripsFile.writeAsStringSync(tripsLines.join('\n') + '\n');


  // Stop Times
  final stFile = File('assets/gtfs_data/ferry_stop_times.txt');
  var stLines = stFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
  stLines.removeWhere((l) => l.startsWith('F_TSB'));

  void addStops(String tripId, List<String> stops) {
    for (int i = 0; i < stops.length; i++) {
        var min = (i * 4); // roughly 4 min per stop
        var timeStr = "00:${min.toString().padLeft(2, '0')}:00";
        stLines.add("$tripId,$timeStr,$timeStr,${stops[i]},${i+1}");
    }
  }

  // City extra stops
  final tsbCStopsExtra = ['F_N12', 'F_N10', 'F_N9', 'F_ARUN', 'F_N7', 'F_N5', 'F_ICON', 'F_CEN'];

  // U TRIP1 (NS -> CEN)
  addStops('F_TSB_U_TRIP1', tsbUStops);
  addStops('F_TSB_U_TRIP1_SAT', tsbUStops);
  addStops('F_TSB_U_TRIP1_SUN', tsbUStops);
  // U TRIP2 (CEN -> NS)
  addStops('F_TSB_U_TRIP2', tsbUStops.reversed.toList());
  addStops('F_TSB_U_TRIP2_SAT', tsbUStops.reversed.toList());
  addStops('F_TSB_U_TRIP2_SUN', tsbUStops.reversed.toList());

  // C TRIP1 (N12 -> SC)
  addStops('F_TSB_C_TRIP1', tsbCStops);
  addStops('F_TSB_C_TRIP1_SAT', tsbCStops);
  addStops('F_TSB_C_TRIP1_SUN', tsbCStops);

  // C TRIP2 (SC -> N12)
  addStops('F_TSB_C_TRIP2', tsbCStops.reversed.toList());
  addStops('F_TSB_C_TRIP2_SAT', tsbCStops.reversed.toList());
  addStops('F_TSB_C_TRIP2_SUN', tsbCStops.reversed.toList());

  // C TRIP3 (CEN -> N12)
  addStops('F_TSB_C_TRIP3_SAT', tsbCStopsExtra.reversed.toList());
  addStops('F_TSB_C_TRIP3_SUN', tsbCStopsExtra.reversed.toList());
  addStops('F_TSB_C_TRIP4_SAT', tsbCStopsExtra);
  addStops('F_TSB_C_TRIP4_SUN', tsbCStopsExtra);

  stFile.writeAsStringSync(stLines.join('\n') + '\n');


  // Timetables
  final ftFile = File('assets/gtfs_data/fixed_timetables.txt');
  var ftLines = ftFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList();
  ftLines.removeWhere((l) => l.startsWith('F_TSB'));

  void addTimetable(String tripId, List<String> stops, List<String> startTimes) {
    for (int i = 0; i < stops.length; i++) {
        List<String> stopArrivals = [];
        int offset = i * 4;
        for (var t in startTimes) {
            var parts = t.split(':');
            var h = int.parse(parts[0]);
            var m = int.parse(parts[1]);
            var mh = m + offset;
            var hh = h + (mh ~/ 60);
            mh = mh % 60;
            var timeStr = "${hh.toString().padLeft(2, '0')}:${mh.toString().padLeft(2, '0')}:00";
            stopArrivals.add(timeStr);
        }
        if (stopArrivals.isNotEmpty) {
          ftLines.add("$tripId,${stops[i]},${stopArrivals.join(';')}");
        }
    }
  }

  // Urban times
  final uTrip1WkdTimes = '06:00 06:15 06:30 06:45 07:00 07:15 07:30 07:45 08:00 08:20 08:40 09:00 12:30 13:00 13:30 14:00 14:30 15:00 15:20 15:40 16:00 16:20 16:40 17:00'.split(' ');
  final uTrip2WkdTimes = '07:30 07:45 08:00 08:15 08:30 08:45 09:00 09:15 09:30 09:50 10:10 10:30 14:00 14:30 15:00 15:30 16:00 16:30 16:50 17:10 17:30 17:50 18:10 18:30'.split(' ');

  final uTrip1WkeTimes = '06:30 07:00 07:30 08:00 08:30 09:00 09:30 10:00 13:30 14:00 14:30 15:00 15:30 16:00 16:30 17:00'.split(' ');
  final uTrip2WkeTimes = '08:00 08:30 09:00 09:30 10:00 10:30 11:00 11:30 15:00 15:30 16:00 16:30 17:00 17:30 18:00 18:30'.split(' ');

  addTimetable('F_TSB_U_TRIP1', tsbUStops, uTrip1WkdTimes);
  addTimetable('F_TSB_U_TRIP2', tsbUStops.reversed.toList(), uTrip2WkdTimes);
  addTimetable('F_TSB_U_TRIP1_SAT', tsbUStops, uTrip1WkeTimes);
  addTimetable('F_TSB_U_TRIP2_SAT', tsbUStops.reversed.toList(), uTrip2WkeTimes);
  addTimetable('F_TSB_U_TRIP1_SUN', tsbUStops, uTrip1WkeTimes);
  addTimetable('F_TSB_U_TRIP2_SUN', tsbUStops.reversed.toList(), uTrip2WkeTimes);

  // City times
  final cTrip1Times = '09:00 09:30 10:00 10:30 11:00 11:30 12:00 12:30 13:00 13:30 14:00 14:30 15:00 15:30 16:00 16:30 17:00 17:30 18:00 18:30'.split(' ');
  final cTrip2Times = '08:00 08:30 09:00 09:30 10:00 10:30 11:00 11:30 12:00 12:30 13:00 13:30 14:00 14:30 15:00 15:30 16:00 16:30 17:00 17:30'.split(' ');

  addTimetable('F_TSB_C_TRIP1', tsbCStops, cTrip1Times);
  addTimetable('F_TSB_C_TRIP2', tsbCStops.reversed.toList(), cTrip2Times);
  addTimetable('F_TSB_C_TRIP1_SAT', tsbCStops, cTrip1Times);
  addTimetable('F_TSB_C_TRIP2_SAT', tsbCStops.reversed.toList(), cTrip2Times);
  addTimetable('F_TSB_C_TRIP1_SUN', tsbCStops, cTrip1Times);
  addTimetable('F_TSB_C_TRIP2_SUN', tsbCStops.reversed.toList(), cTrip2Times);

  // City Extra Weekend
  final cTrip3Times = '11:15 11:45 12:15 12:45 13:15 13:45 15:15 16:15 17:15'.split(' '); // Sathorn to Phra Pinklao
  final cTrip4Times = '11:45 12:15 12:45 13:15 15:45 16:45'.split(' '); // Phra Pinklao to Sathorn

  addTimetable('F_TSB_C_TRIP3_SAT', tsbCStopsExtra.reversed.toList(), cTrip3Times);
  addTimetable('F_TSB_C_TRIP3_SUN', tsbCStopsExtra.reversed.toList(), cTrip3Times);
  addTimetable('F_TSB_C_TRIP4_SAT', tsbCStopsExtra, cTrip4Times);
  addTimetable('F_TSB_C_TRIP4_SUN', tsbCStopsExtra, cTrip4Times);

  ftFile.writeAsStringSync(ftLines.join('\n') + '\n');
  print('Added TSB Routes and Timetables.');
}