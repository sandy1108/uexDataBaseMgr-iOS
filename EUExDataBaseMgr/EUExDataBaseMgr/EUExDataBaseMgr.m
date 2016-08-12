//
//  EUExDataBaseMgr.m
//  webKitCorePalm
//
//  Created by zywx on 12-4-10.
//  Copyright 2012 3g2win. All rights reserved.
//

#import "EUExDataBaseMgr.h"
#import "uexDatabase.h"
#import <AppCanKit/ACEXTScope.h>




#define UEX_RESULT NSNumber *
#define UEX_DATABASE NSDictionary *
//#define UEX_ERROR NSDictionary *

//typedef NS_ENUM(NSInteger,uexDatabaseErrorCode){
//    uexDatabaseErrorNoError = 0,
//    uexDatabaseErrorInvalidParameters = -1,
//    uexDatabaseErrorExecutingSQLError = -2,
//    uexDatabaseErrorTransactionFailure = -3,
//    uexDatabaseErrorTransactionRollback = -4,
//};

static UEX_RESULT kSuccess;
static UEX_RESULT kFailure;
static UEX_RESULT kAlreadyOpened;
static NSDictionary<NSNumber *,NSString *>* kErrorInfoDict;

__attribute__((constructor)) static void initUexConstant(){
    kSuccess = @0;
    kFailure = @1;
    kAlreadyOpened = @-1;
}


static inline UEX_DATABASE uexDBMake(NSString * _Nonnull name,NSNumber * _Nonnull opId){
    return @{
             @"name": name,
             @"id": opId
             };
}

static inline NSString * uexDBGetName(UEX_DATABASE db){
    return db[@"name"];
}

static inline NSNumber *randomOpId(){
    return @(arc4random_uniform(INT_MAX));
}






@interface EUExDataBaseMgr()
@property (nonatomic,strong)NSMutableDictionary<NSString *,uexDatabase *> *dbDict;

@end







@implementation EUExDataBaseMgr




-(void)dealloc{
    [self clean];
}
-(void)clean{
    for (uexDatabase *db in [self.dbDict allValues]) {
        [db close];
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

#pragma mark - 4.0 API

- (UEX_DATABASE)open:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName) = inArguments;

    if (!inDBName || inDBName.length == 0) {
        return nil;
    }
    uexDatabase *db = [self.dbDict objectForKey:inDBName];
    if (db) {
        return uexDBMake(inDBName, randomOpId());
    }
    db = [[uexDatabase alloc]init];
    if (![db open:inDBName]) {
        return nil;
    }
    [self.dbDict setObject:db forKey:inDBName];
    return uexDBMake(inDBName, randomOpId());
}


- (void)sql:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_DATABASE jsDB,NSString *sql,ACJSFunctionRef *cb) = inArguments;
    
    
    
    __block UEX_ERROR err = kUexNoError;
    void (^callback)() = ^(){
        [cb executeWithArguments:ACArgsPack(err)];
    };
    uexDatabase *db = [self.dbDict objectForKey:uexDBGetName(jsDB)];
    if (!db || !sql || sql.length == 0) {
        err = uexErrorMake(1,@"参数错误");
        callback();
        return;
    }
    [db execSQL:sql completion:^(BOOL isSuccess) {
        if (!isSuccess) {
            err = uexErrorMake(2,@"SQL Error");
        }
        callback();
    }];
}


- (void)select:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_DATABASE jsDB,NSString *sql,ACJSFunctionRef *cb) = inArguments;
    
    __block UEX_ERROR err = kUexNoError;
    void (^callback)(NSArray *data) = ^(NSArray *data){
        [cb executeWithArguments:ACArgsPack(err,data)];
    };
    uexDatabase *db = [self.dbDict objectForKey:uexDBGetName(jsDB)];
    if (!db || !sql || sql.length == 0) {
        err = uexErrorMake(1,@"参数错误");
        callback(nil);
        return;
    }
    [db selectSQL:sql completion:^(NSArray<NSDictionary *> *result) {
        if (!result) {
            err = uexErrorMake(2,@"SQL Error");
        }
        callback(result);
    }];
    
}



- (void)transactionEx:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_DATABASE jsDB,NSArray *SQLs,ACJSFunctionRef *cb) = inArguments;
    __block UEX_ERROR err = kUexNoError;
    void (^callback)() = ^(){
        [cb executeWithArguments:ACArgsPack(err)];
    };
    uexDatabase *db = [self.dbDict objectForKey:uexDBGetName(jsDB)];
    
    
    if (!db || !SQLs) {
        err = uexErrorMake(1,@"参数错误");
        callback();
        return;
    }
    [db doTransactionWithSQLs:SQLs completion:^(uexDatabaseTransactionResult result) {
        switch (result) {
            case uexDatabaseTransactionSuccess: {
                break;
            }
            case uexDatabaseTransactionRollback: {
                err = uexErrorMake(2,@"SQL Error,transaction ROLLBACK");
                break;
            }
            case uexDatabaseTransactionError: {
                err = uexErrorMake(3,@"SQL Error,transaction FAILED");
                break;
            }
        }
        callback();
    }];
    
}

