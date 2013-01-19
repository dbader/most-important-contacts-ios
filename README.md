# [Guessing a user’s favorite contacts on iOS](http://dbader.org/blog/guessing-favorite-contacts-ios)

![Demo application screenshot](https://raw.github.com/dbader/most-important-contacts-ios/master/screenshot.jpg)

This repository contains code for an App Store-legal heuristic that guesses the favorite contacts in a user's address book on iOS. Many iOS apps provide an "invite your friends" feature. From a usability design perspective it is desireable that the app suggests friends that are likely to be invited by the user.

The code is described in closer detail in this [blog post](http://dbader.org/blog/guessing-favorite-contacts-ios).

## Example Usage
The implementation of the heuristic is contained in DBFriendInviter.h and DBFriendInviter.m.

This will give you the 10 most important contacts in the address book:

```objective-c
#import "DBFriendInviter.h"
NSArray *contacts = [DBFriendInviter mostImportantContacts];
```

The returned list consists of an `NSArray` of `ABRecordID`s. Each `ABRecordID` is wrapped in an `NSNumber` instance. The list is sorted by descending importance, i.e. the most important contacts are first.

You can also change the number of returned results or exclude a set of blacklisted contacts using the following function:

```objective-c
NSMutableSet *blacklistedContacts = [NSMutableSet set];
[set addObject:@(recordID_1)];
// ...
[set addObject:@(recordID_N)];

NSArray *contacts = [DBFriendInviter mostImportantContactsWithIgnoredRecordIDs:blacklistedContacts
                                                                    maxResults:20];
```

## Demo application
The repository contains a demo application for iOS 6.

## Contact
[Daniel Bader](http://dbader.org) – Twitter: [@dbader_org](http://twitter.com/dbader_org)

The code made available here is described in closer detail in this [blog post](http://dbader.org/blog/guessing-favorite-contacts-ios).

## License
All code in this repository is available under the MIT license. See the LICENSE file for more info.
