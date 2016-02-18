//
//  SipCallingButtonsViewController.h
//  Copyright © 2015 VoIPGRID. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SipCallingButton;
@class VSLCall;

@interface SipCallingButtonsViewController : UIViewController

/**
 *  The currently active call.
 */
@property (weak, nonatomic) VSLCall *call;

/**
 *  Button that can be pressed to toggle hold.
 */
@property (weak, nonatomic) IBOutlet SipCallingButton *holdButton;

/**
 *  Button that can be pressed to toggle mute.
 */
@property (weak, nonatomic) IBOutlet SipCallingButton *muteButton;

/**
 *  Button that can be pressed to toggle speaker mode.
 */
@property (weak, nonatomic) IBOutlet SipCallingButton *speakerButton;

/**
 *  This method will toggle hold on the call.
 *
 *  @param sender SipCallingButton instance that is pressed.
 */
- (IBAction)holdButtonPressed:(SipCallingButton *)sender;

/**
 *  This method will toggle mute on the call.
 *
 *  @param sender SipCallingButton instance that is pressed.
 */
- (IBAction)muteButtonPressed:(SipCallingButton *)sender;

/**
 *  This method will toggle speaker mode on the call.
 *
 *  @param sender SipCallingButton instance that is pressed.
 */
- (IBAction)speakerButtonPressed:(SipCallingButton *)sender;

@end
