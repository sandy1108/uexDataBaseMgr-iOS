//
//  Database.h
//  webKitCorePalm
//
//  Created by AppCan on 12-4-10.
//  Copyright 2012 AppCan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
@interface Database : NSObject {
	sqlite3 *dbHandle;
}
@property (nonatomic,assign)dispatch_queue_t queue;
@property (nonatomic,assign)dispatch_semaphore_t transactionLock;



-(BOOL)openDataBase:(NSString*)inDBName;
-(BOOL)closeDataBase;
-(BOOL)execSQL:(const char*)inSQL;
-(NSArray *)selectSQL:(const char*)inSQL;
@end
