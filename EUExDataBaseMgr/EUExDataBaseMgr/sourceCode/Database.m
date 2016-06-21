//
//  Database.m
//  webKitCorePalm
//
//  Created by AppCan on 12-4-10.
//  Copyright 2012 AppCan. All rights reserved.
//

#import "Database.h"

@implementation Database
-(BOOL)openDataBase:(NSString*)inDBName{
    //获取documents路径

    NSString * documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject ;

	NSString *dbFolderPath = [documentPath stringByAppendingPathComponent:@"database"];
	NSFileManager *fileHandle = [NSFileManager defaultManager];
    BOOL isFolder = NO;
	BOOL isExist = [fileHandle fileExistsAtPath:dbFolderPath isDirectory:&isFolder];
	if (!isExist || !isFolder) {
		[[NSFileManager defaultManager] createDirectoryAtPath:dbFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
	
	NSString *dbPath = [dbFolderPath stringByAppendingPathComponent:inDBName];
	if (sqlite3_open([dbPath UTF8String], &dbHandle) == SQLITE_OK) {
        NSString *label = [@"com.appcan.uexDataBaseMgr.dbQueue." stringByAppendingString:inDBName];
        self.queue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        self.transactionLock = dispatch_semaphore_create(1);
		return YES;
	}else {
		sqlite3_close(dbHandle);
	}
	return NO;
}

- (BOOL)closeDataBase{
	if (sqlite3_close(dbHandle)==SQLITE_OK) {
		return YES;
	}
	return NO;
}

- (BOOL)execSQL:(const char*)inSQL{
    ACLogDebug(@"exec SQL: %s",inSQL);
	char *errMsg = nil;

	int execStatus = sqlite3_exec(dbHandle, inSQL, NULL, NULL, &errMsg);
	if (execStatus == SQLITE_OK) {
		return YES;
	}else{
		ACLogInfo(@"database execSQL ERROR!status = %d,errMsg=%s",execStatus,errMsg);
		sqlite3_free(errMsg);
        return NO;
	}
	
}
- (NSArray *)selectSQL:(const char*)inSQL{
    ACLogDebug(@"select SQL: %s",inSQL);
	const char *errMsg = nil;
	sqlite3_stmt *stmt;
	int stepStatus,i,count,column_type;
	NSObject *columnValue;
    NSString *columnName;
	NSMutableArray *resultRows = [NSMutableArray array];
    BOOL isSuccess = YES;
	if (sqlite3_prepare_v2(dbHandle, inSQL, -1, &stmt, NULL) != SQLITE_OK) {
        isSuccess = NO;
		errMsg = sqlite3_errmsg (dbHandle);
		ACLogInfo(@"selectSQL errMsg=%s",errMsg);

	}
    BOOL keepGoing = isSuccess;
	while (keepGoing) {
		stepStatus = sqlite3_step(stmt);
		switch (stepStatus) {
				case SQLITE_ROW:{
					i = 0;
					NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithCapacity:0];
					count = sqlite3_column_count(stmt);
					while (i<count) {
						column_type = sqlite3_column_type(stmt, i);
						switch (column_type) {
							case SQLITE_INTEGER:
								columnValue = [NSNumber numberWithInt: sqlite3_column_int(stmt, i)];
								columnName = [NSString stringWithFormat:@"%s", sqlite3_column_name(stmt, i)];
								[entry setObject:columnValue forKey:columnName];
								break;
							case SQLITE_TEXT:
								//columnValue = [NSString stringWithFormat:@"%s",sqlite3_column_text(stmt, i)];
								columnValue = [NSString stringWithUTF8String:(char*)sqlite3_column_text(stmt, i)];
								columnName = [NSString stringWithFormat:@"%s",sqlite3_column_name(stmt, i)];
								[entry setObject:columnValue forKey:columnName];
								break;
							case SQLITE_FLOAT:
								columnValue = [NSNumber numberWithDouble:sqlite3_column_double(stmt, i)];
                                //NSLog(@"columnValue=%f",sqlite3_column_double(stmt, i));
								columnName = [NSString stringWithFormat:@"%s",sqlite3_column_name(stmt, i)];
								[entry setObject:columnValue forKey:columnName];
								break;
							case SQLITE_BLOB:
								break;
							case SQLITE_NULL:
								break;
						}
						i++;
					}
					[resultRows addObject:entry];
                    break;
				}
				case SQLITE_DONE:{
					keepGoing = NO;
                    break;
				}
				default:{
					errMsg ="stmt error";
                    ACLogInfo(@"selectSQL errMsg=%s",errMsg);
                    isSuccess = NO;
					keepGoing = NO;
                    break;
				}
		}
	}
	sqlite3_finalize(stmt);
	if (!isSuccess) {
        return nil;
	}
    return resultRows;
}

@end
