//
//  SIPCallingViewController.h
//  Copyright © 2016 VoIPGRID. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VialerSIPLib-iOS/VialerSIPLib.h>


@interface SIPCallingViewController : UIViewController

/**
 *  This will setup a SIP call with the provided phonenumber.
 *
 *  @param phoneNumber the phonenumber to be displayed in the UI.
 */
- (void)handleOutgoingCallWithPhoneNumber:(NSString * _Nonnull)phoneNumber;

@end
