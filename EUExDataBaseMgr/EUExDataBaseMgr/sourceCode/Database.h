//
//  Database.h
//  webKitCorePalm
//
//  Created by AppCan on 12-4-10.
//  Copyright 2012 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sqlite3.h"

#define USE_SQLCipher //是否使用SQLCipher宏开关

@interface Database : NSObject {
	sqlite3 *dbHandle;
}
-(BOOL)openDataBase:(NSString*)inDBName withEncryptKey:(NSString *)encryptkey;
-(BOOL)closeDataBase;
-(BOOL)execSQL:(const char*)inSQL;
-(NSString*)selectSQL:(const char*)inSQL;
@end
