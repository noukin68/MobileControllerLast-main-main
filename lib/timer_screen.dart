import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/auth.dart';
import 'package:flutter_application_1/process_info.dart';
import 'package:flutter_application_1/process_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:math';

class TimerScreen extends StatefulWidget {
  final IO.Socket socket;

  TimerScreen(this.socket);

  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin {
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  bool isCountingDown = false;
  bool isTimerRunning = false;
  bool isSocketConnected = true;
  List<ProcessInfo> processInfoList = [];

  late AnimationController _buttonAnimationController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    widget.socket.on('process-data', (data) {
      setState(() {
        if (data is List) {
          processInfoList = List<ProcessInfo>.from(
            data.map((item) {
              if (item is Map<String, dynamic>) {
                return ProcessInfo.fromJson(item);
              }
            }),
          );
        } else {
          processInfoList = [];
        }
      });
    });

    widget.socket.on('connection-status', (data) {
      setState(() {
        isSocketConnected = data['connected'];
      });
    });

    widget.socket.on(
      'restart-timer',
      (data) {
        restartTimer();
      },
    );

    widget.socket.on(
      'test-completed',
      (data) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color.fromRGBO(119, 75, 36, 1),
              title: Text(
                "Уведомление",
                style: TextStyle(
                  color: const Color.fromRGBO(239, 206, 173, 1),
                ),
              ),
              content: Text(
                "Тест завершен",
                style: TextStyle(
                  color: const Color.fromRGBO(239, 206, 173, 1),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: onContinuePressed,
                  child: Text(
                    'Продолжить работу',
                    style: TextStyle(
                      color: const Color(0xFFEFCEAD),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onFinishPressed,
                  child: Text(
                    'Завершить работу',
                    style: TextStyle(
                      color: const Color(0xFFEFCEAD),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void restartTimer() {
    setState(() {
      sendTimeToServer();
    });
  }

  Future<void> onContinuePressed() async {
    widget.socket.emit('continue-work');
    Navigator.pop(context);
  }

  void onFinishPressed() {
    widget.socket.emit('finish-work');
    Navigator.pop(context);
  }

  void startCountdown() {
    final totalSeconds = hours * 3600 + minutes * 60 + seconds;

    setState(() {
      isCountingDown = true;
      isTimerRunning = true; // Устанавливаем флаг в true при запуске таймера.
    });

    Future.delayed(Duration(seconds: totalSeconds), () {
      setState(() {
        isCountingDown = false;
        isTimerRunning =
            false; // Устанавливаем флаг в false при окончании таймера.
      });
    });
  }

  void stopCountdown() {
    setState(() {
      isCountingDown = false;
      isTimerRunning = false;
    });

    final totalSeconds = calculateRemainingSeconds();
    print('Stopping timer and sending time: $totalSeconds');
    widget.socket.emit('stop-timer', totalSeconds);
  }

  void sendTimeToServer() {
    final totalSeconds = hours * 3600 + minutes * 60 + seconds;

    print('Sending time: $hours:$minutes:$seconds');
    widget.socket.emit('time-received', totalSeconds);

    startCountdown();
  }

  int calculateRemainingSeconds() {
    final totalSeconds = hours * 3600 + minutes * 60 + seconds;
    return totalSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Лимит времени'),
        backgroundColor: const Color.fromRGBO(119, 75, 36, 1),
        foregroundColor: const Color.fromRGBO(239, 206, 173, 1),
        actions: [
          IconButton(
            icon: Icon(
              Icons.exit_to_app,
              color: const Color.fromRGBO(239, 206, 173, 1),
            ),
            onPressed: () => logout(),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFEFCEAD),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: CircleProgressPainter(
                      remainingSeconds: calculateRemainingSeconds()),
                  child: Center(
                    child: isCountingDown
                        ? CountdownTimer(
                            seconds: calculateRemainingSeconds(),
                            onFinish: () {
                              setState(() {
                                isCountingDown = false;
                              });
                            },
                          )
                        : Text(
                            formatTime(calculateRemainingSeconds()),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color.fromRGBO(119, 75, 36, 1),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  NumberPicker(
                    title: 'Часы',
                    minValue: 0,
                    maxValue: 23,
                    onChanged: (value) {
                      setState(() {
                        hours = value;
                      });
                    },
                  ),
                  NumberPicker(
                    title: 'Минуты',
                    minValue: 0,
                    maxValue: 59,
                    onChanged: (value) {
                      setState(() {
                        minutes = value;
                      });
                    },
                  ),
                  NumberPicker(
                    title: 'Секунды',
                    minValue: 0,
                    maxValue: 59,
                    onChanged: (value) {
                      setState(() {
                        seconds = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _buttonScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buttonScaleAnimation.value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTapDown: (_) {
                    _buttonAnimationController.forward();
                  },
                  onTapUp: (_) {
                    _buttonAnimationController.reverse();
                    sendTimeToServer();
                  },
                  onTapCancel: () {
                    _buttonAnimationController.reverse();
                  },
                  child: Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: const Color.fromRGBO(119, 75, 36, 1),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Color.fromRGBO(239, 206, 173, 1),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Установить таймер',
                            style: TextStyle(
                              color: Color.fromRGBO(239, 206, 173, 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _buttonScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buttonScaleAnimation.value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTapDown: (_) {
                    _buttonAnimationController.forward();
                  },
                  onTapUp: (_) {
                    _buttonAnimationController.reverse();
                    stopCountdown(); // Вызываем метод остановки таймера.
                  },
                  onTapCancel: () {
                    _buttonAnimationController.reverse();
                  },
                  child: Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: const Color.fromRGBO(119, 75, 36, 1),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.stop,
                            color: Color.fromRGBO(239, 206, 173, 1),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Остановить таймер',
                            style: TextStyle(
                              color: Color.fromRGBO(239, 206, 173, 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _buttonScaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buttonScaleAnimation.value,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTapDown: (_) {
                    _buttonAnimationController.forward();
                  },
                  onTapUp: (_) {
                    _buttonAnimationController.reverse();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProcessInfoScreen(processInfoList),
                      ),
                    );
                  },
                  onTapCancel: () {
                    _buttonAnimationController.reverse();
                  },
                  child: Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: const Color.fromRGBO(119, 75, 36, 1),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color.fromRGBO(239, 206, 173, 1),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Отчёт',
                            style: TextStyle(
                              color: Color.fromRGBO(239, 206, 173, 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Статус подключения: ${isSocketConnected ? 'Сопряжено' : 'Не сопряжено'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color.fromRGBO(119, 75, 36, 1),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _buttonAnimationController.dispose();
    super.dispose();
  }

  String formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}';
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage(widget.socket)),
    );
  }
}

class NumberPicker extends StatefulWidget {
  final String title;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const NumberPicker({
    required this.title,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
  });

  @override
  _NumberPickerState createState() => _NumberPickerState();
}

class _NumberPickerState extends State<NumberPicker> {
  int value = 0;

  void increment() {
    setState(() {
      value = (value + 1) % (widget.maxValue + 1);
      if (value < widget.minValue) {
        value = widget.minValue;
      }
      widget.onChanged(value);
    });
  }

  void decrement() {
    setState(() {
      value = (value - 1) % (widget.maxValue + 1);
      if (value < widget.minValue) {
        value = widget.maxValue;
      }
      widget.onChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(widget.title,
            style: const TextStyle(
              fontSize: 16,
              color: Color.fromRGBO(119, 75, 36, 1),
            )),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color.fromRGBO(119, 75, 36, 1),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(119, 75, 36, 1),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                margin: EdgeInsets.only(right: 2),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(40, 40),
                    padding: EdgeInsets.all(4),
                    textStyle: TextStyle(fontSize: 12),
                    backgroundColor: Color.fromRGBO(119, 75, 36, 1),
                    foregroundColor: Color.fromRGBO(239, 206, 173, 1),
                  ),
                  onPressed: increment,
                  child: Text('+'),
                ),
              ),
              Container(
                margin: EdgeInsets.only(left: 2),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(40, 40),
                    padding: EdgeInsets.all(4),
                    textStyle: TextStyle(fontSize: 12),
                    backgroundColor: Color.fromRGBO(119, 75, 36, 1),
                    foregroundColor: Color.fromRGBO(239, 206, 173, 1),
                  ),
                  onPressed: decrement,
                  child: Text('-'),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class CircleProgressPainter extends CustomPainter {
  final int remainingSeconds;

  CircleProgressPainter({required this.remainingSeconds});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    final double startAngle = -pi / 2;
    final double sweepAngle = 2 * pi * (remainingSeconds / (24 * 3600));

    final Paint paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class CountdownTimer extends StatefulWidget {
  final int seconds;
  final VoidCallback onFinish;

  const CountdownTimer({required this.seconds, required this.onFinish});

  @override
  _CountdownTimerState createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.seconds;
    startCountdown();
  }

  void startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer.cancel();
          widget.onFinish();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int hours = _remainingSeconds ~/ 3600;
    final int minutes = (_remainingSeconds % 3600) ~/ 60;
    final int seconds = _remainingSeconds % 60;

    return Text(
      '$hours : ${minutes.toString().padLeft(2, '0')} : ${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color.fromRGBO(119, 75, 36, 1),
      ),
    );
  }
}
