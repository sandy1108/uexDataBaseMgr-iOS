//
//  EUExDataBaseMgr.m
//  webKitCorePalm
//
//  Created by zywx on 12-4-10.
//  Copyright 2012 3g2win. All rights reserved.
//

#import "EUExDataBaseMgr.h"

#import "Database.h"
#import <AppCanKit/ACEXTScope.h>


        


@interface EUExDataBaseMgr()
@property (nonatomic,strong)NSMutableDictionary<NSString *,Database *> *dbDict;
@property (nonatomic,assign)BOOL shouldRollback;


@end


#define UEX_SUCCESS @0
#define UEX_FAILURE @1

@implementation EUExDataBaseMgr
-(void)dealloc{
    [self clean];
}
-(void)clean{
    for (Database *db in [self.self.dbDict allValues]) {
        [db closeDataBase];
    }
    [self.dbDict removeAllObjects];
	
}


- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{

    self = [super initWithWebViewEngine:engine];
    if (self) {
        _dbDict = [NSMutableDictionary dictionary];
    }
    return self;
}




- (NSNumber *)openDataBase:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId) = inArguments;
    __block NSNumber *cbResult = UEX_FAILURE;
    @onExit{
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbOpenDataBase" arguments:ACArgsPack(@(inOpId.integerValue),@2,cbResult)];
    };
    
    if (!inDBName || inDBName.length == 0) {
        return cbResult;
    }

	Database *db = [self.dbDict objectForKey:inDBName];
	if (db) {
        cbResult = UEX_SUCCESS;
		return @-1;
	}
    
	db = [[Database alloc] init];
	if ([db openDataBase:inDBName]) {
        [self.dbDict setObject:db forKey:inDBName];
        cbResult = UEX_SUCCESS;
	}
    return cbResult;
}






- (void)executeSql:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId,NSString *inSQL,ACJSFunctionRef *cb) = inArguments;


    void (^callback)(NSNumber *result) = ^(NSNumber *result){
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbExecuteSql" arguments:ACArgsPack(@(inOpId.integerValue),@2,result)];
        [cb executeWithArguments:ACArgsPack(result)];
    };
    
    
	Database *db = [self.dbDict objectForKey:inDBName];
	if(!db || !inSQL || inSQL.length == 0){
        callback(UEX_FAILURE);
        return;
	}

    dispatch_async(db.queue, ^{
        if ([db execSQL:[inSQL UTF8String]]) {
            callback(UEX_SUCCESS);
        }else {
            self.shouldRollback = YES;
            callback(UEX_FAILURE);
        }
    });



}
-(void)selectSql:(NSMutableArray *)inArguments{
	ACArgsUnpack(NSString *inDBName,NSNumber *inOpId,NSString *inSQL,ACJSFunctionRef *cb) = inArguments;
    void (^callback)(NSArray *result) = ^(NSArray *result){
        if(result){
            [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbSelectSql" arguments:ACArgsPack(@(inOpId.integerValue),@1,result.ac_JSONFragment)];
        }else{
            [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbSelectSql" arguments:ACArgsPack(@(inOpId.integerValue),@2,UEX_FAILURE)];
        }
        [cb executeWithArguments:ACArgsPack(result)];
    };
    
    
    
	Database *db = [self.dbDict objectForKey:inDBName];
	if(!db || !inSQL || inSQL.length == 0){
        callback(nil);
        return;
	}

    dispatch_async(db.queue, ^{
        callback([db selectSQL:[inSQL UTF8String]]);
    });
}


- (void)transaction:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId,ACJSFunctionRef *inFunc,ACJSFunctionRef *cb) = inArguments;
    void (^callback)(NSNumber *result) = ^(NSNumber *result){
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbTransaction" arguments:ACArgsPack(@(inOpId.integerValue),@2,result)];
        [cb executeWithArguments:ACArgsPack(result)];
    };
    Database *db = [self.dbDict objectForKey:inDBName];
    if (!db || !inFunc) {
        callback(UEX_FAILURE);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block BOOL shouleContinue = YES;
        //保证本次transaction结束前不会开始第二次transaction
        dispatch_semaphore_wait(db.transactionLock, DISPATCH_TIME_FOREVER);

        self.shouldRollback = NO;
        dispatch_async(db.queue, ^{
            if (![db execSQL:"BEGIN TRANSACTION"]) {
                callback(UEX_FAILURE);
                shouleContinue = NO;
                dispatch_semaphore_signal(db.transactionLock);
            };
        });
        dispatch_async(db.queue, ^{
            if (shouleContinue) {
                [inFunc executeWithArguments:nil completionHandler:^(JSValue * _Nullable returnValue) {
                    
                    //此回调执行时,inFunc中的消息可能还在主线程中待转发到插件实例,因此其中的sql操作并未全部加入db.queue中
                    //所以从主线程进入dbqueue,保证inFunc中所有的sql操作均已加入db.queue后,再结束transaction
                    dispatch_async(dispatch_get_main_queue(), ^{
                        dispatch_async(db.queue, ^{
                            if (!shouleContinue) {
                                return;
                            }
                            if (self.shouldRollback) {
                                [db execSQL:"ROLLBACK TRANSACTION"];
                                callback(UEX_FAILURE);
                            }else{
                                if([db execSQL:"COMMIT TRANSACTION"]){
                                    callback(UEX_SUCCESS);
                                }else{
                                    callback(UEX_FAILURE);
                                }
                            }
                            dispatch_semaphore_signal(db.transactionLock);
                        });
                    });
                }];
            }
        });
    });
}


- (NSNumber *)closeDataBase:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId) = inArguments;
    __block NSNumber *cbResult = UEX_FAILURE;
    @onExit{
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbCloseDataBase" arguments:ACArgsPack(@(inOpId.integerValue),@2,cbResult)];
    };
    
	Database *db = [self.dbDict objectForKey:inDBName];
	if(!db){
		return cbResult;
	}
    
	if ([db closeDataBase]) {
		[self.dbDict removeObjectForKey:inDBName];
        cbResult = UEX_SUCCESS;
	}
    return cbResult;
}

@end
