import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextFieldPin extends StatelessWidget {
  final Function(String) onChange;
  final double defaultBoxSize;
  final double selectedBoxSize;
  final BoxDecoration? defaultDecoration;
  final int codeLength;
  final TextStyle? textStyle;
  final double margin;
  final BoxDecoration? selectedDecoration;
  final bool autoFocus;
  final MainAxisAlignment alignment;
  final TextEditingController textController;

  TextFieldPin({
    required this.onChange,
    required this.defaultBoxSize,
    defaultDecoration,
    selectedBoxSize,
    this.codeLength = 5,
    this.textStyle,
    this.margin = 16.0,
    this.selectedDecoration,
    this.autoFocus = false,
    this.alignment = MainAxisAlignment.center,
    textController,
  })  : this.textController = textController ?? new TextEditingController(),
        this.selectedBoxSize = selectedBoxSize ?? defaultBoxSize,
        this.defaultDecoration = defaultDecoration ??
            BoxDecoration(
              border: Border.all(color: Colors.black),
            );

  List<Widget> getField() {
    final List<Widget> result = <Widget>[];
    for (int i = 1; i <= codeLength; i++) {
      result.add(Padding(
        padding: EdgeInsets.symmetric(
          horizontal: margin,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            textController.text.length <= i - 1
                ? Align(
                    alignment: Alignment.center,
                    child: Container(
                        height: defaultBoxSize,
                        width: defaultBoxSize,
                        decoration: defaultDecoration),
                  )
                : Container(),
            textController.text.length >= i
                ? Container(
                    decoration: selectedDecoration,
                    width: selectedBoxSize,
                    height: selectedBoxSize,
                    child: Center(
                      child: Text(
                        textController.text[i - 1],
                        style: textStyle,
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: defaultBoxSize >= selectedBoxSize
                ? defaultBoxSize
                : selectedBoxSize,
            child: Row(
              mainAxisAlignment: alignment,
              children: getField(),
            ),
          ),
          defaultTextField(),
        ],
      ),
    );
  }

  Widget defaultTextField() {
    return Opacity(
      opacity: 0.0,
      child: TextField(
        maxLength: codeLength,
        showCursor: false,
        enableSuggestions: false,
        autocorrect: false,
        autofocus: autoFocus,
        enableIMEPersonalizedLearning: false,
        enableInteractiveSelection: false,
        style: TextStyle(color: Colors.transparent),
        decoration: InputDecoration(
            fillColor: Colors.transparent,
            counterStyle: TextStyle(color: Colors.transparent),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
            ),
            filled: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly
        ],
        keyboardType: TextInputType.phone,
        controller: textController,
        onChanged: onChange,
      ),
    );
  }
}
