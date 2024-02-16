/*
    SmartHome ESP Flutter client
    Copyright (C) 2024  Dominik Ruszczyk

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
*/

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const SmartHomeRoot());
}

class SmartHomeRoot extends StatelessWidget {
  const SmartHomeRoot({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartHome',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const SmartHome(),
    );
  }
}

class SmartHome extends StatefulWidget {
  const SmartHome({super.key});

  @override
  State<SmartHome> createState() => SmartHomeState();
}

class PinButton extends StatefulWidget {
  final int id;
  final Stream<WebSocketEvent> eventStream;

  PinButton(this.id, this.eventStream);

  @override
  State<StatefulWidget> createState() {
    return PinButtonState(id, eventStream);
  }
}

final ButtonStyle flatButtonStyle = TextButton.styleFrom(
  primary: Colors.black87,
  padding: EdgeInsets.symmetric(horizontal: 16),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(2)),
  ),
);

class PinState {
  bool status, locked;
  PinState(this.status, this.locked);
}

class PinButtonState extends State<PinButton> {
  final int id;
  final Stream<WebSocketEvent> eventStream;
  PinButtonState(this.id, this.eventStream) {}

  int count = 0;

  Future<http.Response> toggleButton() {
    return http.get(Uri.parse('http://10.0.1.176/toggle?pin=' + id.toString()));
  }

  Future<PinState> updateButtonState() {
    return http
        .get(Uri.parse('http://10.0.1.176/state?pin=' + id.toString()))
        .then((value) {
      PinState state = new PinState(false, false);
      if (value.body.characters.elementAt(0) == "1") {
        state.status = true;
      } else {
        state.status = false;
      }

      if (value.body.characters.elementAt(1) == "1") {
        state.locked = true;
      } else {
        state.locked = false;
      }
      return state;
    });
  }

  Text getText(PinState state) {
    String content = (state.status ? "ON" : "OFF");
    if (state.locked) {
      return Text(content,
          style: TextStyle(decoration: TextDecoration.lineThrough));
    } else {
      return Text(content);
    }
  }

  @override
  Widget build(BuildContext context) {
            return FutureBuilder(
            future: updateButtonState(),
            builder: (context, snapshot) {

              PinState state = snapshot.data ?? new PinState(false, false);

              return StreamBuilder(
                  stream: eventStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      WebSocketEvent? event = snapshot.data;
                      if (event?.id == id) {
                        switch (event?.type) {
                          case WebSocketEventType.ON:
                            state.status = true;
                            break;
                          case WebSocketEventType.OFF:
                            state.status = false;
                            break;
                          case WebSocketEventType.LOCK:
                            state.locked = true;
                            break;
                          case WebSocketEventType.UNLOCK:
                            state.locked = false;
                            break;
                          case null:
                            break;
                        }
                      }
                    }

                    return TextButton(
                        style: flatButtonStyle,
                        onPressed: () {
                          toggleButton().then((_) { setState((){}); });
                        },
                        child: getText(state));
                  });
            });
  }
}

enum WebSocketEventType { ON, OFF, LOCK, UNLOCK }

class WebSocketEvent {
  final WebSocketEventType type;
  final int id;
  const WebSocketEvent(this.type, this.id);
}

class SmartHomeState extends State<SmartHome> {
  final StreamController eventStream =
      StreamController<WebSocketEvent>.broadcast();

  SmartHomeState() {
    WebSocketChannel ws =
        WebSocketChannel.connect(Uri.parse('ws://10.0.1.176/ws'));

    ws.stream.listen((message) {
      List<String> split = message.toString().split(" ");
      if (split.length == 2) {
        String command = split[0];
        try {
          int pin = int.parse(split[1]);
          onWebsocketCommand(command, pin);
        } catch (e) {}
      }
    });
  }

  void onWebsocketCommand(String command, int pin) {
    switch (command.toUpperCase()) {
      case "ON":
        {
          eventStream.add(WebSocketEvent(WebSocketEventType.ON, pin));
          break;
        }
      case "OFF":
        {
          eventStream.add(WebSocketEvent(WebSocketEventType.OFF, pin));
          break;
        }
      case "LOCK":
        {
          eventStream.add(WebSocketEvent(WebSocketEventType.LOCK, pin));
          break;
        }
      case "UNLOCK":
        {
          eventStream.add(WebSocketEvent(WebSocketEventType.UNLOCK, pin));
          break;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text("SmartHome"),
        ),
        body: Padding(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Center(
                child: GridView.count(
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              crossAxisCount: 2,
              children: [
                PinButton(0, eventStream.stream.cast()),
                PinButton(1, eventStream.stream.cast()),
                PinButton(2, eventStream.stream.cast()),
                PinButton(3, eventStream.stream.cast())
              ],
            ))));
  }
}
