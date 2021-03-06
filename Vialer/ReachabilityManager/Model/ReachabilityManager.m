//
//  ReachabilityManager.m
//  Copyright © 2015 VoIPGRID. All rights reserved.
//

#import "ReachabilityManager.h"
#import "Configuration.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "Reachability.h"

static NSString * const ReachabilityManagerStatusKey = @"reachabilityStatus";

@interface ReachabilityManager()
@property (strong, nonatomic) Reachability *reachabilityPodInstance;
@property (strong, nonatomic) CTTelephonyNetworkInfo *networkInfo;

@property (nonatomic) ReachabilityManagerStatusType reachabilityStatus;
@end

@implementation ReachabilityManager

#pragma mark - lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

#pragma mark - properties
- (Reachability *)reachabilityPodInstance {
    if (!_reachabilityPodInstance) {
        NSString *sipProxy = [[Configuration defaultConfiguration] UrlForKey:ConfigurationSIPDomain];
        _reachabilityPodInstance = [Reachability reachabilityWithHostName:sipProxy];
    }
    return _reachabilityPodInstance;
}

- (CTTelephonyNetworkInfo *)networkInfo {
    if (!_networkInfo) {
        _networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    }
    return _networkInfo;
}

- (void)setReachabilityStatus:(ReachabilityManagerStatusType)reachabilityStatus {
    if (reachabilityStatus != _reachabilityStatus) {
        [self willChangeValueForKey:ReachabilityManagerStatusKey];
        _reachabilityStatus = reachabilityStatus;
        [self didChangeValueForKey:ReachabilityManagerStatusKey];
    }
}

#pragma mark - start/stop monitoring
- (void)startMonitoring {
    [self currentReachabilityStatus];

    [self.reachabilityPodInstance startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged:) name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(radioAccessChanged:) name:CTRadioAccessTechnologyDidChangeNotification object:nil];
}

- (void)stopMonitoring {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:CTRadioAccessTechnologyDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];

    [self.reachabilityPodInstance stopNotifier];
}

#pragma mark - Status logic
/**
 *  @return Returns Yes if connection is 4g, otherwise No.
 */
- (BOOL)on4g {
    return [self.networkInfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE] && [self hasInternet];
}

/**
 *  @return Returns Yes if connection is Wifi, otherwise No.
 */
- (BOOL)onWiFi {
    return [self.reachabilityPodInstance isReachableViaWiFi] && [self hasInternet];
}

/**
 *  @return Returns Yes if the device has an internet connection, otherwise No.
 */
- (BOOL)hasInternet {
    return [self.reachabilityPodInstance isReachable];
}

/**
 *  For internal use, the function has a side effect of updating the internal reachability status
 *  which is used in a couple of functions inside this class.
 *
 *  @return The current up to date reability status.
 */
- (ReachabilityManagerStatusType)currentReachabilityStatus {
    if ([self on4g] || [self onWiFi]) {
        self.reachabilityStatus = ReachabilityManagerStatusHighSpeed;
    } else if ([self hasInternet]) {
        self.reachabilityStatus = ReachabilityManagerStatusLowSpeed;
    } else {
        self.reachabilityStatus = ReachabilityManagerStatusOffline;
    }
    return self.reachabilityStatus;
}

- (ReachabilityManagerStatusType)resetAndGetCurrentReachabilityStatus {
    self.networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    return [self currentReachabilityStatus];
}

- (NSString *)currentConnectionTypeString {
    if (self.onWiFi) {
        return @"Wifi";
    } else if (self.on4g) {
        return @"4G";
    } else {
        return @"unknown";
    }
}

#pragma mark - Callback functions
- (void)internetConnectionChanged:(NSNotification *)notification {
    [self currentReachabilityStatus];
}

- (void)radioAccessChanged:(NSNotification *)notification {
    [self currentReachabilityStatus];
}

/**
 *  This method will be called via a notification when the app enters the foreground.
 *
 *  @param notification NSNotification instance that is calling this method.
 */
- (void)appWillEnterForeground:(NSNotification *)notification {
    /**
     *  When the app returns from background, the CCTelephonyNetworkInfo doesn't return a currentRadioAccessTechnology.
     *  To fix this, we recreate the instance.
     */
    self.networkInfo = [[CTTelephonyNetworkInfo alloc] init];
}

#pragma mark - KVO overrider
// To override default KVO behaviour for the Reachability status property.
+ (BOOL)automaticallyNotifiesObserversOfReachabilityStatus {
    return NO;
}

@end
