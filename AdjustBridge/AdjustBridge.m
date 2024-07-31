//
//  AdjustBridge.m
//  Adjust SDK
//
//  Created by Pedro Filipe (@nonelse) on 27th April 2016.
//  Copyright © 2016-2018 Adjust GmbH. All rights reserved.
//

#import "AdjustBridge.h"
#import <AdjustSdk/AdjustSdk.h>
#import "AdjustBridgeRegister.h"
#import "WKWebViewJavascriptBridge.h"

@interface AdjustBridge() <AdjustDelegate>

@property BOOL isDeferredDeeplinkOpeningEnabled;
@property (nonatomic, copy) NSString *fbPixelDefaultEventToken;
@property (nonatomic, copy) NSString *attributionCallbackName;
@property (nonatomic, copy) NSString *eventSuccessCallbackName;
@property (nonatomic, copy) NSString *eventFailureCallbackName;
@property (nonatomic, copy) NSString *sessionSuccessCallbackName;
@property (nonatomic, copy) NSString *sessionFailureCallbackName;
@property (nonatomic, copy) NSString *deferredDeeplinkCallbackName;
@property (nonatomic, copy) NSString *skanUpdatedCallbackName;
@property (nonatomic, strong) NSMutableDictionary *fbPixelMapping;
@property (nonatomic, strong) NSMutableArray *urlStrategyDomains;
@property (nonatomic, strong) ADJAttribution *attribution;
@property (nonatomic, strong) ADJLogger *logger;

@end

@implementation AdjustBridge

#pragma mark - Object lifecycle

- (id)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _bridgeRegister = nil;
    self.isDeferredDeeplinkOpeningEnabled = YES;
    _logger = [[ADJLogger alloc] init];

    [self resetAdjustBridge];

    return self;
}

- (void)resetAdjustBridge {
    self.attributionCallbackName = nil;
    self.eventSuccessCallbackName = nil;
    self.eventFailureCallbackName = nil;
    self.sessionSuccessCallbackName = nil;
    self.sessionFailureCallbackName = nil;
    self.deferredDeeplinkCallbackName = nil;
    self.skanUpdatedCallbackName = nil;
}

#pragma mark - AdjustDelegate methods

- (void)adjustAttributionChanged:(ADJAttribution *)attribution {
    if (self.attributionCallbackName == nil) {
        return;
    }
    [self.bridgeRegister callHandler:self.attributionCallbackName data:[attribution dictionary]];
}

- (void)adjustEventTrackingSucceeded:(ADJEventSuccess *)eventSuccessResponseData {
    if (self.eventSuccessCallbackName == nil) {
        return;
    }

    NSMutableDictionary *eventSuccessResponseDataDictionary = [NSMutableDictionary dictionary];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.message forKey:@"message"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.timestamp forKey:@"timestamp"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.adid forKey:@"adid"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.eventToken forKey:@"eventToken"];
    [eventSuccessResponseDataDictionary setValue:eventSuccessResponseData.callbackId forKey:@"callbackId"];

    NSString *jsonResponse = [self convertJsonDictionaryToNSString:eventSuccessResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [eventSuccessResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self.bridgeRegister callHandler:self.eventSuccessCallbackName data:eventSuccessResponseDataDictionary];
}

- (void)adjustEventTrackingFailed:(ADJEventFailure *)eventFailureResponseData {
    if (self.eventFailureCallbackName == nil) {
        return;
    }

    NSMutableDictionary *eventFailureResponseDataDictionary = [NSMutableDictionary dictionary];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.message forKey:@"message"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.timestamp forKey:@"timestamp"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.adid forKey:@"adid"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.eventToken forKey:@"eventToken"];
    [eventFailureResponseDataDictionary setValue:eventFailureResponseData.callbackId forKey:@"callbackId"];
    [eventFailureResponseDataDictionary setValue:[NSNumber numberWithBool:eventFailureResponseData.willRetry] forKey:@"willRetry"];

    NSString *jsonResponse = [self convertJsonDictionaryToNSString:eventFailureResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [eventFailureResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self.bridgeRegister callHandler:self.eventFailureCallbackName data:eventFailureResponseDataDictionary];
}

