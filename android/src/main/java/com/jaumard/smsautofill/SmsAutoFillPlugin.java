package com.jaumard.smsautofill;

import android.annotation.TargetApi;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.IntentSender;
import android.os.Build;
import android.os.Bundle;
import androidx.annotation.NonNull;

import com.google.android.gms.auth.api.Auth;
import com.google.android.gms.auth.api.credentials.Credential;
import com.google.android.gms.auth.api.credentials.HintRequest;
import com.google.android.gms.auth.api.phone.SmsRetriever;
import com.google.android.gms.auth.api.phone.SmsRetrieverClient;
import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.common.api.GoogleApiClient;
import com.google.android.gms.common.api.Status;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;

import java.lang.ref.WeakReference;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * SmsAutoFillPlugin
 */
public class SmsAutoFillPlugin implements MethodCallHandler {
    private static final int PHONE_HINT_REQUEST = 101012;

    private Activity activity;
    private Result pendingHintResult;
    private MethodChannel channel;
    private SmsBroadcastReceiver broadcastReceiver;

    private SmsAutoFillPlugin(MethodChannel channel, Registrar registrar) {
        this.activity = registrar.activity();
        this.channel = channel;
        registrar.addActivityResultListener(new PluginRegistry.ActivityResultListener() {

            @Override
            public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
                if (requestCode == PHONE_HINT_REQUEST) {
                    if (resultCode == Activity.RESULT_OK) {
                        Credential credential = data.getParcelableExtra(Credential.EXTRA_KEY);
                        final String phoneNumber = credential.getId();
                        pendingHintResult.success(phoneNumber);
                    } else {
                        pendingHintResult.success(null);
                    }
                    return true;
                }
                return false;
            }
        });
    }

    public void setCode(String code) {
        channel.invokeMethod("smscode", code);
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "sms_autofill");
        channel.setMethodCallHandler(new SmsAutoFillPlugin(channel, registrar));
    }

    @Override
    public void onMethodCall(MethodCall call, final Result result) {
        switch (call.method) {
            case "requestPhoneHint":
                pendingHintResult = result;
                requestHint();
                break;
            case "listenForCode":
                SmsRetrieverClient client = SmsRetriever.getClient(activity);
                Task<Void> task = client.startSmsRetriever();

                task.addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        broadcastReceiver = new SmsBroadcastReceiver(new WeakReference<>(SmsAutoFillPlugin.this));
                        activity.registerReceiver(broadcastReceiver, new IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION));
                        result.success(null);
                    }
                });

                task.addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        result.error("ERROR_START_SMS_RETRIEVER", "Can't start sms retriever", null);
                    }
                });
                break;
            case "getPlatformVersion":
                pendingHintResult = result;
                requestHint();
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @TargetApi(Build.VERSION_CODES.ECLAIR)
    private void requestHint() {
        HintRequest hintRequest = new HintRequest.Builder()
                .setPhoneNumberIdentifierSupported(true)
                .build();
        GoogleApiClient mCredentialsClient = new GoogleApiClient.Builder(activity)
                .addApi(Auth.CREDENTIALS_API)
                .build();
        PendingIntent intent = Auth.CredentialsApi.getHintPickerIntent(
                mCredentialsClient, hintRequest);
        try {
            activity.startIntentSenderForResult(intent.getIntentSender(),
                    PHONE_HINT_REQUEST, null, 0, 0, 0);
        } catch (IntentSender.SendIntentException e) {
            e.printStackTrace();
        }
    }

    private static class SmsBroadcastReceiver extends BroadcastReceiver {
        final WeakReference<SmsAutoFillPlugin> plugin;

        private SmsBroadcastReceiver(WeakReference<SmsAutoFillPlugin> plugin) {
            this.plugin = plugin;
        }

        @Override
        public void onReceive(Context context, Intent intent) {
            if (SmsRetriever.SMS_RETRIEVED_ACTION.equals(intent.getAction())) {
                if (plugin.get() == null) {
                    return;
                }
                else {
                    plugin.get().activity.unregisterReceiver(this);
                }

                Bundle extras = intent.getExtras();
                Status status;
                if (extras != null) {
                    status = (Status) extras.get(SmsRetriever.EXTRA_STATUS);
                    if (status != null) {
                        switch (status.getStatusCode()) {
                            case CommonStatusCodes.SUCCESS:
                                // Get SMS message contents
                                String message = (String) extras.get(SmsRetriever.EXTRA_SMS_MESSAGE);
                                Pattern pattern = Pattern.compile("\\d{4,6}");
                                if (message != null) {
                                    Matcher matcher = pattern.matcher(message);

                                    if (matcher.find()) {
                                        plugin.get().setCode(matcher.group(0));
                                    } else {
                                        plugin.get().setCode(message);
                                    }
                                    return;
                                }
                        }
                    }
                }
                plugin.get().setCode(null);
            }
        }
    }
}
