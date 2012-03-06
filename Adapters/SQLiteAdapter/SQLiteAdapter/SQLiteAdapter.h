//
//  SQLite.h
//  NoSQL
//
//  Created by Ryan Petrich on 12/03/05.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLAdapter.h"

#import <sqlite3.h>

extern NSString * const SQLiteErrorDomain;

#pragma mark -

@interface SQLiteAdapter : NSObject <DBAdapter>

@end

@interface SQLiteConnection : NSObject <SQLConnection>

@end

#pragma mark -

@interface SQLiteDatabase : NSObject <SQLDatabase>

- (id)initWithConnection:(SQLiteConnection *)connection 
                    name:(NSString *)name
          stringEncoding:(NSStringEncoding)stringEncoding;

@end

#pragma mark -

// TODO Make NSProxy to sql result set
@interface SQLiteTable : NSObject <SQLTable>

- (id)initWithDatabase:(id <SQLDatabase>)database
                  name:(NSString *)name
        stringEncoding:(NSStringEncoding)stringEncoding;

@end

#pragma mark -

@interface SQLiteResultSet : NSObject <SQLResultSet>

- (id)initWithStatement:(sqlite3_stmt *)statement;

@end

#pragma mark -

@interface SQLiteField : NSObject <SQLField>

+ (SQLiteField *)fieldInStatement:(sqlite3_stmt *)statement atIndex:(NSUInteger)fieldIndex;

@end

#pragma mark -

@interface SQLiteTuple : NSObject <SQLTuple>

- (id)initWithValuesKeyedByFieldName:(NSDictionary *)keyedValues;

@end
