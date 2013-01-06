// DBFriendInviter.m
// 
// Copyright (c) 2013 Daniel Bader (http://dbader.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "DBFriendInviter.h"


/**
 * A simple value object that stores a reference to an address book contact (an ABRecordID)
 * and the contact's associated importance score.
 */
@interface __DBContactScorePair : NSObject
@property(readonly, nonatomic) ABRecordID contact;
@property(readonly, nonatomic) NSInteger score;
+ (__DBContactScorePair*) pairWithContact:(ABRecordID)aContact score:(NSInteger)aScore;
@end

@implementation __DBContactScorePair

- (instancetype) initWithContact:(ABRecordID)contact score:(NSInteger)score {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _contact = contact;
    _score = score;
    
    return self;
}

+ (instancetype) pairWithContact:(ABRecordID)contact score:(NSInteger)score {
    return [[__DBContactScorePair alloc] initWithContact:contact score:score];
}

// Sort by descending score, i.e. higher scores first.
- (NSComparisonResult) compare:(__DBContactScorePair*)other {
    if (self.score > other.score) {
        return NSOrderedAscending;
    }
    
    if (self.score < other.score) {
        return NSOrderedDescending;
    }
    
    return NSOrderedSame;
}

// Return a human-readable name for the contact.
// This is for debugging purposes only because it instantiates a new ABAddressBookRef
// with every call. To improve performance you should reuse a single ABAddressBookRef.
- (NSString*) contactName {
    CFErrorRef error = nil;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    ABRecordRef record = ABAddressBookGetPersonWithRecordID(addressBook, self.contact);
    
    NSString *compositeName = (__bridge_transfer NSString*) ABRecordCopyCompositeName(record);
    
    if (addressBook) {
        CFRelease(addressBook);
    }
    
    return compositeName;
}

- (NSString*) description {
    return [NSString stringWithFormat:@"%@(%@, recordID=%i, score=%i)",
                NSStringFromClass(self.class),
                self.contactName,
                self.contact,
                self.score];
}
@end

/**
 * A simple value object that stores an adress book contact property (an ABPropertyID)
 * and its associated importance score. We use this to construct a static lookup table
 * for determining the importance score of an address book contact.
 *
 * This is an internal class used by the DBFriendFinder class and should not be
 * exposed externally.
 */
@interface __DBPropertyScorePair : NSObject
@property(readonly, nonatomic) ABPropertyID property;
@property(readonly, nonatomic) NSInteger score;
- (instancetype) initWithProperty:(ABPropertyID)property score:(NSInteger)score;
+ (instancetype) pairWithProperty:(ABPropertyID)property score:(NSInteger)score;
@end

@implementation __DBPropertyScorePair

- (instancetype) initWithProperty:(ABPropertyID)property score:(NSInteger)score {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _property = property;
    _score = score;
    
    return self;
}

+ (instancetype) pairWithProperty:(ABPropertyID)property score:(NSInteger)score {
    return [[__DBPropertyScorePair alloc] initWithProperty:property score:score];
}

@end

/** The score awarded if the contact has an associated image. */
static NSInteger const IMAGE_SCORE = 20;

/** The score penalty for contacts that belong to companies. */
static NSInteger const NON_PERSON_PENALTY = 100;

/**
 * Lookup tables for properties and their score values.
 * Single and multivalue properties are treated differently.
 */
static NSArray *SINGLEVALUE_PROPERTIES = nil;
static NSArray *MULTIVALUE_PROPERTIES = nil;

@implementation DBFriendInviter

/**
 * Initialize the score lookup tables only once. We cannot do this by declaring them
 * as static const because the kAB... constants only become valid at runtime.
 */
