//
//  SettingsViewControllerTests.m
//  Copyright © 2015 VoIPGRID. All rights reserved.
//

#import "SettingsViewController.h"

#import <OCMock/OCMock.h>
#import "SystemUser.h"
#import <XCTest/XCTest.h>

@interface SettingsViewController ()
@property (strong, nonatomic) SystemUser *currentUser;
@end

@interface SettingsViewControllerTests : XCTestCase
@property (nonatomic) SettingsViewController *settingsViewController;
@end

@implementation SettingsViewControllerTests

- (void)setUp {
    [super setUp];
    self.settingsViewController = [[UIStoryboard storyboardWithName:@"SettingsStoryboard" bundle:nil] instantiateViewControllerWithIdentifier:@"SettingsViewController"];
}

- (void)tearDown {
    self.settingsViewController = nil;
    [super tearDown];
}

- (void)testSettingsViewControllerHasBackButton {
    XCTAssertTrue([self.settingsViewController.navigationItem.leftBarButtonItem.title isEqualToString:NSLocalizedString(@"Back", nil)], @"There should be a back button in the navigationbar.");
}

- (void)testChangeSwitchToOffWillSetSipEnabledToOff {
    id mockSystemUser = OCMClassMock([SystemUser class]);
    self.settingsViewController.currentUser = mockSystemUser;
    id mockSwitch = OCMClassMock([UISwitch class]);
    OCMStub([mockSwitch isOn]).andReturn(NO);
    OCMStub([mockSwitch tag]).andReturn(1001);

    [self.settingsViewController didChangeSwitch:mockSwitch];

    OCMVerify([mockSystemUser setSipEnabled:NO]);
}

- (void)testChangeSwitchToOffWillReloadTable {
    id mockSystemUser = OCMClassMock([SystemUser class]);
    id mockTableView = OCMClassMock([UITableView class]);
    self.settingsViewController.currentUser = mockSystemUser;
    self.settingsViewController.tableView = mockTableView;
    id mockSwitch = OCMClassMock([UISwitch class]);
    OCMStub([mockSwitch isOn]).andReturn(NO);
    OCMStub([mockSwitch tag]).andReturn(1001);

    [self.settingsViewController didChangeSwitch:mockSwitch];

    OCMVerify([mockTableView reloadSections:[OCMArg any] withRowAnimation:UITableViewRowAnimationAutomatic]);
}

- (void)testChangeSwitchToOnWillAskUserToGetSipAccount {
    id mockSystemUser = OCMClassMock([SystemUser class]);
    self.settingsViewController.currentUser = mockSystemUser;
    id mockSwitch = OCMClassMock([UISwitch class]);
    OCMStub([mockSwitch isOn]).andReturn(YES);
    OCMStub([mockSwitch tag]).andReturn(1001);

    [self.settingsViewController didChangeSwitch:mockSwitch];

    OCMVerify([mockSystemUser getAndActivateSIPAccountWithCompletion:[OCMArg any]]);
}

- (void)testSystemUserWillReturnErrorWhenFetchingSipAccount {
    id mockSystemUser = OCMClassMock([SystemUser class]);
    OCMStub([mockSystemUser getAndActivateSIPAccountWithCompletion:[OCMArg checkWithBlock:^BOOL(void (^passedBlock)(BOOL success, NSError *error)) {
        passedBlock(NO, [NSError errorWithDomain:@"testDomain" code:-1 userInfo:nil]);
        return YES;
    }]]);

    self.settingsViewController.currentUser = mockSystemUser;
    id mockSwitch = OCMClassMock([UISwitch class]);
    OCMStub([mockSwitch isOn]).andReturn(YES);
    OCMStub([mockSwitch tag]).andReturn(1001);

    [self.settingsViewController didChangeSwitch:mockSwitch];

    OCMVerify([mockSwitch setOn:NO]);
}

- (void)testSystemUserWillReturnNoSuccessWhenFetchingSipAccount {
    id mockSystemUser = OCMClassMock([SystemUser class]);
    OCMStub([mockSystemUser getAndActivateSIPAccountWithCompletion:[OCMArg checkWithBlock:^BOOL(void (^passedBlock)(BOOL success, NSError *error)) {
        passedBlock(NO, nil);
        return YES;
    }]]);

    self.settingsViewController.currentUser = mockSystemUser;
    id mockSwitch = OCMClassMock([UISwitch class]);
    OCMStub([mockSwitch isOn]).andReturn(YES);
    OCMStub([mockSwitch tag]).andReturn(1001);

    [self.settingsViewController didChangeSwitch:mockSwitch];

    OCMVerify([mockSwitch setOn:NO]);
}

- (void)testWhenSipAccountIsFetchedReloadTable {
    id mockSystemUser = OCMClassMock([SystemUser class]);
    OCMStub([mockSystemUser getAndActivateSIPAccountWithCompletion:[OCMArg checkWithBlock:^BOOL(void (^passedBlock)(BOOL success, NSError *error)) {
        passedBlock(YES, nil);
        return YES;
    }]]);
    id mockTableView = OCMClassMock([UITableView class]);
    self.settingsViewController.currentUser = mockSystemUser;
    self.settingsViewController.tableView = mockTableView;
    id mockSwitch = OCMClassMock([UISwitch class]);
    OCMStub([mockSwitch isOn]).andReturn(YES);
    OCMStub([mockSwitch tag]).andReturn(1001);

    [self.settingsViewController didChangeSwitch:mockSwitch];

    OCMVerify([mockTableView reloadSections:[OCMArg any] withRowAnimation:UITableViewRowAnimationAutomatic]);
}

@end
