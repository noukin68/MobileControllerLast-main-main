class ProcessInfo {
  final String processName;
  final String startTime;
  final String elapsedTime;

  ProcessInfo({
    required this.processName,
    required this.startTime,
    required this.elapsedTime,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      processName: json['ProcessName'],
      startTime: json['StartTime'],
      elapsedTime: json['ElapsedTime'],
    );
  }
}
