//
//  MHJsonColorManager.h
//  MongoHub
//
//  Created by Jérôme Lebel on 29/08/2014.
//
//

#import <AppKit/AppKit.h>

#define MHJsonColorManagerHasBeenUpdatedNotification @"MHJsonColorManagerHasBeenUpdatedNotification"

@interface MHJsonColorManager : NSObject
{
    NSMutableDictionary                     *_values;
}

@property (nonatomic, readonly, strong) NSDictionary *values;

+ (instancetype)sharedManager;

- (void)resetValues;
- (void)valueUpdated;
- (void)save;

@end
