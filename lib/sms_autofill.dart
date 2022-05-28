import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_input_text_field/pin_input_text_field.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:sms_autofill/text_field_pin.dart';

export 'package:pin_input_text_field/pin_input_text_field.dart';

class SmsAutoFill {
  static SmsAutoFill? _singleton;
  static const MethodChannel _channel = const MethodChannel('sms_autofill');
  final StreamController<String> _code = StreamController.broadcast();

  factory SmsAutoFill() => _singleton ??= SmsAutoFill._();

  SmsAutoFill._() {
    _channel.setMethodCallHandler(_didReceive);
  }

  Future<void> _didReceive(MethodCall method) async {
    if (method.method == 'smscode') {
      _code.add(method.arguments);
    }
  }

  Stream<String> get code => _code.stream;

  Future<String?> get hint async {
    final String? hint = await _channel.invokeMethod('requestPhoneHint');
    return hint;
  }

  Future<void> listenForCode({String smsCodeRegexPattern: '\\d{4,6}'}) async {
    await _channel.invokeMethod('listenForCode',
        <String, String>{'smsCodeRegexPattern': smsCodeRegexPattern});
  }

  Future<void> unregisterListener() async {
    await _channel.invokeMethod('unregisterListener');
  }

  Future<String> get getAppSignature async {
    final String? appSignature = await _channel.invokeMethod('getAppSignature');
    return appSignature ?? '';
  }
}

class PinFieldAutoFill extends StatefulWidget {
  final int codeLength;
  final bool autoFocus;
  final TextEditingController? controller;
  final String? currentCode;
  final Function(String)? onCodeSubmitted;
  final Function(String?)? onCodeChanged;
  final PinDecoration decoration;
  final FocusNode? focusNode;
  final double? boxSize;
  final Cursor? cursor;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool enableInteractiveSelection;
  final String? smsCodeRegexPattern;
  final List<TextInputFormatter>? inputFormatters;

  const PinFieldAutoFill(
      {Key? key,
      this.keyboardType = const TextInputType.numberWithOptions(),
      this.textInputAction = TextInputAction.done,
      this.focusNode,
      this.boxSize,
      this.cursor,
      this.inputFormatters,
      this.enableInteractiveSelection = true,
      this.controller,
      this.decoration = const UnderlineDecoration(
          colorBuilder: FixedColorBuilder(Colors.black),
          textStyle: TextStyle(color: Colors.black)),
      this.onCodeSubmitted,
      this.onCodeChanged,
      this.currentCode,
      this.autoFocus = false,
      this.codeLength = 6,
      this.smsCodeRegexPattern})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PinFieldAutoFillState();
  }
}

BoxDecoration get _pinPutDecoration {
  return BoxDecoration(
    border: Border.all(color: Color(0xff35E3DD), width: 2),
    borderRadius: BorderRadius.circular(10),
  );
}

class _PinFieldAutoFillState extends State<PinFieldAutoFill> with CodeAutoFill {
  late TextEditingController controller;
  bool _shouldDisposeController = false;

  @override
  Widget build(BuildContext context) {
    return TextFieldPin(
      textController: controller,
      autoFocus: true,
      codeLength: widget.codeLength,
      alignment: MainAxisAlignment.center,
      defaultBoxSize: widget.boxSize!,
      margin: 5.0,
      selectedBoxSize: widget.boxSize,
      textStyle: TextStyle(fontSize: 16.0),
      defaultDecoration: _pinPutDecoration.copyWith(
        color: Colors.white,
        border: Border.all(color: Color(0xffEFEEF3)),
      ),
      selectedDecoration: _pinPutDecoration.copyWith(
          border: Border.all(color: Color(0xff35E3DD))),
      onChange: (code) {
        if (code.length == 6) {
          FocusScope.of(context).requestFocus(FocusNode());
          controller.text = code;
        }
      },
    );

    //   PinInputTextField(
    //   pinLength: widget.codeLength,
    //   decoration: widget.decoration,
    //   focusNode: widget.focusNode,
    //   enableInteractiveSelection: widget.enableInteractiveSelection,
    //   autocorrect: false,
    //   cursor: widget.cursor,
    //   autofillHints: const <String>[AutofillHints.oneTimeCode],
    //   textCapitalization: TextCapitalization.none,
    //   toolbarOptions: ToolbarOptions(paste: true),
    //   keyboardType: widget.keyboardType,
    //   autoFocus: widget.autoFocus,
    //   controller: controller,
    //   inputFormatters: widget.inputFormatters,
    //   textInputAction: widget.textInputAction,
    //   onSubmit: widget.onCodeSubmitted,
    // );
  }

