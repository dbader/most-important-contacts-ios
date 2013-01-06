// DBFriendInviter.h
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

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@interface DBFriendInviter : NSObject

/** 
 * Return the 10 most-important contacts from the user's address book. 
 * The returned list consists of an NSArray of ABRecordIDs. Each ABRecordID is wrapped
 * in an NSNumber instance. The list is sorted by descending importance, i.e. the most
 * important contacts are first.
 */
+ (NSArray*) mostImportantContacts;

/** 
 * Like [DBFriendInviter mostImportantContacts].
 *
 * Additionally, a set of ignored ABRecordIDs (wrapped in NSNumbers)
 * can be specified. All ABRecordIDs within this set are not included in the returned list of
 * the user's most-important contacts. This is useful to blacklist contacts that were already invited
 * or that belong to the user.
 *
 * Up to `maxResults` results will be returned by the method.
 */
+ (NSArray*) mostImportantContactsWithIgnoredRecordIDs:(NSSet*)ignoredRecordIDs maxResults:(NSUInteger)maxResults;

/**
 * Returns the importance score for the given contact. Useful for debugging purposes
 * or to perform additional filtering.
 */
+ (NSInteger) importanceScoreForContact:(ABRecordRef)contact;

@end