- (void)adjustSessionTrackingSucceeded:(ADJSessionSuccess *)sessionSuccessResponseData {
    if (self.sessionSuccessCallbackName == nil) {
        return;
    }

    NSMutableDictionary *sessionSuccessResponseDataDictionary = [NSMutableDictionary dictionary];
    [sessionSuccessResponseDataDictionary setValue:sessionSuccessResponseData.message forKey:@"message"];
    [sessionSuccessResponseDataDictionary setValue:sessionSuccessResponseData.timestamp forKey:@"timestamp"];
    [sessionSuccessResponseDataDictionary setValue:sessionSuccessResponseData.adid forKey:@"adid"];

    NSString *jsonResponse = [self convertJsonDictionaryToNSString:sessionSuccessResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [sessionSuccessResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self.bridgeRegister callHandler:self.sessionSuccessCallbackName data:sessionSuccessResponseDataDictionary];
}

- (void)adjustSessionTrackingFailed:(ADJSessionFailure *)sessionFailureResponseData {
    if (self.sessionFailureCallbackName == nil) {
        return;
    }

    NSMutableDictionary *sessionFailureResponseDataDictionary = [NSMutableDictionary dictionary];
    [sessionFailureResponseDataDictionary setValue:sessionFailureResponseData.message forKey:@"message"];
    [sessionFailureResponseDataDictionary setValue:sessionFailureResponseData.timestamp forKey:@"timestamp"];
    [sessionFailureResponseDataDictionary setValue:sessionFailureResponseData.adid forKey:@"adid"];
    [sessionFailureResponseDataDictionary setValue:[NSNumber numberWithBool:sessionFailureResponseData.willRetry] forKey:@"willRetry"];

    NSString *jsonResponse = [self convertJsonDictionaryToNSString:sessionFailureResponseData.jsonResponse];
    if (jsonResponse == nil) {
        jsonResponse = @"{}";
    }
    [sessionFailureResponseDataDictionary setValue:jsonResponse forKey:@"jsonResponse"];

    [self.bridgeRegister callHandler:self.sessionFailureCallbackName data:sessionFailureResponseDataDictionary];
}

- (BOOL)adjustDeferredDeeplinkReceived:(NSURL *)deeplink {
    if (self.deferredDeeplinkCallbackName) {
        [self.bridgeRegister callHandler:self.deferredDeeplinkCallbackName data:[deeplink absoluteString]];
    }
    return self.isDeferredDeeplinkOpeningEnabled;
}

- (void)adjustSkanUpdatedWithConversionData:(nonnull NSDictionary<NSString *, NSString *> *)data {
    if (self.skanUpdatedCallbackName == nil) {
        return;
    }

    NSMutableDictionary *skanUpdatedDictionary = [NSMutableDictionary dictionary];
    [skanUpdatedDictionary setValue:data[@"conversion_value"] forKey:@"conversionValue"];
    [skanUpdatedDictionary setValue:data[@"coarse_value"] forKey:@"coarseValue"];
    [skanUpdatedDictionary setValue:data[@"lock_window"] forKey:@"lockWindow"];
    [skanUpdatedDictionary setValue:data[@"error"] forKey:@"error"];

    [self.bridgeRegister callHandler:self.skanUpdatedCallbackName data:skanUpdatedDictionary];
}

#pragma mark - Public methods

- (void)augmentHybridWebView {
    NSString *fbAppId = [self getFbAppId];

    if (fbAppId == nil) {
        [self.logger error:@"FacebookAppID is not correctly configured in the pList"];
        return;
    }
    [_bridgeRegister augmentHybridWebView:fbAppId];
    [self registerAugmentedView];
}

- (void)loadWKWebViewBridge:(WKWebView *)wkWebView {
    [self loadWKWebViewBridge:wkWebView wkWebViewDelegate:nil];
}

- (void)loadWKWebViewBridge:(WKWebView *)wkWebView
          wkWebViewDelegate:(id<WKNavigationDelegate>)wkWebViewDelegate {
    if (self.bridgeRegister != nil) {
        // WebViewBridge already loaded
        return;
    }

    _bridgeRegister = [[AdjustBridgeRegister alloc] initWithWKWebView:wkWebView];
    [self.bridgeRegister setWKWebViewDelegate:wkWebViewDelegate];

    [self.bridgeRegister registerHandler:@"adjust_initSdk" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *appToken = [data objectForKey:@"appToken"];
        NSString *environment = [data objectForKey:@"environment"];
        NSString *allowSuppressLogLevel = [data objectForKey:@"allowSuppressLogLevel"];
        NSString *sdkPrefix = [data objectForKey:@"sdkPrefix"];
        NSString *defaultTracker = [data objectForKey:@"defaultTracker"];
        NSString *externalDeviceId = [data objectForKey:@"externalDeviceId"];
        NSString *logLevel = [data objectForKey:@"logLevel"];
        NSNumber *sendInBackground = [data objectForKey:@"sendInBackground"];
        NSNumber *isCostDataInAttributionEnabled = [data objectForKey:@"isCostDataInAttributionEnabled"];
        NSNumber *isAdServicesEnabled = [data objectForKey:@"isAdServicesEnabled"];
        NSNumber *isIdfaReadingAllowed = [data objectForKey:@"isIdfaReadingAllowed"];
        NSNumber *isCoppaComplianceEnabled = [data objectForKey:@"isCoppaComplianceEnabled"];
        NSNumber *isSkanAttributionHandlingEnabled = [data objectForKey:@"isSkanAttributionHandlingEnabled"];
        NSNumber *isDeferredDeeplinkOpeningEnabled = [data objectForKey:@"isDeferredDeeplinkOpeningEnabled"];
        NSString *fbPixelDefaultEventToken = [data objectForKey:@"fbPixelDefaultEventToken"];
        id fbPixelMapping = [data objectForKey:@"fbPixelMapping"];
        NSString *attributionCallback = [data objectForKey:@"attributionCallback"];
        NSString *eventSuccessCallback = [data objectForKey:@"eventSuccessCallback"];
        NSString *eventFailureCallback = [data objectForKey:@"eventFailureCallback"];
        NSString *sessionSuccessCallback = [data objectForKey:@"sessionSuccessCallback"];
        NSString *sessionFailureCallback = [data objectForKey:@"sessionFailureCallback"];
        NSString *deferredDeeplinkCallback = [data objectForKey:@"deferredDeeplinkCallback"];
        NSString *skanUpdatedCallback = [data objectForKey:@"skanUpdatedCallback"];
        NSNumber *shouldReadDeviceInfoOnce = [data objectForKey:@"shouldReadDeviceInfoOnce"];
        NSNumber *attConsentWaitingSeconds = [data objectForKey:@"attConsentWaitingSeconds"];
        NSNumber *eventDeduplicationIdsMaxSize = [data objectForKey:@"eventDeduplicationIdsMaxSize"];
        id urlStrategyDomains = [data objectForKey:@"urlStrategyDomains"];
        NSNumber *useSubdomains = [data objectForKey:@"useSubdomains"];
        NSNumber *isDataResidency = [data objectForKey:@"isDataResidency"];

        ADJConfig *adjustConfig;
        if ([self isFieldValid:allowSuppressLogLevel]) {
            adjustConfig = [[ADJConfig alloc] initWithAppToken:appToken
                                                   environment:environment
                                              suppressLogLevel:[allowSuppressLogLevel boolValue]];
        } else {
            adjustConfig = [[ADJConfig alloc] initWithAppToken:appToken
                                                   environment:environment];
        }

        // no need to continue if adjust config is not valid
        if (![adjustConfig isValid]) {
            return;
        }

        if ([self isFieldValid:sdkPrefix]) {
            [adjustConfig setSdkPrefix:sdkPrefix];
        }
        if ([self isFieldValid:defaultTracker]) {
            [adjustConfig setDefaultTracker:defaultTracker];
        }
        if ([self isFieldValid:externalDeviceId]) {
            [adjustConfig setExternalDeviceId:externalDeviceId];
        }
        if ([self isFieldValid:logLevel]) {
            [adjustConfig setLogLevel:[ADJLogger logLevelFromString:[logLevel lowercaseString]]];
        }
        if ([self isFieldValid:sendInBackground]) {
            if ([sendInBackground boolValue] == YES) {
                [adjustConfig enableSendingInBackground];
            }
        }
        if ([self isFieldValid:isCostDataInAttributionEnabled]) {
            if ([isCostDataInAttributionEnabled boolValue] == YES) {
                [adjustConfig enableCostDataInAttribution];
            }
        }
        if ([self isFieldValid:isAdServicesEnabled]) {
            if ([isAdServicesEnabled boolValue] == NO) {
                [adjustConfig disableAdServices];
            }
        }
        if ([self isFieldValid:isIdfaReadingAllowed]) {
            if ([isIdfaReadingAllowed boolValue] == NO) {
                [adjustConfig disableIdfaReading];
            }
        }
        if ([self isFieldValid:isCoppaComplianceEnabled]) {
            if ([isCoppaComplianceEnabled boolValue] == YES) {
                [adjustConfig enableCoppaCompliance];
            }
        }
        if ([self isFieldValid:attConsentWaitingSeconds]) {
            [adjustConfig setAttConsentWaitingInterval:[attConsentWaitingSeconds doubleValue]];
        }
        if ([self isFieldValid:isSkanAttributionHandlingEnabled]) {
            if ([isSkanAttributionHandlingEnabled boolValue] == NO) {
                [adjustConfig disableSkanAttribution];
            }
        }
        if ([self isFieldValid:isDeferredDeeplinkOpeningEnabled]) {
            self.isDeferredDeeplinkOpeningEnabled = [isDeferredDeeplinkOpeningEnabled boolValue];
        }
        if ([self isFieldValid:fbPixelDefaultEventToken]) {
            self.fbPixelDefaultEventToken = fbPixelDefaultEventToken;
        }
        if ([fbPixelMapping count] > 0) {
            self.fbPixelMapping = [[NSMutableDictionary alloc] initWithCapacity:[fbPixelMapping count] / 2];
        }
        for (int i = 0; i < [fbPixelMapping count]; i += 2) {
            NSString *key = [[fbPixelMapping objectAtIndex:i] description];
            NSString *value = [[fbPixelMapping objectAtIndex:(i + 1)] description];
            [self.fbPixelMapping setObject:value forKey:key];
        }
        if ([self isFieldValid:attributionCallback]) {
            self.attributionCallbackName = attributionCallback;
        }
        if ([self isFieldValid:eventSuccessCallback]) {
            self.eventSuccessCallbackName = eventSuccessCallback;
        }
        if ([self isFieldValid:eventFailureCallback]) {
            self.eventFailureCallbackName = eventFailureCallback;
        }
        if ([self isFieldValid:sessionSuccessCallback]) {
            self.sessionSuccessCallbackName = sessionSuccessCallback;
        }
        if ([self isFieldValid:sessionFailureCallback]) {
            self.sessionFailureCallbackName = sessionFailureCallback;
        }
        if ([self isFieldValid:deferredDeeplinkCallback]) {
            self.deferredDeeplinkCallbackName = deferredDeeplinkCallback;
        }
        if ([self isFieldValid:skanUpdatedCallback]) {
            self.skanUpdatedCallbackName = skanUpdatedCallback;
        }

        // set self as delegate if any callback is configured
        // change to swizzle the methods in the future
        if (self.attributionCallbackName != nil
            || self.eventSuccessCallbackName != nil
            || self.eventFailureCallbackName != nil
            || self.sessionSuccessCallbackName != nil
            || self.sessionFailureCallbackName != nil
            || self.deferredDeeplinkCallbackName != nil
            || self.skanUpdatedCallbackName != nil) {
            [adjustConfig setDelegate:self];
        }
        if ([self isFieldValid:shouldReadDeviceInfoOnce]) {
            if ([shouldReadDeviceInfoOnce boolValue] == YES) {
                [adjustConfig enableDeviceIdsReadingOnce];
            }
        }
        if ([self isFieldValid:eventDeduplicationIdsMaxSize]) {
            [adjustConfig setEventDeduplicationIdsMaxSize:[eventDeduplicationIdsMaxSize integerValue]];
        }

        // URL strategy
        if (urlStrategyDomains != nil && [urlStrategyDomains count] > 0) {
            self.urlStrategyDomains = [[NSMutableArray alloc] initWithCapacity:[urlStrategyDomains count]];
            for (int i = 0; i < [urlStrategyDomains count]; i += 1) {
                NSString *domain = [[urlStrategyDomains objectAtIndex:i] description];
                [self.urlStrategyDomains addObject:domain];
            }
        }
        if ([self isFieldValid:useSubdomains] && [self isFieldValid:isDataResidency]) {
            [adjustConfig setUrlStrategy:(NSArray *)self.urlStrategyDomains
                           useSubdomains:[useSubdomains boolValue]
                         isDataResidency:[isDataResidency boolValue]];
        }

        [Adjust initSdk:adjustConfig];
    }];

    [self.bridgeRegister registerHandler:@"adjust_trackEvent" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *eventToken = [data objectForKey:@"eventToken"];
        NSString *revenue = [data objectForKey:@"revenue"];
        NSString *currency = [data objectForKey:@"currency"];
        NSString *deduplicationId = [data objectForKey:@"deduplicationId"];
        NSString *callbackId = [data objectForKey:@"callbackId"];
        id callbackParameters = [data objectForKey:@"callbackParameters"];
        id partnerParameters = [data objectForKey:@"partnerParameters"];

        ADJEvent *adjustEvent = [[ADJEvent alloc] initWithEventToken:eventToken];
        // no need to continue if adjust event is not valid
        if (![adjustEvent isValid]) {
            return;
        }

        if ([self isFieldValid:revenue] && [self isFieldValid:currency]) {
            double revenueValue = [revenue doubleValue];
            [adjustEvent setRevenue:revenueValue currency:currency];
        }
        if ([self isFieldValid:deduplicationId]) {
            [adjustEvent setDeduplicationId:deduplicationId];
        }
        if ([self isFieldValid:callbackId]) {
            [adjustEvent setCallbackId:callbackId];
        }
        for (int i = 0; i < [callbackParameters count]; i += 2) {
            NSString *key = [[callbackParameters objectAtIndex:i] description];
            NSString *value = [[callbackParameters objectAtIndex:(i + 1)] description];
            [adjustEvent addCallbackParameter:key value:value];
        }
        for (int i = 0; i < [partnerParameters count]; i += 2) {
            NSString *key = [[partnerParameters objectAtIndex:i] description];
            NSString *value = [[partnerParameters objectAtIndex:(i + 1)] description];
            [adjustEvent addPartnerParameter:key value:value];
        }

        [Adjust trackEvent:adjustEvent];
    }];

    [self.bridgeRegister registerHandler:@"adjust_trackSubsessionStart" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust trackSubsessionStart];
    }];

    [self.bridgeRegister registerHandler:@"adjust_trackSubsessionEnd" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust trackSubsessionEnd];
    }];

    [self.bridgeRegister registerHandler:@"adjust_enable" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust enable];
    }];

    [self.bridgeRegister registerHandler:@"adjust_disable" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust disable];
    }];

    [self.bridgeRegister registerHandler:@"adjust_isEnabled" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }
        __block WVJBResponseCallback localResponseCallback = responseCallback;
        [Adjust isEnabledWithCompletionHandler:^(BOOL isEnabled) {
            localResponseCallback([NSNumber numberWithBool:isEnabled]);
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_switchToOfflineMode" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust switchToOfflineMode];
    }];

    [self.bridgeRegister registerHandler:@"adjust_switchBackToOnlineMode" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust switchBackToOnlineMode];
    }];

    [self.bridgeRegister registerHandler:@"adjust_sdkVersion" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }

        __block NSString *_Nullable localSdkPrefix = (NSString *)data;
        __block WVJBResponseCallback localResponseCallback = responseCallback;
        [Adjust sdkVersionWithCompletionHandler:^(NSString * _Nullable sdkVersion) {
            NSString *joinedSdkVersion = [NSString stringWithFormat:@"%@@%@", localSdkPrefix, sdkVersion];
            localResponseCallback(joinedSdkVersion);
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_idfa" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }

        __block WVJBResponseCallback localResponseCallback = responseCallback;
        [Adjust idfaWithCompletionHandler:^(NSString * _Nullable idfa) {
            localResponseCallback(idfa);
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_idfv" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }

        __block WVJBResponseCallback localResponseCallback = responseCallback;
        [Adjust idfvWithCompletionHandler:^(NSString * _Nullable idfv) {
            localResponseCallback(idfv);
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_requestAppTrackingAuthorizationWithCompletionHandler" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }
        
        [Adjust requestAppTrackingAuthorizationWithCompletionHandler:^(NSUInteger status) {
            responseCallback([NSNumber numberWithUnsignedInteger:status]);
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_appTrackingAuthorizationStatus" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }

        responseCallback([NSNumber numberWithInt:[Adjust appTrackingAuthorizationStatus]]);
    }];

    [self.bridgeRegister registerHandler:@"adjust_updateSkanConversionValueCoarseValueLockWindowCompletionHandler"
                                 handler:^(id data, WVJBResponseCallback responseCallback) {
        NSNumber *conversionValue = [data objectForKey:@"conversionValue"];
        NSString *coarseValue = [data objectForKey:@"coarseValue"];
        NSNumber *lockWindow = [data objectForKey:@"lockWindow"];
        [Adjust updateSkanConversionValue:[conversionValue integerValue]
                              coarseValue:coarseValue
                               lockWindow:lockWindow
                    withCompletionHandler:^(NSError * _Nullable error){
            if (error != nil) {
                responseCallback([NSString stringWithFormat:@"%@", error]);
            }
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_adid" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }

        __block WVJBResponseCallback localResponseCallback = responseCallback;
        [Adjust adidWithCompletionHandler:^(NSString * _Nullable adid) {
            localResponseCallback(adid);
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_attribution" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (responseCallback == nil) {
            return;
        }

        __block WVJBResponseCallback localResponseCallback = responseCallback;
        [Adjust attributionWithCompletionHandler:^(ADJAttribution * _Nullable attribution) {
            NSDictionary *attributionDictionary = nil;
            if (attribution != nil) {
                attributionDictionary = [attribution dictionary];
            }
            localResponseCallback(attributionDictionary);
        }];
    }];

    [self.bridgeRegister registerHandler:@"adjust_addGlobalCallbackParameter" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *key = [data objectForKey:@"key"];
        NSString *value = [data objectForKey:@"value"];
        [Adjust addGlobalCallbackParameter:value forKey:key];
    }];

    [self.bridgeRegister registerHandler:@"adjust_addGlobalPartnerParameter" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *key = [data objectForKey:@"key"];
        NSString *value = [data objectForKey:@"value"];
        [Adjust addGlobalPartnerParameter:value forKey:key];
    }];

    [self.bridgeRegister registerHandler:@"adjust_removeGlobalCallbackParameter" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (![data isKindOfClass:[NSString class]]) {
            return;
        }
        [Adjust removeGlobalCallbackParameterForKey:(NSString *)data];
    }];

    [self.bridgeRegister registerHandler:@"adjust_removeGlobalPartnerParameter" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (![data isKindOfClass:[NSString class]]) {
            return;
        }
        [Adjust removeGlobalPartnerParameterForKey:(NSString *)data];
    }];

    [self.bridgeRegister registerHandler:@"adjust_removeGlobalCallbackParameters" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust removeGlobalCallbackParameters];
    }];

    [self.bridgeRegister registerHandler:@"adjust_removeGlobalPartnerParameters" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust removeGlobalPartnerParameters];
    }];

    [self.bridgeRegister registerHandler:@"adjust_gdprForgetMe" handler:^(id data, WVJBResponseCallback responseCallback) {
        [Adjust gdprForgetMe];
    }];

    [self.bridgeRegister registerHandler:@"adjust_trackThirdPartySharing" handler:^(id data, WVJBResponseCallback responseCallback) {
        id isEnabledO = [data objectForKey:@"isEnabled"];
        id granularOptions = [data objectForKey:@"granularOptions"];
        id partnerSharingSettings = [data objectForKey:@"partnerSharingSettings"];

        NSNumber *isEnabled = nil;
        if ([isEnabledO isKindOfClass:[NSNumber class]]) {
            isEnabled = (NSNumber *)isEnabledO;
        }
        ADJThirdPartySharing *adjustThirdPartySharing =
        [[ADJThirdPartySharing alloc] initWithIsEnabled:isEnabled];
        for (int i = 0; i < [granularOptions count]; i += 3) {
            NSString *partnerName = [[granularOptions objectAtIndex:i] description];
            NSString *key = [[granularOptions objectAtIndex:(i + 1)] description];
            NSString *value = [[granularOptions objectAtIndex:(i + 2)] description];
            [adjustThirdPartySharing addGranularOption:partnerName key:key value:value];
        }
        for (int i = 0; i < [partnerSharingSettings count]; i += 3) {
            NSString *partnerName = [[partnerSharingSettings objectAtIndex:i] description];
            NSString *key = [[partnerSharingSettings objectAtIndex:(i + 1)] description];
            BOOL value = [[partnerSharingSettings objectAtIndex:(i + 2)] boolValue];
            [adjustThirdPartySharing addPartnerSharingSetting:partnerName key:key value:value];
        }

        [Adjust trackThirdPartySharing:adjustThirdPartySharing];
    }];

    [self.bridgeRegister registerHandler:@"adjust_trackMeasurementConsent" handler:^(id data, WVJBResponseCallback responseCallback) {
        if (![data isKindOfClass:[NSNumber class]]) {
            return;
        }
        [Adjust trackMeasurementConsent:[(NSNumber *)data boolValue]];
    }];

    [self.bridgeRegister registerHandler:@"adjust_setTestOptions" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *urlOverwrite = [data objectForKey:@"urlOverwrite"];
        NSString *extraPath = [data objectForKey:@"extraPath"];
        NSNumber *timerIntervalInMilliseconds = [data objectForKey:@"timerIntervalInMilliseconds"];
        NSNumber *timerStartInMilliseconds = [data objectForKey:@"timerStartInMilliseconds"];
        NSNumber *sessionIntervalInMilliseconds = [data objectForKey:@"sessionIntervalInMilliseconds"];
        NSNumber *subsessionIntervalInMilliseconds = [data objectForKey:@"subsessionIntervalInMilliseconds"];
        NSNumber *teardown = [data objectForKey:@"teardown"];
        NSNumber *deleteState = [data objectForKey:@"deleteState"];
        NSNumber *noBackoffWait = [data objectForKey:@"noBackoffWait"];
        NSNumber *adServicesFrameworkEnabled = [data objectForKey:@"adServicesFrameworkEnabled"];
        NSNumber *attStatus = [data objectForKey:@"attStatus"];
        NSString *idfa = [data objectForKey:@"idfa"];

        NSMutableDictionary *testOptions = [NSMutableDictionary dictionary];

        if ([self isFieldValid:urlOverwrite]) {
            [testOptions setObject:urlOverwrite forKey:@"testUrlOverwrite"];
        }
        if ([self isFieldValid:extraPath]) {
            [testOptions setObject:extraPath forKey:@"extraPath"];
        }
        if ([self isFieldValid:timerIntervalInMilliseconds]) {
            [testOptions setObject:timerIntervalInMilliseconds forKey:@"timerIntervalInMilliseconds"];
        }
        if ([self isFieldValid:timerStartInMilliseconds]) {
            [testOptions setObject:timerStartInMilliseconds forKey:@"timerStartInMilliseconds"];
        }
        if ([self isFieldValid:sessionIntervalInMilliseconds]) {
            [testOptions setObject:sessionIntervalInMilliseconds forKey:@"sessionIntervalInMilliseconds"];
        }
        if ([self isFieldValid:subsessionIntervalInMilliseconds]) {
            [testOptions setObject:subsessionIntervalInMilliseconds forKey:@"subsessionIntervalInMilliseconds"];
        }
        if ([self isFieldValid:attStatus]) {
            [testOptions setObject:attStatus forKey:@"attStatusInt"];
        }
        if ([self isFieldValid:idfa]) {
            [testOptions setObject:idfa forKey:@"idfa"];
        }
        if ([self isFieldValid:teardown]) {
            [testOptions setObject:teardown forKey:@"teardown"];
            if ([teardown boolValue] == YES) {
                [self resetAdjustBridge];
            }
        }
        if ([self isFieldValid:deleteState]) {
            [testOptions setObject:deleteState forKey:@"deleteState"];
        }
        if ([self isFieldValid:noBackoffWait]) {
            [testOptions setObject:noBackoffWait forKey:@"noBackoffWait"];
        }
        if ([self isFieldValid:adServicesFrameworkEnabled]) {
            [testOptions setObject:adServicesFrameworkEnabled forKey:@"adServicesFrameworkEnabled"];
        }

        [Adjust setTestOptions:testOptions];
    }];
}

