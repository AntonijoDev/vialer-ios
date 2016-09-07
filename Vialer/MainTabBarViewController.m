//
//  MainTabBarViewController.m
//  Vialer
//
//  Created by Bob Voorneveld on 17/11/15.
//  Copyright © 2015 VoIPGRID. All rights reserved.
//

#import "MainTabBarViewController.h"
#import "Configuration.h"

@interface MainTabBarViewController ()

@end

@implementation MainTabBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupLayout];
}

- (void)setupLayout {
    Configuration *config = [Configuration defaultConfiguration];

    // Customize TabBar
    [UITabBar appearance].tintColor = [config.colorConfiguration colorForKey:ConfigurationTabBarTintColor];
    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UIToolbar class]]] setTintColor:[config.colorConfiguration colorForKey:ConfigurationTabBarTintColor]];
    [UITabBar appearance].barTintColor = [config.colorConfiguration colorForKey:ConfigurationTabBarBackgroundColor];
}

@end
