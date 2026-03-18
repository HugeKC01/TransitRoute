import 'dart:io';

void main() {
  final tripsFile = File('assets/gtfs_data/trips.txt');
  final freqsFile = File('assets/gtfs_data/frequencies.txt');
  final stopTimesFile = File('assets/gtfs_data/bus_stop_times.txt');
  
  var trips = tripsFile.readAsStringSync();
  if (!trips.contains('BRT_0')) {
    if (!trips.endsWith('\n')) {
      tripsFile.writeAsStringSync('\n', mode: FileMode.append);
    }
    tripsFile.writeAsStringSync('BRT,WKD,BRT_0,Ratchaphruek,0,BRT_MAIN,\nBRT,WKD,BRT_1,Sathorn,1,BRT_MAIN,\n', mode: FileMode.append);
  }
  
  var freqs = '''BRT_0,06:00:00,09:00:00,300
BRT_0,09:00:00,16:00:00,900
BRT_0,16:00:00,20:00:00,300
BRT_0,20:00:00,24:00:00,900
BRT_1,06:00:00,09:00:00,300
BRT_1,09:00:00,16:00:00,900
BRT_1,16:00:00,20:00:00,300
BRT_1,20:00:00,24:00:00,900
''';
  if (!freqsFile.readAsStringSync().contains('BRT_0')) {
    freqsFile.writeAsStringSync(freqs, mode: FileMode.append);
  }
  
  var stopTimesStr = '';
  // BRT_0: BRT_1 -> BRT_14
  String formatTime(int m) {
    int h = 6 + (m ~/ 60);
    int min = m % 60;
    return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:00';
  }
  
  for (int i = 1; i <= 14; i++) {
    var time = formatTime((i - 1) * 2);
    stopTimesStr += 'BRT_0,$time,$time,BRT_$i,$i\n';
  }
  
  // BRT_1: BRT_14 -> BRT_1
  for (int i = 14; i >= 1; i--) {
    int seq = 15 - i;
    var time = formatTime((seq - 1) * 2);
    stopTimesStr += 'BRT_1,$time,$time,BRT_$i,$seq\n';
  }
  
  var stopTimesContent = stopTimesFile.readAsStringSync();
  if (!stopTimesContent.contains('BRT_0')) {
    if (!stopTimesContent.endsWith('\n')) {
      stopTimesFile.writeAsStringSync('\n', mode: FileMode.append);
    }
    stopTimesFile.writeAsStringSync(stopTimesStr, mode: FileMode.append);
  }
  
  print('Done adding BRT to trips, frequencies, and bus_stop_times.');
}
