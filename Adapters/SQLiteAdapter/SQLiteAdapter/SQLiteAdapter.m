//
//  SQLite.m
//  NoSQL
//
//  Created by Ryan Petrich on 12/03/05git .
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "SQLiteAdapter.h"

NSString * const SQLiteErrorDomain = @"com.heroku.client.sqlite.error";

static NSDate * NSDateFromPostgreSQLTimestamp(NSString *timestamp) {
    static NSDateFormatter *_postgresDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _postgresDateFormatter = [[NSDateFormatter alloc] init];
        [_postgresDateFormatter setDateFormat:@"yyyy'-'MM'-'dd HH':'mm':'ssZZ"];
    });
    
    if ([timestamp rangeOfString:@"."].location != NSNotFound) {
        timestamp = [NSString stringWithFormat:@"%@ +0000", [timestamp substringToIndex:[timestamp rangeOfString:@"."].location]];
    } else {
        timestamp = [NSString stringWithFormat:@"%@ +0000", timestamp];
    }
    
    return [_postgresDateFormatter dateFromString:timestamp];
}

#pragma mark -

@implementation SQLiteAdapter

+ (NSString *)primaryURLScheme {
    return @"sqlite";
}

+ (BOOL)canConnectWithURL:(NSURL *)url {
    return [[url scheme] isEqualToString:@"sqlite"];
}

+ (id <DBConnection>)connectionWithURL:(NSURL *)url 
                                 error:(NSError **)error
{
    return [[SQLiteConnection alloc] initWithURL:url];
}

@end

@interface SQLiteConnection () {
@private
    sqlite3 *_connection;
    __strong NSURL *_url;
}

@end

@implementation SQLiteConnection
@synthesize url = _url;
@dynamic databases;

- (void)dealloc {
    if (_connection) {
        sqlite3_close(_connection);
        _connection = NULL;
    }    
}

- (id)initWithURL:(NSURL *)url {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _url = url;
    
    return self;
}

- (BOOL)open {
	[self close];
    
    int result = sqlite3_open_v2("/Users/ryan/test.db", &_connection, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
	if (result != SQLITE_OK)  {
        NSLog(@"Connection bad: %d", result);
        
		return NO;
    }
	
	return YES;
}

- (BOOL)close {
    if (_connection) {
        sqlite3_close(_connection);
        _connection = NULL;
    }
	return YES;
}

- (BOOL)reset {
    [self close];
    return [self open];
}

- (id <SQLResultSet>)executeSQL:(NSString *)SQL 
                          error:(NSError *__autoreleasing *)error 
{
    sqlite3_stmt *statement = NULL;
    int e = sqlite3_prepare_v2(_connection, [SQL UTF8String], -1, &statement, NULL);
    if (e == SQLITE_OK)
        return [[SQLiteResultSet alloc] initWithStatement:statement];
    if (error)
        *error = [[NSError alloc] initWithDomain:SQLiteErrorDomain code:e userInfo:nil];
    return nil;
}


- (NSArray *)databases {
    return [NSArray arrayWithObject:[[SQLiteDatabase alloc] initWithConnection:self name:[_url lastPathComponent] stringEncoding:NSUTF8StringEncoding]];
}

@end

#pragma mark -

@interface SQLiteDatabase () {
@private
    __strong SQLiteConnection *_connection;
    __strong NSString *_name;
    __strong NSArray *_tables;
    NSStringEncoding _stringEncoding;
}
@end

@implementation SQLiteDatabase
@synthesize connection = _connection;
@synthesize name = _name;
@synthesize stringEncoding = _stringEncoding;
@synthesize tables = _tables;

- (id)initWithConnection:(SQLiteConnection *)connection 
                    name:(NSString *)name
          stringEncoding:(NSStringEncoding)stringEncoding
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _connection = connection;
    _name = name;
    _stringEncoding = stringEncoding;
    
    NSString *SQL = [NSString stringWithFormat:@"SELECT * FROM sqlite_master WHERE type='table' ORDER BY table_name ASC"];
    NSMutableArray *mutableTables = [NSMutableArray array];
    
    [[[_connection executeSQL:SQL error:NULL] tuples] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SQLiteTable *table = [[SQLiteTable alloc] initWithDatabase:self name:[(id <SQLTuple>)obj valueForKey:@"name"] stringEncoding:NSUTF8StringEncoding];
        [mutableTables addObject:table];
    }];
    
    _tables = [NSArray arrayWithArray:mutableTables];

    return self;
}

