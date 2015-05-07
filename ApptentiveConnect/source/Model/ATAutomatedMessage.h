//
//  ATAutomatedMessage.h
//  ApptentiveConnect
//
//  Created by Andrew Wooster on 10/19/12.
//  Copyright (c) 2012 Apptentive, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "ATTextMessage.h"

@interface ATAutomatedMessage : ATTextMessage

@property (nonatomic, strong) NSString *title;

@end