- (void)registerAugmentedView {
    [self.bridgeRegister registerHandler:@"adjust_fbPixelEvent" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSString *pixelID = [data objectForKey:@"pixelID"];
        if (pixelID == nil) {
            [self.logger error:@"Can't bridge an event without a referral Pixel ID. Check your webview Pixel configuration"];
            return;
        }
        NSString *evtName = [data objectForKey:@"evtName"];
        NSString *eventToken = [self getEventTokenFromFbPixelEventName:evtName];
        if (eventToken == nil) {
            [self.logger debug:@"No mapping found for the fb pixel event %@, trying to fall back to the default event token", evtName];
            eventToken = self.fbPixelDefaultEventToken;
        }
        if (eventToken == nil) {
            [self.logger  debug:@"There is not a default event token configured or a mapping found for event named: '%@'. It won't be tracked as an adjust event", evtName];
            return;
        }

        ADJEvent *fbPixelEvent = [[ADJEvent alloc] initWithEventToken:eventToken];
        if (![fbPixelEvent isValid]) {
            return;
        }

        id customData = [data objectForKey:@"customData"];
        [fbPixelEvent addPartnerParameter:@"_fb_pixel_referral_id" value:pixelID];
        // [fbPixelEvent addPartnerParameter:@"_eventName" value:evtName];
        if ([customData isKindOfClass:[NSString class]]) {
            NSError *jsonParseError = nil;
            NSDictionary *params = [NSJSONSerialization JSONObjectWithData:[customData dataUsingEncoding:NSUTF8StringEncoding]
                                                                   options:NSJSONReadingMutableContainers
                                                                     error:&jsonParseError];
            [params enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                NSString *keyS = [key description];
                NSString *valueS = [obj description];
                [fbPixelEvent addPartnerParameter:keyS value:valueS];
            }];
        }
        [Adjust trackEvent:fbPixelEvent];
    }];
}

