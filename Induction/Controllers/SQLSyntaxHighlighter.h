//
//  SQLSyntaxHighlighter.h
//  Kirin
//
//  Created by Mattt Thompson on 12/02/02.
//  Copyright (c) 2012年 Heroku. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZWRCompatibility.h"

@interface SQLSyntaxHighlighter : NSObject <NSTextViewDelegate, NSTextStorageDelegate> {
@private
    __zwrc_weak NSTextView *_textView;
}

@property (assign, nonatomic) IBOutlet NSTextView *textView;

@end
