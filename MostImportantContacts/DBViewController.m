//
//  DBViewController.m
//  MostImportantContacts
//
//  Created by Daniel Bader on 06.01.13.
//  Copyright (c) 2013 Daniel Bader. All rights reserved.
//

#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "DBViewController.h"
#import "DBFriendInviter.h"

@interface DBViewController ()
@property (strong) NSArray *contacts;
@end

@implementation DBViewController {
    ABAddressBookRef _addressBook;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.contacts = nil;
    
    if (!_addressBook) {
        CFErrorRef error = NULL;
        _addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    }
}

- (void) dealloc {
    self.contacts = nil;
    if (_addressBook) {
        CFRelease(_addressBook);
        _addressBook = NULL;
    }
}

- (void) viewDidAppear:(BOOL)animated {
    if (self.contacts.count) {
        return;
    }
    
    CFErrorRef error = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, &error);
    if (!addressBook) {
        NSLog(@"Failed to access the address book: %@", error);
        return;
    }
    
    __block BOOL accessGranted = NO;
    if (ABAddressBookRequestAccessWithCompletion != NULL) {
        // We're on iOS 6.
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            accessGranted = granted;
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } else {
        // We're on iOS 5 or older.
        accessGranted = YES;
    }
        
    CFRelease(addressBook);
    
    if (accessGranted) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            NSLog(@"Determining most important contacts...");
            self.contacts = [DBFriendInviter mostImportantContacts];
            NSLog(@"Done. ABRecordIDs of the most important contacts: %@", _contacts);
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self.tableView reloadData];
            });
        });
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"ContactCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
        
    ABRecordID contact = [[self.contacts objectAtIndex:indexPath.row] intValue];
    ABRecordRef record = ABAddressBookGetPersonWithRecordID(_addressBook, contact);
    NSString *compositeName = (__bridge_transfer NSString*) ABRecordCopyCompositeName(record);
    
    // Compute the score again for debugging purposes. Normally you wouldn't need this.
    NSInteger score = [DBFriendInviter importanceScoreForContact:record];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@", compositeName];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Score: %i", score];
    
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Display the select
    ABRecordID contact = [[self.contacts objectAtIndex:indexPath.row] intValue];
    ABRecordRef person = ABAddressBookGetPersonWithRecordID(_addressBook, contact);
    ABPersonViewController *picker = [[ABPersonViewController alloc] init];
    picker.displayedPerson = person;
    [self.navigationController pushViewController:picker animated:YES];
}

@end
