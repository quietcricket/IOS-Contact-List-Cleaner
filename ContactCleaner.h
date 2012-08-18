//
//  CountryCodeDetector.h
//  imhere
//
//  Created by Shang Liang on 2/8/12.
//  Copyright (c) 2012 WE/WEAR/GLASSES. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ContactCleaner:NSObject

-(NSString*) guessCountryCode;
-(NSDictionary*) getCleanedContacts;

@end
