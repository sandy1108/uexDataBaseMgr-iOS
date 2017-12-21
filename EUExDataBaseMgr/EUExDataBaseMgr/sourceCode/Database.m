//
//  Database.m
//  webKitCorePalm
//
//  Created by AppCan on 12-4-10.
//  Copyright 2012 AppCan. All rights reserved.
//

#import "Database.h"
#import "EUtility.h"
#import "JSON.h"
@implementation Database
-(BOOL)openDataBase:(NSString*)inDBName withEncryptKey:(NSString *)encryptkey{
    //获取documents路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * appCanDocumentPath =[[NSString alloc] initWithString:[paths objectAtIndex:0]] ;
    NSString *docPath = [appCanDocumentPath stringByAppendingPathComponent:inDBName];
	NSString *dbFolderPath = [EUtility documentPath:@"database"];
	NSFileManager *fileHandle = [NSFileManager defaultManager];
	BOOL isExist = [fileHandle fileExistsAtPath:docPath];
	if (isExist) {
		NSDictionary *dict = [fileHandle attributesOfItemAtPath:dbFolderPath error:nil];
		NSString *fileType = [dict objectForKey:NSFileType];
		if (![fileType isEqual:NSFileTypeDirectory]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:dbFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
		}
	}else {
		[[NSFileManager defaultManager] createDirectoryAtPath:dbFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
	}
	NSString *dbPath = [NSString stringWithFormat:@"%@/%@",dbFolderPath,inDBName];
	NSLog(@"openDataBase dbPath=%@",dbPath);
	int openDataStatus = sqlite3_open([dbPath UTF8String], &dbHandle);
	//NSLog(@"openDataBase openDataStatus =%d",openDataStatus);
	if (openDataStatus==SQLITE_OK) {
        BOOL ret = YES;
#ifdef USE_SQLCipher
        if ([encryptkey isKindOfClass:[NSString class]] && encryptkey.length > 0) {
            ret = [self setKey:encryptkey];
            NSLog(@"openDataBase openDataStatus==SQLITE_OK, encrypt: %d", ret);
        }
#endif
		return ret;
	}else {
		sqlite3_close(dbHandle);
	}
	return NO;
}

-(BOOL)closeDataBase{
	if (sqlite3_close(dbHandle)==SQLITE_OK) {
		return YES;
	}
	return NO;
}

- (BOOL)setKey:(NSString*)key {
    NSData *keyData = [NSData dataWithBytes:[key UTF8String] length:(NSUInteger)strlen([key UTF8String])];
    
    return [self setKeyWithData:keyData];
}

- (BOOL)setKeyWithData:(NSData *)keyData {
#ifdef SQLITE_HAS_CODEC
    if (!keyData) {
        return NO;
    }
    
    int rc = sqlite3_key(dbHandle, [keyData bytes], (int)[keyData length]);
    BOOL ret = (rc == SQLITE_OK);
    if (!ret) {
        NSLog(@"setKeyWithData--->status: %d", rc);
    }
    return ret;
#else
    return NO;
#endif
}

-(BOOL)execSQL:(const char*)inSQL{
	char *errMsg = NULL;
	int execStatus = sqlite3_exec(dbHandle, inSQL, NULL, NULL, &errMsg);
	if (execStatus == SQLITE_OK) {
		return YES;
	}else{
		PluginLog(@"database execSQL execStatus = %d,errMsg=%s",execStatus,errMsg);
		sqlite3_free(errMsg);
	}
	return NO;
}
-(NSString*)selectSQL:(const char*)inSQL{
	char *errMsg = NULL;
	sqlite3_stmt *stmt;
	NSMutableDictionary *entry;
	int stepStatus,i,count,column_type;
	NSObject *columnValue;
    NSString *columnName;
	NSString *resultSet;
	NSMutableArray *resultRows = [NSMutableArray arrayWithCapacity:0];
	BOOL keepGoing = NO;
	int preStatus = sqlite3_prepare_v2(dbHandle, inSQL, -1, &stmt, NULL);
	if (preStatus != SQLITE_OK) {
		errMsg = (char *) sqlite3_errmsg (dbHandle);
		PluginLog(@" selectSQL errMsg=%s",errMsg);
		keepGoing = NO;
	}
	keepGoing = YES;
	while (keepGoing) {
		stepStatus = sqlite3_step(stmt);
		switch (stepStatus) {
				case SQLITE_ROW:{
					i = 0;
					entry = [NSMutableDictionary dictionaryWithCapacity:0];
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
					keepGoing = NO;
				break;
				}
		}
	}
	sqlite3_finalize(stmt);
	if (errMsg!=NULL) {
		PluginLog(@"selectSQL errMsg=%s",errMsg);
	}else {
		resultSet = [resultRows JSONFragment];
		return resultSet;
	}
	return NULL;	
}
-(void)dealloc{
	[super dealloc];
}
@end