- (NSString *)description {
    return _name;
}

- (NSArray *)dataSourceGroupNames {
    return [NSArray arrayWithObject:NSLocalizedString(@"Tables", nil)];
}

- (NSArray *)dataSourcesForGroupNamed:(NSString *)groupName {
    if ([groupName isEqualToString:NSLocalizedString(@"Tables", nil)]) {
        return self.tables;
    } else {
        return nil;
    }
}

@end

#pragma mark -

@interface SQLiteTable () {
@private
    __strong NSString *_name;
    NSStringEncoding _stringEncoding;
    __strong id <SQLDatabase> _database;
}
@end

// TODO formalize / add default implementation of data source proxy
@implementation SQLiteTable
@synthesize name = _name;
@synthesize stringEncoding = _stringEncoding;

- (id)initWithDatabase:(id <SQLDatabase>)database
                  name:(NSString *)name
        stringEncoding:(NSStringEncoding)stringEncoding
{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _name = name;
    
    _database = database;
    
    return self;
}

- (NSString *)description {
    return _name;
}

- (NSUInteger)numberOfRecords {
    return [[[[[[_database connection] executeSQL:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", _name] error:nil] recordsAtIndexes:[NSIndexSet indexSetWithIndex:0]] lastObject] valueForKey:@"count"] integerValue]; 
}

#pragma mark - 

- (id <DBResultSet>)resultSetForRecordsAtIndexes:(NSIndexSet *)indexes 
                                           error:(NSError *__autoreleasing *)error
{
    return [[_database connection] executeSQL:[NSString stringWithFormat:@"SELECT * FROM %@ OFFSET %d LIMIT %d ", _name, [indexes firstIndex], [indexes count]] error:nil];
}

#pragma mark -

- (id <DBResultSet>)resultSetForQuery:(NSString *)query 
                                error:(NSError *__autoreleasing *)error 
{
    return [[_database connection] executeSQL:query error:error];
}

#pragma mark -

- (id <DBResultSet>)resultSetForDimension:(NSExpression *)dimension
                                 measures:(NSArray *)measures
                                    error:(NSError **)error
{
    @throw [NSException exceptionWithName:NSObjectNotAvailableException reason:@"Expression-based result sets not implemented!" userInfo:nil];
}

@end

#pragma mark -

@interface SQLiteField () {
@private
    NSUInteger _index;
    __strong NSString *_name;
    DBValueType _type;
    NSUInteger _size;
}
@end

@implementation SQLiteField
@synthesize index = _index;
@synthesize name = _name;
@synthesize type = _type;
@synthesize size = _size;

+ (SQLiteField *)fieldInStatement:(sqlite3_stmt *)statement
                          atIndex:(NSUInteger)fieldIndex 
{
    SQLiteField *field = [[SQLiteField alloc] init];
    field->_index = fieldIndex;
    // Always treat as strings until we can do something more intelligent about this
    field->_type = DBStringValue;
    field->_name = [[NSString alloc] initWithCString:sqlite3_column_name(statement, fieldIndex) encoding:NSUTF8StringEncoding];
    return field;
}

- (id)objectForBytes:(const char *)bytes 
              length:(NSUInteger)length 
            encoding:(NSStringEncoding)encoding 
{
    id value = nil;
    switch (_type) {
        case DBBooleanValue:
            value = [NSNumber numberWithBool:((*(char *)bytes) == 't')];
            break;
        case DBIntegerValue:
            value = [NSNumber numberWithInteger:[[[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] integerValue]];
            break;
        case DBDecimalValue:
            value = [NSNumber numberWithDouble:[[[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] doubleValue]];
            break;
        case DBStringValue:
            value = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
            break;
        case DBDateValue:
            value = NSDateFromPostgreSQLTimestamp([[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding]);
            break;
        default:
            break;
    }
            
    return value;
}

@end

#pragma mark -

@interface SQLiteTuple () {
@private
    NSUInteger _index;
    __strong NSDictionary *_valuesKeyedByFieldName;
}
@end

@implementation SQLiteTuple
@synthesize index = _index;

- (id)initWithValuesKeyedByFieldName:(NSDictionary *)keyedValues {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _valuesKeyedByFieldName = keyedValues;
    
    return self;
}

- (id)valueForKey:(NSString *)key {
    return [_valuesKeyedByFieldName objectForKey:key];
}

@end


#pragma mark -

@interface SQLiteResultSet () {
@private
    sqlite3_stmt *_statement;
    NSUInteger _columnCount;
    NSUInteger _recordCount;
    __strong NSArray *_columns;
    __strong NSDictionary *_columnsKeyedByName;
    __strong NSArray *_tuples;
}

- (id)tupleValueAtIndex:(NSUInteger)tupleIndex 
          forFieldNamed:(NSString *)fieldName;

@end

@implementation SQLiteResultSet
@synthesize fields = _fields;
@synthesize tuples = _tuples;

- (void)dealloc {
    if (_statement) {
        sqlite3_finalize(_statement);
    }    
}

- (id)initWithStatement:(sqlite3_stmt *)statement {
    self = [super init];
    if (!self) {
        sqlite3_finalize(statement);
        return nil;
    }
    
    _statement = statement;
    _columnCount = sqlite3_column_count(statement);
    
    NSMutableArray *mutableFields = [[NSMutableArray alloc] initWithCapacity:_columnCount];
    for (int i = 0; i < _columnCount; i++) {
        SQLiteField *field = [SQLiteField fieldInStatement:statement atIndex:i];
        [mutableFields addObject:field];
    }
    _fields = mutableFields;
    
    NSMutableDictionary *mutableKeyedColumns = [[NSMutableDictionary alloc] initWithCapacity:_columnCount];
    for (SQLiteField *field in _columns) {
        [mutableKeyedColumns setObject:field forKey:field.name];
    }
    _columnsKeyedByName = mutableKeyedColumns;
    
    NSMutableArray *mutableTuples = [[NSMutableArray alloc] init];
    int error = sqlite3_step(statement);
    while (error == SQLITE_ROW) {
        NSMutableDictionary *mutableKeyedTupleValues = [[NSMutableDictionary alloc] initWithCapacity:_columnCount];
        for (int i = 0; i < _columnCount; i++) {
            id value;
            switch (sqlite3_column_type(statement, i)) {
                case SQLITE_INTEGER:
                    value = [[NSNumber alloc] initWithLongLong:sqlite3_column_int64(statement, i)];
                    break;
                case SQLITE_FLOAT:
                    value = [[NSNumber alloc] initWithDouble:sqlite3_column_double(statement, i)];
                    break;
                case SQLITE_TEXT:
                    value = [[NSString alloc] initWithUTF8String:(char *)sqlite3_column_text(statement, i)];
                    break;
                case SQLITE_BLOB: {
                    int length = sqlite3_column_bytes(statement, i);
                    value = [[NSData alloc] initWithBytes:sqlite3_column_blob(statement, i) length:length];
                    break;
                }
                case SQLITE_NULL:
                default:
                    value = [NSNull null];
            }
            SQLiteField *field = [mutableFields objectAtIndex:i];
            [mutableKeyedTupleValues setObject:value forKey:field.name];
        }
        SQLiteTuple *tuple = [[SQLiteTuple alloc] initWithValuesKeyedByFieldName:mutableKeyedTupleValues];
        [mutableTuples addObject:tuple];
        error = sqlite3_step(statement);
    }
    
    _tuples = mutableTuples;
    
    return self;
}

- (NSUInteger)numberOfFields {
    return _columnCount;
}

- (NSUInteger)numberOfRecords {
    return _recordCount;
}

- (NSArray *)recordsAtIndexes:(NSIndexSet *)indexes {
    return [_tuples objectsAtIndexes:indexes];
}

- (NSString *)identifierForTableColumnAtIndex:(NSUInteger)index {
    SQLiteField *field = [_fields objectAtIndex:index];
    return [field name];
}

- (DBValueType)valueTypeForTableColumnAtIndex:(NSUInteger)index {
    SQLiteField *field = [_fields objectAtIndex:index];
    return [field type];
}

- (NSSortDescriptor *)sortDescriptorPrototypeForTableColumnAtIndex:(NSUInteger)index {
    SQLiteField *field = [_fields objectAtIndex:index];
    if ([field type] == DBStringValue) {
        return [NSSortDescriptor sortDescriptorWithKey:[field name] ascending:YES selector:@selector(localizedStandardCompare:)];
    } else {
        return [NSSortDescriptor sortDescriptorWithKey:[field name] ascending:YES];
    }
}

- (id)tupleValueAtIndex:(NSUInteger)tupleIndex 
          forFieldNamed:(NSString *)fieldName
{
    SQLiteTuple *tuple = [_tuples objectAtIndex:tupleIndex];
    return [tuple valueForKey:fieldName];
}

@end