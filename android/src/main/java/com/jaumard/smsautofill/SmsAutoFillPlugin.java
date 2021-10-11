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
import android.telephony.TelephonyManager;

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

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * SmsAutoFillPlugin
 */
public class SmsAutoFillPlugin implements FlutterPlugin, ActivityAware, MethodCallHandler {

    private static final int PHONE_HINT_REQUEST = 11012;
    private static final String channelName = "sms_autofill";

    private Activity activity;
    private Result pendingHintResult;
    private MethodChannel channel;
    private SmsBroadcastReceiver broadcastReceiver;
    private final PluginRegistry.ActivityResultListener activityResultListener = new PluginRegistry.ActivityResultListener() {

        @Override
        public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
            if (requestCode == SmsAutoFillPlugin.PHONE_HINT_REQUEST && pendingHintResult != null) {
                if (resultCode == Activity.RESULT_OK && data != null) {
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
    };

    public SmsAutoFillPlugin() {
    }

    private SmsAutoFillPlugin(Registrar registrar) {
        activity = registrar.activity();
        setupChannel(registrar.messenger());
        registrar.addActivityResultListener(activityResultListener);
    }

    public void setCode(String code) {
        channel.invokeMethod("smscode", code);
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        new SmsAutoFillPlugin(registrar);
    }

    @Override
    public void onMethodCall(MethodCall call, @NonNull final Result result) {
        switch (call.method) {
            case "requestPhoneHint":
                pendingHintResult = result;
                requestHint();
                break;
            case "listenForCode":
                final String smsCodeRegexPattern = call.argument("smsCodeRegexPattern");
                SmsRetrieverClient client = SmsRetriever.getClient(activity);
                Task<Void> task = client.startSmsRetriever();

                task.addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        unregisterReceiver();// unregister existing receiver
                        broadcastReceiver = new SmsBroadcastReceiver(new WeakReference<>(SmsAutoFillPlugin.this),
                                smsCodeRegexPattern);
                        activity.registerReceiver(broadcastReceiver,
                                new IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION));
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
            case "unregisterListener":
                unregisterReceiver();
                result.success("successfully unregister receiver");
                break;
            case "getAppSignature":
                AppSignatureHelper signatureHelper = new AppSignatureHelper(activity.getApplicationContext());
                String appSignature = signatureHelper.getAppSignature();
                result.success(appSignature);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    @TargetApi(Build.VERSION_CODES.ECLAIR)
    private void requestHint() {

        if (!isSimSupport()) {
            if (pendingHintResult != null) {
                pendingHintResult.success(null);
            }
            return;
        }

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
                    SmsAutoFillPlugin.PHONE_HINT_REQUEST, null, 0, 0, 0);
        } catch (IntentSender.SendIntentException e) {
            e.printStackTrace();
        }
    }

    public boolean isSimSupport() {
        TelephonyManager telephonyManager = (TelephonyManager) activity.getSystemService(Context.TELEPHONY_SERVICE);
        return !(telephonyManager.getSimState() == TelephonyManager.SIM_STATE_ABSENT);
    }

    private void setupChannel(BinaryMessenger messenger) {
        channel = new MethodChannel(messenger, SmsAutoFillPlugin.channelName);
        channel.setMethodCallHandler(this);
    }

    private void unregisterReceiver() {
        if (broadcastReceiver != null) {
            try {
                activity.unregisterReceiver(broadcastReceiver);
            } catch (Exception ex) {
                // silent catch to avoir crash if receiver is not registered
            }
            broadcastReceiver = null;
        }
    }

    /**
     * This {@code FlutterPlugin} has been associated with a {@link FlutterEngine} instance.
     *
     * <p>Relevant resources that this {@code FlutterPlugin} may need are provided via the {@code
     * binding}. The {@code binding} may be cached and referenced until {@link #onDetachedFromEngine(FlutterPluginBinding)}
     * is invoked and returns.
     */
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        setupChannel(binding.getBinaryMessenger());
    }

