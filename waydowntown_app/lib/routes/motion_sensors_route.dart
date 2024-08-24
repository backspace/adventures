import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

void main() {
  runApp(const MotionSensorsRoute());
}

class MotionSensorsRoute extends StatefulWidget {
  const MotionSensorsRoute({super.key});

  @override
  MotionSensorsRouteState createState() => MotionSensorsRouteState();
}

class MotionSensorsRouteState extends State<MotionSensorsRoute> {
  final Vector3 _accelerometer = Vector3.zero();
  final Vector3 _gyroscope = Vector3.zero();
  final Vector3 _magnetometer = Vector3.zero();
  final Vector3 _userAaccelerometer = Vector3.zero();
  final Vector3 _orientation = Vector3.zero();
  final Vector3 _absoluteOrientation = Vector3.zero();
  final Vector3 _absoluteOrientation2 = Vector3.zero();
  double? _screenOrientation = 0;

  int? _groupValue = 0;

  // Add these variables to store the stream subscriptions
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<UserAccelerometerEvent>
      _userAccelerometerSubscription;
  late StreamSubscription<MagnetometerEvent> _magnetometerSubscription;
  StreamSubscription<OrientationEvent>? _orientationSubscription;
  late StreamSubscription<AbsoluteOrientationEvent>
      _absoluteOrientationSubscription;
  late StreamSubscription<ScreenOrientationEvent>
      _screenOrientationSubscription;

  @override
  void initState() {
    super.initState();

    _gyroscopeSubscription =
        motionSensors.gyroscope.listen((GyroscopeEvent event) {
      setState(() {
        _gyroscope.setValues(event.x, event.y, event.z);
      });
    });

    _accelerometerSubscription =
        motionSensors.accelerometer.listen((AccelerometerEvent event) {
      setState(() {
        _accelerometer.setValues(event.x, event.y, event.z);
      });
    });

    _userAccelerometerSubscription =
        motionSensors.userAccelerometer.listen((UserAccelerometerEvent event) {
      setState(() {
        _userAaccelerometer.setValues(event.x, event.y, event.z);
      });
    });

    _magnetometerSubscription =
        motionSensors.magnetometer.listen((MagnetometerEvent event) {
      setState(() {
        _magnetometer.setValues(event.x, event.y, event.z);
        var matrix =
            motionSensors.getRotationMatrix(_accelerometer, _magnetometer);
        _absoluteOrientation2.setFrom(motionSensors.getOrientation(matrix));
      });
    });

    motionSensors.isOrientationAvailable().then((available) {
      if (available) {
        _orientationSubscription =
            motionSensors.orientation.listen((OrientationEvent event) {
          setState(() {
            _orientation.setValues(event.yaw, event.pitch, event.roll);
          });
        });
      }
    });

    _absoluteOrientationSubscription = motionSensors.absoluteOrientation
        .listen((AbsoluteOrientationEvent event) {
      setState(() {
        _absoluteOrientation.setValues(event.yaw, event.pitch, event.roll);
      });
    });

    _screenOrientationSubscription =
        motionSensors.screenOrientation.listen((ScreenOrientationEvent event) {
      setState(() {
        _screenOrientation = event.angle;
      });
    });
  }

  @override
  void dispose() {
    _gyroscopeSubscription.cancel();
    _accelerometerSubscription.cancel();
    _userAccelerometerSubscription.cancel();
    _magnetometerSubscription.cancel();
    _orientationSubscription?.cancel();
    _absoluteOrientationSubscription.cancel();
    _screenOrientationSubscription.cancel();
    super.dispose();
  }

  void setUpdateInterval(int? groupValue, int interval) {
    motionSensors.accelerometerUpdateInterval = interval;
    motionSensors.userAccelerometerUpdateInterval = interval;
    motionSensors.gyroscopeUpdateInterval = interval;
    motionSensors.magnetometerUpdateInterval = interval;
    motionSensors.orientationUpdateInterval = interval;
    motionSensors.absoluteOrientationUpdateInterval = interval;
    setState(() {
      _groupValue = groupValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Motion Sensors'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Update Interval'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Radio(
                  value: 1,
                  groupValue: _groupValue,
                  onChanged: (dynamic value) => setUpdateInterval(
                      value, Duration.microsecondsPerSecond ~/ 1),
                ),
                const Text("1 FPS"),
                Radio(
                  value: 2,
                  groupValue: _groupValue,
                  onChanged: (dynamic value) => setUpdateInterval(
                      value, Duration.microsecondsPerSecond ~/ 30),
                ),
                const Text("30 FPS"),
                Radio(
                  value: 3,
                  groupValue: _groupValue,
                  onChanged: (dynamic value) => setUpdateInterval(
                      value, Duration.microsecondsPerSecond ~/ 60),
                ),
                const Text("60 FPS"),
              ],
            ),
            const Text('Accelerometer'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(_accelerometer.x.toStringAsFixed(4)),
                Text(_accelerometer.y.toStringAsFixed(4)),
                Text(_accelerometer.z.toStringAsFixed(4)),
              ],
            ),
            const Text('Magnetometer'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(_magnetometer.x.toStringAsFixed(4)),
                Text(_magnetometer.y.toStringAsFixed(4)),
                Text(_magnetometer.z.toStringAsFixed(4)),
              ],
            ),
            const Text('Gyroscope'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(_gyroscope.x.toStringAsFixed(4)),
                Text(_gyroscope.y.toStringAsFixed(4)),
                Text(_gyroscope.z.toStringAsFixed(4)),
              ],
            ),
            const Text('User Accelerometer'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(_userAaccelerometer.x.toStringAsFixed(4)),
                Text(_userAaccelerometer.y.toStringAsFixed(4)),
                Text(_userAaccelerometer.z.toStringAsFixed(4)),
              ],
            ),
            const Text('Orientation'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(degrees(_orientation.x).toStringAsFixed(4)),
                Text(degrees(_orientation.y).toStringAsFixed(4)),
                Text(degrees(_orientation.z).toStringAsFixed(4)),
              ],
            ),
            const Text('Absolute Orientation'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(degrees(_absoluteOrientation.x).toStringAsFixed(4)),
                Text(degrees(_absoluteOrientation.y).toStringAsFixed(4)),
                Text(degrees(_absoluteOrientation.z).toStringAsFixed(4)),
              ],
            ),
            const Text('Orientation (accelerometer + magnetometer)'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(degrees(_absoluteOrientation2.x).toStringAsFixed(4)),
                Text(degrees(_absoluteOrientation2.y).toStringAsFixed(4)),
                Text(degrees(_absoluteOrientation2.z).toStringAsFixed(4)),
              ],
            ),
            const Text('Screen Orientation'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(_screenOrientation!.toStringAsFixed(4)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