- (UEX_BOOL)close:(NSMutableArray *)inArguments{
    ACArgsUnpack(UEX_DATABASE jsDB) = inArguments;
    uexDatabase *db = [self.dbDict objectForKey:uexDBGetName(jsDB)];
    if (!db || ![db close]) {
        return UEX_FALSE;
    }
    [self.dbDict removeObjectForKey:uexDBGetName(jsDB)];
    return UEX_TRUE;
}


#pragma mark - 3.0 API

- (UEX_RESULT)openDataBase:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId) = inArguments;
    __block UEX_RESULT cbResult = kFailure;
    @onExit{
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbOpenDataBase" arguments:ACArgsPack(@(inOpId.integerValue),@2,cbResult)];
    };
    
    if (!inDBName || inDBName.length == 0) {
        return cbResult;
    }
	uexDatabase *db = [self.dbDict objectForKey:inDBName];
	if (db) {
        cbResult = kSuccess;
		return kAlreadyOpened;
	}
    db = [[uexDatabase alloc]init];
	if ([db open:inDBName]) {
        [self.dbDict setObject:db forKey:inDBName];
        cbResult = kSuccess;
	}
    return cbResult;
}






- (void)executeSql:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId,NSString *inSQL,ACJSFunctionRef *cb) = inArguments;
    void (^callback)(UEX_RESULT result) = ^(UEX_RESULT result){
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbExecuteSql" arguments:ACArgsPack(@(inOpId.integerValue),@2,result)];
        [cb executeWithArguments:ACArgsPack(result)];
    };
	uexDatabase *db = [self.dbDict objectForKey:inDBName];
	if(!db || !inSQL || inSQL.length == 0){
        callback(kFailure);
        return;
	}
    [db execSQL:inSQL completion:^(BOOL isSuccess) {
        UEX_RESULT result = isSuccess ? kSuccess : kFailure;
        callback(result);
    }];
}
-(void)selectSql:(NSMutableArray *)inArguments{
	ACArgsUnpack(NSString *inDBName,NSNumber *inOpId,NSString *inSQL,ACJSFunctionRef *cb) = inArguments;
    void (^callback)(NSArray *result) = ^(NSArray *result){
        if(result){
            [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbSelectSql" arguments:ACArgsPack(@(inOpId.integerValue),@1,result.ac_JSONFragment)];
        }else{
            [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbSelectSql" arguments:ACArgsPack(@(inOpId.integerValue),@2,kFailure)];
        }
        [cb executeWithArguments:ACArgsPack(result)];
    };
    
	uexDatabase *db = [self.dbDict objectForKey:inDBName];
	if(!db || !inSQL || inSQL.length == 0){
        callback(nil);
        return;
	}
    [db selectSQL:inSQL completion:^(NSArray<NSDictionary *> *result) {
        callback(result);
    }];
    

}


- (void)transaction:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId,ACJSFunctionRef *inFunc,ACJSFunctionRef *cb) = inArguments;
    void (^callback)(NSNumber *result) = ^(NSNumber *result){
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbTransaction" arguments:ACArgsPack(@(inOpId.integerValue),@2,result)];
        [cb executeWithArguments:ACArgsPack(result)];
    };
    uexDatabase *db = [self.dbDict objectForKey:inDBName];
    if (!db || !inFunc) {
        callback(kFailure);
        return;
    }
    [db doTransaction:inFunc completion:^(uexDatabaseTransactionResult result) {
        switch (result) {
            case uexDatabaseTransactionSuccess: {
                callback(kSuccess);
                break;
            }
            case uexDatabaseTransactionRollback:
            case uexDatabaseTransactionError: {
                callback(kFailure);
                break;
            }
        }
    }];
}

- (UEX_RESULT)closeDataBase:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *inDBName,NSNumber *inOpId) = inArguments;
    __block UEX_RESULT cbResult = kFailure;
    @onExit{
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexDataBaseMgr.cbCloseDataBase" arguments:ACArgsPack(@(inOpId.integerValue),@2,cbResult)];
    };
    
	uexDatabase *db = [self.dbDict objectForKey:inDBName];
	if(db && [db close]){
        [self.dbDict removeObjectForKey:inDBName];
        cbResult = kSuccess;
	}
    return cbResult;
}

@end
