//
//  DBDatabaseViewController.h
//  Kirin
//
//  Created by Mattt Thompson on 12/01/26.
//  Copyright (c) 2012年 Heroku. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "DBAdapter.h"
#import "ZWRCompatibility.h"

@class ExploreTableViewController;
@class QueryViewController;
@class VisualizeViewController;
@class SQLResultsTableViewController;

enum _DBDatabaseViewTabs {
    ExploreTab,
    QueryTab,
    VisualizeTab,
} DBDatabaseViewTabs;

@interface DBDatabaseViewController : NSViewController <NSOutlineViewDelegate> {
@private
    __zwrc_weak NSToolbar *_toolbar;
    __zwrc_weak NSOutlineView *_outlineView;
    __zwrc_weak NSTabView *_tabView;
}

@property (strong, nonatomic) id <DBDatabase> database;
@property (strong, nonatomic, readonly) NSArray *sourceListNodes;

@property (unsafe_unretained, nonatomic) IBOutlet NSToolbar *toolbar;
@property (unsafe_unretained, nonatomic) IBOutlet NSOutlineView *outlineView;
@property (unsafe_unretained, nonatomic) IBOutlet NSTabView *tabView;

@property (strong, nonatomic) IBOutlet ExploreTableViewController *exploreViewController;
@property (strong, nonatomic) IBOutlet QueryViewController *queryViewController;
@property (strong, nonatomic) IBOutlet VisualizeViewController *visualizeViewController;

- (IBAction)explore:(id)sender;
- (IBAction)query:(id)sender;
- (IBAction)visualize:(id)sender;

@end