  @override
  void initState() {
    _shouldDisposeController = widget.controller == null;
    controller = widget.controller ?? TextEditingController(text: '');
    code = widget.currentCode;
    codeUpdated();
    controller.addListener(() {
      if (controller.text != code) {
        code = controller.text;
        if (widget.onCodeChanged != null) {
          widget.onCodeChanged!(code);
        }
      }
    });
    listenForCode(smsCodeRegexPattern: widget.smsCodeRegexPattern);
    super.initState();
  }

  @override
  void didUpdateWidget(PinFieldAutoFill oldWidget) {
    if (widget.controller != null && widget.controller != controller) {
      controller.dispose();
      controller = widget.controller!;
    }

    if (widget.currentCode != oldWidget.currentCode ||
        widget.currentCode != code) {
      code = widget.currentCode;
      codeUpdated();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void codeUpdated() {
    if (controller.text != code) {
      controller.value = TextEditingValue(text: code ?? '');
      if (widget.onCodeChanged != null) {
        widget.onCodeChanged!(code ?? '');
      }
    }
  }

  @override
  void dispose() {
    cancel();
    if (_shouldDisposeController) {
      controller.dispose();
    }
    unregisterListener();
    super.dispose();
  }
}

class PhoneFormFieldHint extends StatelessWidget {
  final bool autoFocus;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator? validator;
  final InputDecoration? decoration;
  final TextField? child;

  const PhoneFormFieldHint({
    Key? key,
    this.child,
    this.controller,
    this.inputFormatters,
    this.validator,
    this.decoration,
    this.autoFocus = false,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _PhoneFieldHint(
        key: key,
        child: child,
        inputFormatters: inputFormatters,
        controller: controller,
        validator: validator,
        decoration: decoration,
        autoFocus: autoFocus,
        focusNode: focusNode,
        isFormWidget: true);
  }
}

class PhoneFieldHint extends StatelessWidget {
  final bool autoFocus;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final InputDecoration? decoration;
  final TextField? child;

  const PhoneFieldHint({
    Key? key,
    this.child,
    this.controller,
    this.inputFormatters,
    this.decoration,
    this.autoFocus = false,
    this.focusNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _PhoneFieldHint(
        key: key,
        child: child,
        inputFormatters: inputFormatters,
        controller: controller,
        decoration: decoration,
        autoFocus: autoFocus,
        focusNode: focusNode,
        isFormWidget: false);
  }
}

class _PhoneFieldHint extends StatefulWidget {
  final bool autoFocus;
  final FocusNode? focusNode;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator? validator;
  final bool isFormWidget;
  final InputDecoration? decoration;
  final TextField? child;

  const _PhoneFieldHint({
    Key? key,
    this.child,
    this.controller,
    this.inputFormatters,
    this.validator,
    this.isFormWidget = false,
    this.decoration,
    this.autoFocus = false,
    this.focusNode,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _PhoneFieldHintState();
  }
}

class _PhoneFieldHintState extends State<_PhoneFieldHint> {
  final SmsAutoFill _autoFill = SmsAutoFill();
  late TextEditingController _controller;
  late List<TextInputFormatter> _inputFormatters;
  late FocusNode _focusNode;
  bool _hintShown = false;
  bool _isUsingInternalController = false;
  bool _isUsingInternalFocusNode = false;

  @override
  void initState() {
    _controller = widget.controller ??
        widget.child?.controller ??
        _createInternalController();
    _inputFormatters =
        widget.inputFormatters ?? widget.child?.inputFormatters ?? [];
    _focusNode = widget.focusNode ??
        widget.child?.focusNode ??
        _createInternalFocusNode();
    _focusNode.addListener(() async {
      if (_focusNode.hasFocus && !_hintShown) {
        _hintShown = true;
        scheduleMicrotask(() {
          _askPhoneHint();
        });
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ??
        InputDecoration(
          suffixIcon: Platform.isAndroid
              ? IconButton(
                  icon: Icon(Icons.phonelink_setup),
                  onPressed: () async {
                    _hintShown = true;
                    await _askPhoneHint();
                  },
                )
              : null,
        );

    return widget.child ??
        _createField(widget.isFormWidget, decoration, widget.validator);
  }

  @override
  void dispose() {
    if (_isUsingInternalController) {
      _controller.dispose();
    }

    if (_isUsingInternalFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  Widget _createField(bool isFormWidget, InputDecoration decoration,
      FormFieldValidator? validator) {
    return isFormWidget
        ? _createTextFormField(decoration, validator)
        : _createTextField(decoration);
  }

  Widget _createTextField(InputDecoration decoration) {
    return TextField(
      autofocus: widget.autoFocus,
      focusNode: _focusNode,
      autofillHints: [AutofillHints.telephoneNumber],
      inputFormatters: _inputFormatters,
      decoration: decoration,
      controller: _controller,
      keyboardType: TextInputType.phone,
    );
  }

  Widget _createTextFormField(
      InputDecoration decoration, FormFieldValidator? validator) {
    return TextFormField(
      validator: validator,
      autofocus: widget.autoFocus,
      focusNode: _focusNode,
      autofillHints: [AutofillHints.telephoneNumber],
      inputFormatters: _inputFormatters,
      decoration: decoration,
      controller: _controller,
      keyboardType: TextInputType.phone,
    );
  }

  Future<void> _askPhoneHint() async {
    String? hint = await _autoFill.hint;
    _controller.value = TextEditingValue(text: hint ?? '');
  }

  TextEditingController _createInternalController() {
    _isUsingInternalController = true;
    return TextEditingController(text: '');
  }

  FocusNode _createInternalFocusNode() {
    _isUsingInternalFocusNode = true;
    return FocusNode();
  }
}

class TextFieldPinAutoFill extends StatefulWidget {
  final int codeLength;
  final bool autoFocus;
  final FocusNode? focusNode;
  final String? currentCode;
  final Function(String)? onCodeSubmitted;
  final Function(String)? onCodeChanged;
  final InputDecoration decoration;
  final bool obscureText;
  final TextStyle? style;
  final String? smsCodeRegexPattern;
  final List<TextInputFormatter>? inputFormatters;

  const TextFieldPinAutoFill(
      {Key? key,
      this.focusNode,
      this.obscureText = false,
      this.onCodeSubmitted,
      this.style,
      this.inputFormatters,
      this.onCodeChanged,
      this.decoration = const InputDecoration(),
      this.currentCode,
      this.autoFocus = false,
      this.codeLength = 6,
      this.smsCodeRegexPattern})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TextFieldPinAutoFillState();
  }
}

mixin CodeAutoFill {
  final SmsAutoFill _autoFill = SmsAutoFill();
  String? code;
  StreamSubscription? _subscription;

  void listenForCode({String? smsCodeRegexPattern}) {
    _subscription = _autoFill.code.listen((code) {
      this.code = code;
      codeUpdated();
    });
    (smsCodeRegexPattern == null)
        ? _autoFill.listenForCode()
        : _autoFill.listenForCode(smsCodeRegexPattern: smsCodeRegexPattern);
  }

  Future<void> cancel() async {
    return _subscription?.cancel();
  }

  Future<void> unregisterListener() {
    return _autoFill.unregisterListener();
  }

  void codeUpdated();
}

class _TextFieldPinAutoFillState extends State<TextFieldPinAutoFill>
    with CodeAutoFill {
  final TextEditingController _textController = TextEditingController(text: '');

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: widget.autoFocus,
      focusNode: widget.focusNode,
      maxLength: widget.codeLength,
      decoration: widget.decoration,
      style: widget.style,
      inputFormatters: widget.inputFormatters,
      autofillHints: const <String>[AutofillHints.oneTimeCode],
      onSubmitted: widget.onCodeSubmitted,
      onChanged: widget.onCodeChanged,
      keyboardType: TextInputType.numberWithOptions(),
      controller: _textController,
      obscureText: widget.obscureText,
    );
  }

  @override
  void initState() {
    code = widget.currentCode;
    codeUpdated();
    listenForCode(smsCodeRegexPattern: widget.smsCodeRegexPattern);
    super.initState();
  }

  @override
  void codeUpdated() {
    if (_textController.text != code) {
      _textController.value = TextEditingValue(text: code ?? '');
      if (widget.onCodeChanged != null) {
        widget.onCodeChanged!(code ?? '');
      }
    }
  }

  @override
  void didUpdateWidget(TextFieldPinAutoFill oldWidget) {
    if (widget.currentCode != oldWidget.currentCode ||
        widget.currentCode != _getCode()) {
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
    unregisterListener();
    super.dispose();
  }
}