#pragma mark - Private & helper methods

- (BOOL)isFieldValid:(NSObject *)field {
    if (field == nil) {
        return NO;
    }
    if ([field isKindOfClass:[NSNull class]]) {
        return NO;
    }
    if ([[field description] length] == 0) {
        return NO;
    }
    return !!field;
}

- (NSString *)getFbAppId {
    NSString *facebookLoggingOverrideAppID = [self getValueFromBundleByKey:@"FacebookLoggingOverrideAppID"];
    if (facebookLoggingOverrideAppID != nil) {
        return facebookLoggingOverrideAppID;
    }

    return [self getValueFromBundleByKey:@"FacebookAppID"];
}

- (NSString *)getValueFromBundleByKey:(NSString *)key {
    return [[[NSBundle mainBundle] objectForInfoDictionaryKey:key] copy];
}

- (NSString *)getEventTokenFromFbPixelEventName:(NSString *)fbPixelEventName {
    if (self.fbPixelMapping == nil) {
        return nil;
    }

    return [self.fbPixelMapping objectForKey:fbPixelEventName];
}

- (NSString *)convertJsonDictionaryToNSString:(NSDictionary *)jsonDictionary {
    if (jsonDictionary == nil) {
        return nil;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDictionary
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData) {
        NSLog(@"Unable to conver NSDictionary with JSON response to JSON string: %@", error);
        return nil;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

- (NSNumber *)fieldToNSNumber:(NSObject *)field {
    if (![self isFieldValid:field]) {
        return nil;
    }
    NSNumberFormatter *formatString = [[NSNumberFormatter alloc] init];
    return [formatString numberFromString:[field description]];
}

@end
