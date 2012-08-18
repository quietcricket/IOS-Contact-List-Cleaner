//
//  CountryCodeDetector.m
//  imhere
//
//  Created by Shang Liang on 2/8/12.
//  Copyright (c) 2012 WE/WEAR/GLASSES. All rights reserved.
//
#import <AddressBook/AddressBook.h>
#import "ContactCleaner.h"

@interface ContactCleaner(){
    // the number of times each country code appeared in the contacts list
    NSMutableDictionary* countryCodeFrequencies;
}

-(void)extractContryCode:(NSString*)joinedNumber into:(NSString**)countryCode andNumber:(NSString**)justPhoneNumber;
-(BOOL) isValidCountryCode:(int) code;

@end



@implementation ContactCleaner

#pragma mark -
#pragma mark Public Methods

/**
 * Read the user's contact list, returns a dicionary of user's and their contact details
    [
        {"Melvyn Lim":[
            {"Number":"12345678", "CountryCode":"65", "Label":"Mobile"},
            {"Number":"87654321", "CountryCode":"65", "Label":"Office"},
        ]},
        {"Daniel Ho":[
            {"Number":"12345678", "CountryCode":"65", "Label":"Mobile"}
        ]}
    ]
 */
-(NSDictionary*)getCleanedContacts{
    NSMutableDictionary* cleanedDic=[NSMutableDictionary dictionary];
    countryCodeFrequencies=[[NSMutableDictionary alloc] init];
    
    ABAddressBookRef addressBook = ABAddressBookCreate( );
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople( addressBook );
    CFIndex nPeople = ABAddressBookGetPersonCount( addressBook );
    
    for ( int i = 0; i < nPeople; i++ )
    {
        ABRecordRef ref = CFArrayGetValueAtIndex( allPeople, i );
        
        /**
         * Get the name of the person
         */
        CFStringRef firstname = ABRecordCopyValue(ref, kABPersonFirstNameProperty);
        CFStringRef middlename=ABRecordCopyValue(ref, kABPersonMiddleNameProperty);
        CFStringRef lastname =  ABRecordCopyValue(ref, kABPersonLastNameProperty);
        NSString* fullname=@"";
        /**
         * The contact list can be quite messy, need to cater for empty records
         */
        if(firstname){
            fullname=[NSString stringWithFormat:@"%@ %@",fullname, firstname];
        }
        
        if(middlename){
            fullname=[NSString stringWithFormat:@"%@ %@",fullname, middlename];
        }
        
        if(lastname){
            fullname=[NSString stringWithFormat:@"%@ %@",fullname, lastname];
        }
        
        
        /**
         * Get the phone numbers
         */
        
        ABMultiValueRef phones =(NSString*)ABRecordCopyValue(ref, kABPersonPhoneProperty);
        NSString* mixedPhoneNumber=@"";
        NSString* label;
        NSMutableArray* numbers=[NSMutableArray array];
        for(CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) {
            label = (NSString*)ABMultiValueCopyLabelAtIndex(phones, i);
            mixedPhoneNumber = (NSString*)ABMultiValueCopyValueAtIndex(phones, i);
            /**
             * Not sure if this is possible, no label.
             */
            if(!label){
                NSLog(@"no lable");
                label=@"Mobile";
            }
            
            /**
             * Cleanup the label and number. Remove unwanted characters
             */
            label=[[label componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsJoinedByString:@""];
            NSMutableCharacterSet* set=[NSCharacterSet symbolCharacterSet];
            [set addCharactersInString:@"_!"];
            //TODO: Find out what will happen if the labels are in non-latin characters
            label=[[label componentsSeparatedByCharactersInSet:set] componentsJoinedByString:@""];

            set=[[NSMutableCharacterSet alloc] init];
            [set addCharactersInString:@"+0123456789"];
            [set invert];
            mixedPhoneNumber=[[mixedPhoneNumber componentsSeparatedByCharactersInSet:set] componentsJoinedByString:@""];
            NSString* countryCode=[[NSString alloc] init];
            NSString* justPhoneNumber=[[NSString alloc] init];
            [self extractContryCode:mixedPhoneNumber into:&countryCode andNumber:&justPhoneNumber];
            NSLog(@"%@, %@, %@",countryCode,justPhoneNumber,label);
            NSDictionary *dic=[NSDictionary dictionaryWithObjectsAndKeys:justPhoneNumber,@"Number",countryCode,@"CountryCode",label,@"Label", nil];
            [numbers addObject:dic];
            if(countryCode.length>0){
                NSNumber* num=[countryCodeFrequencies objectForKey:countryCode];
                num=[NSNumber numberWithInt:[num intValue]+1];
                [countryCodeFrequencies setObject:num forKey:countryCode];
            }            
        }
        
        if([fullname length]>0&&[numbers count]>0){
            [cleanedDic setObject:numbers forKey:fullname];
        }
    }
    return cleanedDic;
}

/**
 * Return the country code appeared most number of times in the contacts
 * It's a guess, I think it should be quite accurate
 */
-(NSString*) guessCountryCode{
    int maxCount=0;
    NSString* maxCountryCode=@"1";
    for (NSString* key in [countryCodeFrequencies allKeys]) {
        if([[countryCodeFrequencies objectForKey:key] intValue]>maxCount){
            maxCountryCode=key;
            maxCount=[[countryCodeFrequencies objectForKey:key] intValue];
        }
    }
    
    return maxCountryCode;
}


#pragma mark -
#pragma mark Private Methods

/**
 * Split the phone number into country code and phone number only
 * Some of the entries may not have the country code. Need to find out the most common country code
 * in the user's contact list and we assume that's the country code.
 * However it's not that safe either. The best is to ask the user to key in the country code himself.
 * Another method is to read from the SIM card setting. But if the person is travelling or using some other 
 * country's SIM card, we are screwed too.
 */
-(void)extractContryCode:(NSString*)joinedNumber into:(NSString**)countryCode andNumber:(NSString**)justPhoneNumber{
    
    /**
     * If the number doesn't start with "+", then no country code is set
     */
    if([joinedNumber characterAtIndex:0]!='+'){
        *justPhoneNumber=joinedNumber;
    }else{
        /**
         * Check if the first digit is the country code, 1,2 or 7
         * If yes, take the first digit and the remaining numbers is the justPhoneNumber
         */
        
        if(joinedNumber.length>1){
            *countryCode=[joinedNumber substringWithRange:NSMakeRange(1, 1)];
            if([self isValidCountryCode:[*countryCode intValue]]){
                *justPhoneNumber=[joinedNumber substringFromIndex:2];
                return;
            }
        }
        /**
         * Check if the two digits is a country code, 
         */
        if(joinedNumber.length>2){
            *countryCode=[joinedNumber substringWithRange:NSMakeRange(1, 2)];
            if([self isValidCountryCode:[*countryCode intValue]]){
                *justPhoneNumber=[joinedNumber substringFromIndex:3];
                return;
            }
        }
        
        /**
         * Check if the three digits is a country code, 
         */
        if(joinedNumber.length>3){
            *countryCode=[joinedNumber substringWithRange:NSMakeRange(1, 3)];
            if([self isValidCountryCode:[*countryCode intValue]]){
                *justPhoneNumber=[joinedNumber substringFromIndex:4];
                return;
            }
        }
        
        /**
         * If all fails, remove the "+" sign and assign the rest as justPhoneNumber
         */
        *countryCode=@"";
        *justPhoneNumber=[joinedNumber substringFromIndex:2];
    }
}

-(BOOL) isValidCountryCode:(int) code{
    
    /**
     * Country code extracted from wikipedia.
     * The country code runs in sequence and there is one very important rule, if 20 is a country code, there will be no
     * country code like 201, 202 etc. 
     * This made it possible to check if the 1st digit is a country code, then if the first 2 digits is a country code and lastly
     * the first 3 digits. No missing digits or extra digits will be extracted as country code in such manner.
     */
    static int countryCodes[]={1,2,7,20,27,30,31,32,33,34,36,39,40,41,43,44,45,46,47,48,49,51,52,53,54,55,56,57,58,60,61,62,63,64,65,66,81,82,84,86,90,91,92,93,94,95,98,212,213,216,218,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,248,249,250,251,252,253,254,255,256,257,258,260,261,262,263,264,265,266,267,268,269,290,291,297,298,299,350,351,352,353,354,355,356,357,358,359,370,371,372,373,374,375,376,377,378,380,381,382,385,386,387,389,405,420,421,423,500,501,502,503,504,505,506,507,508,509,590,591,592,593,595,597,598,599,670,672,673,674,675,676,677,678,679,680,681,682,683,685,686,687,688,689,690,691,692,850,852,853,855,856,870,880,886,960,961,962,963,964,965,966,967,968,970,971,972,973,974,975,976,977,992,993,994,995,996,998};
    /**
     * Total 203 different country codes now. Unlikely there will be any change in the future.
     */
    static int totalCodes=203;
    
    for (int i=0; i<totalCodes; i++) {
        if(countryCodes[i]==code){
            return YES;
        }else if(countryCodes[i]>code){
            return NO;
        }
    }
    return NO;
}

@end
