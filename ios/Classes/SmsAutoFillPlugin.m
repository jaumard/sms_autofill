#import "SmsAutoFillPlugin.h"

@implementation SmsAutoFillPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"sms_autofill"
            binaryMessenger:[registrar messenger]];
  SmsAutoFillPlugin* instance = [[SmsAutoFillPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  result(nil);
}

@end
