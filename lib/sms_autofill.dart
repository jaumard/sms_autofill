import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_input_text_field/pin_input_text_field.dart';

class SmsAutoFill {
  static SmsAutoFill _singleton;
  static const MethodChannel _channel = const MethodChannel('sms_autofill');
  final StreamController<String> _code = StreamController.broadcast();

  factory SmsAutoFill() => _singleton ??= SmsAutoFill._();

  SmsAutoFill._() {
    _channel.setMethodCallHandler((method) {
      if (method.method == 'smscode') {
        _code.add(method.arguments);
      }
    });
  }

  Stream<String> get code => _code.stream;

  Future<String> get hint async {
    final String version = await _channel.invokeMethod('requestPhoneHint');
    return version;
  }

  Future<void> get listenForCode async {
    await _channel.invokeMethod('listenForCode');
  }
}

class PinFieldAutoFill extends StatefulWidget {
  final int codeLength;
  final bool autofocus;
  final String currentCode;
  final Function(String) onCodeSubmitted;
  final Function(String) onCodeChanged;
  final PinDecoration decoration;
  final FocusNode focusNode;
  final TextInputType keyboardType;

  const PinFieldAutoFill({
    Key key,
    this.keyboardType = const TextInputType.numberWithOptions(),
    this.focusNode,
    this.decoration = const UnderlineDecoration(textStyle: TextStyle(color: Colors.black)),
    this.onCodeSubmitted,
    this.onCodeChanged,
    this.currentCode,
    this.autofocus = false,
    this.codeLength = 6,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PinFieldAutoFillState();
  }
}

class _PinFieldAutoFillState extends State<PinFieldAutoFill> with CodeAutoFill {
  PinEditingController controller;

  @override
  Widget build(BuildContext context) {
    return PinInputTextField(
      pinLength: widget.codeLength,
      decoration: widget.decoration,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      autoFocus: widget.autofocus,
      pinEditingController: controller,
      onSubmit: widget.onCodeSubmitted,
    );
  }

  @override
  void initState() {
    controller = PinEditingController(text: '', pinLength: widget.codeLength);
    code = widget.currentCode;
    codeUpdated();
    controller.addListener(() {
      code = controller.text;
      if (widget.onCodeChanged != null) {
        widget.onCodeChanged(code);
      }
    });
    super.listenForCode();
    super.initState();
  }

  @override
  void didUpdateWidget(PinFieldAutoFill oldWidget) {
    if (widget.codeLength != oldWidget.codeLength) {
      controller = PinEditingController(text: controller.text, pinLength: widget.codeLength);
    }
    if (widget.currentCode != oldWidget.currentCode || widget.currentCode != code) {
      code = widget.currentCode;
      codeUpdated();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void codeUpdated() {
    controller.value = TextEditingValue(text: code ?? '');
  }

  @override
  void dispose() {
    cancel();
    if (!controller.autoDispose) {
      controller.dispose();
    }
    super.dispose();
  }
}

class PhoneFieldHint extends StatefulWidget {
  final bool autofocus;
  final FocusNode focusNode;
  final TextEditingController controller;
  final TextField child;

  const PhoneFieldHint({
    Key key,
    this.child,
    this.controller,
    this.autofocus = false,
    this.focusNode,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PhoneFieldHintState();
  }
}

class _PhoneFieldHintState extends State<PhoneFieldHint> {
  final SmsAutoFill _autoFill = SmsAutoFill();
  TextEditingController _controller;
  FocusNode _focusNode;
  bool _hintShown = false;

  @override
  void initState() {
    _controller = widget.controller ?? widget.child?.controller ?? TextEditingController(text: '');
    _focusNode = widget.focusNode ?? widget.child?.focusNode ?? FocusNode();
    _focusNode.addListener(() async {
      if (_focusNode.hasFocus && !_hintShown) {
        _hintShown = true;
        await _askPhoneHint();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ??
        TextField(
          autofocus: widget.autofocus,
          focusNode: _focusNode,
          decoration: InputDecoration(
            suffixIcon: Platform.isAndroid
                ? IconButton(
                    icon: Icon(Icons.phonelink_setup),
                    onPressed: () async {
                      await _askPhoneHint();
                    },
                  )
                : null,
          ),
          controller: _controller,
          keyboardType: TextInputType.phone,
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _askPhoneHint() async {
    String hint = await _autoFill.hint;
    _controller.value = TextEditingValue(text: hint ?? '');
  }
}

class TextFieldPinAutoFill extends StatefulWidget {
  final int codeLength;
  final bool autofocus;
  final FocusNode focusNode;
  final String currentCode;
  final Function(String) onCodeSubmitted;
  final Function(String) onCodeChanged;
  final InputDecoration decoration;
  final TextStyle style;

  const TextFieldPinAutoFill({
    Key key,
    this.focusNode,
    this.onCodeSubmitted,
    this.style,
    this.onCodeChanged,
    this.decoration = const InputDecoration(),
    this.currentCode,
    this.autofocus = false,
    this.codeLength = 6,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TextFieldPinAutoFillState();
  }
}

mixin CodeAutoFill {
  final SmsAutoFill _autoFill = SmsAutoFill();
  String code;
  StreamSubscription _subscription;

  void listenForCode() {
    _subscription = _autoFill.code.listen((code) {
      this.code = code;
      codeUpdated();
    });
  }

  void cancel() {
    _subscription?.cancel();
  }

  void codeUpdated();
}

class _TextFieldPinAutoFillState extends State<TextFieldPinAutoFill> with CodeAutoFill {
  final TextEditingController _textController = TextEditingController(text: '');

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      maxLength: widget.codeLength,
      decoration: widget.decoration,
      style: widget.style,
      onSubmitted: widget.onCodeSubmitted,
      onChanged: widget.onCodeChanged,
      keyboardType: TextInputType.numberWithOptions(),
      controller: _textController,
    );
  }

  @override
  void initState() {
    code = widget.currentCode;
    codeUpdated();
    super.listenForCode();
    super.initState();
  }

  @override
  void codeUpdated() {
    _textController.value = TextEditingValue(text: code ?? '');
  }

  @override
  void didUpdateWidget(TextFieldPinAutoFill oldWidget) {
    if (widget.currentCode != oldWidget.currentCode || widget.currentCode != _getCode()) {
      code = widget.currentCode;
      codeUpdated();
    }
    super.didUpdateWidget(oldWidget);
  }

  String _getCode() {
    return _textController.value.text;
  }

  @override
  void dispose() {
    cancel();
    _textController.dispose();
    super.dispose();
  }
}
