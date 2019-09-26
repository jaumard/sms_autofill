import 'package:flutter/material.dart';
import 'package:pin_input_text_field/pin_input_text_field.dart';
import 'package:sms_autofill/sms_autofill.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _code;
  String signature = "{{ app signature }}";

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PhoneFieldHint(autofocus: true),
              Spacer(),
              PinFieldAutoFill(
                decoration: UnderlineDecoration(
                    textStyle: TextStyle(fontSize: 20, color: Colors.black)),
                currentCode: _code,
              ),
              Spacer(),
              TextFieldPinAutoFill(
                currentCode: _code,
              ),
              Spacer(),
              RaisedButton(
                child: Text('Listen for sms code'),
                onPressed: () async {
                  await SmsAutoFill().listenForCode;
                },
              ),
              RaisedButton(
                child: Text('Set code to 123456'),
                onPressed: () async {
                  setState(() {
                    _code = '123456';
                  });
                },
              ),
              SizedBox(
                height: 8.0
              ),
              Divider(
                height: 1.0
              ),
              SizedBox(
                height: 4.0
              ),
              Text("App Signature : $signature"),
              SizedBox(
                height: 4.0
              ),
              RaisedButton(
                child: Text('Get app signature'),
                onPressed: () async {
                  signature = await SmsAutoFill().getAppSignature;
                  setState((){});
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}
