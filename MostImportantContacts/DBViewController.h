//
//  DBViewController.h
//  MostImportantContacts
//
//  Created by Daniel Bader on 06.01.13.
//  Copyright (c) 2013 Daniel Bader. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DBViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@end