    /**
     * This {@code FlutterPlugin} has been removed from a {@link FlutterEngine} instance.
     *
     * <p>The {@code binding} passed to this method is the same instance that was passed in {@link
     * #onAttachedToEngine(FlutterPluginBinding)}. It is provided again in this method as a convenience. The {@code
     * binding} may be referenced during the execution of this method, but it must not be cached or referenced after
     * this method returns.
     *
     * <p>{@code FlutterPlugin}s should release all resources in this method.
     */
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        unregisterReceiver();
    }

    /**
     * This {@code ActivityAware} {@link FlutterPlugin} is now associated with an {@link Activity}.
     *
     * <p>This method can be invoked in 1 of 2 situations:
     *
     * <ul>
     *   <li>This {@code ActivityAware} {@link FlutterPlugin} was
     *       just added to a {@link FlutterEngine} that was already
     *       connected to a running {@link Activity}.
     *   <li>This {@code ActivityAware} {@link FlutterPlugin} was
     *       already added to a {@link FlutterEngine} and that {@link
     *       FlutterEngine} was just connected to an {@link
     *       Activity}.
     * </ul>
     * <p>
     * The given {@link ActivityPluginBinding} contains {@link Activity}-related
     * references that an {@code ActivityAware} {@link
     * FlutterPlugin} may require, such as a reference to the
     * actual {@link Activity} in question. The {@link ActivityPluginBinding} may be
     * referenced until either {@link #onDetachedFromActivityForConfigChanges()} or {@link
     * #onDetachedFromActivity()} is invoked. At the conclusion of either of those methods, the
     * binding is no longer valid. Clear any references to the binding or its resources, and do not
     * invoke any further methods on the binding or its resources.
     */
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(activityResultListener);
    }

    /**
     * The {@link Activity} that was attached and made available in {@link #onAttachedToActivity(ActivityPluginBinding)}
     * has been detached from this {@code ActivityAware}'s {@link FlutterEngine} for the purpose of processing a
     * configuration change.
     *
     * <p>By the end of this method, the {@link Activity} that was made available in
     * {@link #onAttachedToActivity(ActivityPluginBinding)} is no longer valid. Any references to the associated {@link
     * Activity} or {@link ActivityPluginBinding} should be cleared.
     *
     * <p>This method should be quickly followed by {@link
     * #onReattachedToActivityForConfigChanges(ActivityPluginBinding)}, which signifies that a new {@link Activity} has
     * been created with the new configuration options. That method provides a new {@link ActivityPluginBinding}, which
     * references the newly created and associated {@link Activity}.
     *
     * <p>Any {@code Lifecycle} listeners that were registered in {@link
     * #onAttachedToActivity(ActivityPluginBinding)} should be deregistered here to avoid a possible memory leak and
     * other side effects.
     */
    @Override
    public void onDetachedFromActivityForConfigChanges() {
        unregisterReceiver();
    }

    /**
     * This plugin and its {@link FlutterEngine} have been re-attached to an {@link Activity} after the {@link Activity}
     * was recreated to handle configuration changes.
     *
     * <p>{@code binding} includes a reference to the new instance of the {@link
     * Activity}. {@code binding} and its references may be cached and used from now until either {@link
     * #onDetachedFromActivityForConfigChanges()} or {@link #onDetachedFromActivity()} is invoked. At the conclusion of
     * either of those methods, the binding is no longer valid. Clear any references to the binding or its resources,
     * and do not invoke any further methods on the binding or its resources.
     */
    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(activityResultListener);
    }

    /**
     * This plugin has been detached from an {@link Activity}.
     *
     * <p>Detachment can occur for a number of reasons.
     *
     * <ul>
     *   <li>The app is no longer visible and the {@link Activity} instance has been
     *       destroyed.
     *   <li>The {@link FlutterEngine} that this plugin is connected to
     *       has been detached from its {@link FlutterView}.
     *   <li>This {@code ActivityAware} plugin has been removed from its {@link
     *       FlutterEngine}.
     * </ul>
     * <p>
     * By the end of this method, the {@link Activity} that was made available in {@link
     * #onAttachedToActivity(ActivityPluginBinding)} is no longer valid. Any references to the
     * associated {@link Activity} or {@link ActivityPluginBinding} should be cleared.
     *
     * <p>Any {@code Lifecycle} listeners that were registered in {@link
     * #onAttachedToActivity(ActivityPluginBinding)} or {@link
     * #onReattachedToActivityForConfigChanges(ActivityPluginBinding)} should be deregistered here to
     * avoid a possible memory leak and other side effects.
     */
    @Override
    public void onDetachedFromActivity() {
        unregisterReceiver();
    }

    private static class SmsBroadcastReceiver extends BroadcastReceiver {

        final WeakReference<SmsAutoFillPlugin> plugin;
        final String smsCodeRegexPattern;

        private SmsBroadcastReceiver(WeakReference<SmsAutoFillPlugin> plugin, String smsCodeRegexPattern) {
            this.plugin = plugin;
            this.smsCodeRegexPattern = smsCodeRegexPattern;
        }

        @Override
        public void onReceive(Context context, Intent intent) {
            if (SmsRetriever.SMS_RETRIEVED_ACTION.equals(intent.getAction())) {
                if (plugin.get() == null) {
                    return;
                } else {
                    plugin.get().activity.unregisterReceiver(this);
                }

                Bundle extras = intent.getExtras();
                Status status;
                if (extras != null) {
                    status = (Status) extras.get(SmsRetriever.EXTRA_STATUS);
                    if (status != null) {
                        if (status.getStatusCode() == CommonStatusCodes.SUCCESS) {
                            // Get SMS message contents
                            String message = (String) extras.get(SmsRetriever.EXTRA_SMS_MESSAGE);
                            Pattern pattern = Pattern.compile(smsCodeRegexPattern);
                            if (message != null) {
                                Matcher matcher = pattern.matcher(message);

                                if (matcher.find()) {
                                    plugin.get().setCode(matcher.group(0));
                                } else {
                                    plugin.get().setCode(message);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