+ (void) initialize {
    if (!SINGLEVALUE_PROPERTIES) {
        SINGLEVALUE_PROPERTIES = @[
            // Contacts with nicknames and birthdays are likely to be more important.
            [__DBPropertyScorePair pairWithProperty:kABPersonNicknameProperty           score:10],
            [__DBPropertyScorePair pairWithProperty:kABPersonBirthdayProperty           score: 5],        
            [__DBPropertyScorePair pairWithProperty:kABPersonFirstNameProperty          score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonLastNameProperty           score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonMiddleNameProperty         score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonPrefixProperty             score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonSuffixProperty             score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonFirstNamePhoneticProperty  score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonMiddleNamePhoneticProperty score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonOrganizationProperty       score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonJobTitleProperty           score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonDepartmentProperty         score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonPrefixProperty             score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonNoteProperty               score: 1]
        ];
    }
    
    if (!MULTIVALUE_PROPERTIES) {
        MULTIVALUE_PROPERTIES = @[
            // Related names and associated dates (anniversaries) are likely to indicate
            // close relationships. Also, phone numbers and addresses rank higher than emails
            // and IM profiles.
            [__DBPropertyScorePair pairWithProperty:kABPersonRelatedNamesProperty   score:30],
            [__DBPropertyScorePair pairWithProperty:kABPersonDateProperty           score:30],
            [__DBPropertyScorePair pairWithProperty:kABPersonPhoneProperty          score: 4],
            [__DBPropertyScorePair pairWithProperty:kABPersonAddressProperty        score: 4],
            [__DBPropertyScorePair pairWithProperty:kABPersonEmailProperty          score: 2],
            [__DBPropertyScorePair pairWithProperty:kABPersonURLProperty            score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonSocialProfileProperty  score: 1],
            [__DBPropertyScorePair pairWithProperty:kABPersonInstantMessageProperty score: 1]
        ];
    }
}

+ (NSInteger) importanceScoreForContact:(ABRecordRef)contact {    
    NSInteger score = 0;
    
    // Give a score penalty to contacts that belong to an organization
    // instead of a person.
    CFNumberRef contactKind = ABRecordCopyValue(contact, kABPersonKindProperty);
    if (contactKind && contactKind != kABPersonKindPerson) {
        score -= NON_PERSON_PENALTY;
    }
    if (contactKind) {
        CFRelease(contactKind);
    }

    
    // Give score for all non-nil single-value properties
    // (e.g. first name, last name, ...).
    for (__DBPropertyScorePair *pair in SINGLEVALUE_PROPERTIES) {
        NSString *value = (__bridge_transfer NSString*) ABRecordCopyValue(contact, pair.property);
        if (value) {
            score += pair.score;
        }
    }
    
    // Give score for all non-empty multivalue properties
    // (e.g. phone numbers, email addresses, ...).
    for (__DBPropertyScorePair *pair in MULTIVALUE_PROPERTIES) {
        ABMultiValueRef valueRef = ABRecordCopyValue(contact, pair.property);
        if (valueRef) {
            score += ABMultiValueGetCount(valueRef) * pair.score;
            CFRelease(valueRef);
        }
    }
    
    // Give score if a contact has an associated image.
    if (ABPersonHasImageData(contact)) {
        score += IMAGE_SCORE;
    }
    
    return score;
}

+ (NSArray*) mostImportantContactsWithIgnoredRecordIDs:(NSSet*)ignoredRecordIDs maxResults:(NSUInteger)maxResults {
    CFErrorRef error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    if (!addressBook) {
        return nil;        
    }
    
    // Compute an importance score for all contacts in the address book
    // (except for those blacklisted by the `ignoredRecordIDs` set).
    NSArray *allPeople = (__bridge_transfer NSArray*) ABAddressBookCopyArrayOfAllPeople(addressBook);
    NSMutableArray *mostImportantContacts = [NSMutableArray arrayWithCapacity:[allPeople count]];
    for (NSInteger personIndex = 0; personIndex < allPeople.count; personIndex++) {
        ABRecordRef person = (__bridge ABRecordRef) [allPeople objectAtIndex:personIndex];
        ABRecordID personID = ABRecordGetRecordID(person);
        
        if ([ignoredRecordIDs containsObject:@(personID)]) {
            continue;
        }
        
        NSInteger score = [self importanceScoreForContact:person];
        [mostImportantContacts addObject:[__DBContactScorePair pairWithContact:personID score:score]];
    }
    
    if (addressBook) {
        CFRelease(addressBook);
    }
    
    // Sort by descending score, i.e. higher score comes first.
    [mostImportantContacts sortUsingSelector:@selector(compare:)];
    
    // Convert the results into a list of ABRecordIDs wrapped in NSNumbers.
    // Also limit the number of results to `maxResults`.
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:maxResults];
    NSRange resultsRange = NSMakeRange(0, MIN(maxResults, mostImportantContacts.count));
    for (__DBContactScorePair *pair in [mostImportantContacts subarrayWithRange:resultsRange]) {
        [results addObject:@(pair.contact)];
    }
    
    return results;
}

+ (NSArray*) mostImportantContacts {
    return [self mostImportantContactsWithIgnoredRecordIDs:nil maxResults:10];
}

@end
