//
//  EUExDataBaseMgr.m
//  webKitCorePalm
//
//  Created by zywx on 12-4-10.
//  Copyright 2012 3g2win. All rights reserved.
//

#import "EUExDataBaseMgr.h"
#import "EUtility.h"
#import "Database.h"
#import "EUExBaseDefine.h"
#import "BUtility.h"
#import "JSON.h"

@interface DataBaseSingleton : NSObject
+(instancetype) shareInstance ;
@property (nonatomic,retain) NSMutableDictionary *queueDic;
@end


@implementation DataBaseSingleton

static DataBaseSingleton* _instance = nil;

+(instancetype) shareInstance
{
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init] ;
        _instance.queueDic = [[NSMutableDictionary alloc] init];
        
    }) ;
    
    return _instance ;
}

+(id) allocWithZone:(struct _NSZone *)zone
{
    return [DataBaseSingleton shareInstance] ;
}

-(id) copyWithZone:(struct _NSZone *)zone
{
    return [DataBaseSingleton shareInstance] ;
}

- (dispatch_queue_t)getQueue:(NSString *)name
{
    dispatch_queue_t q;
    
    if ((q = [_queueDic objectForKey:name])) {
        return q;
    }
    else
    {
        q = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_SERIAL);
        [_queueDic setObject:q forKey:name];
    }
    
    return q;
}

@end

@interface EUExDataBaseMgr()
@property (nonatomic, strong) dispatch_queue_t queue;
@end


@implementation EUExDataBaseMgr
#define UEX_DO_IN_SERIAL_QUEUE_BEGIN    dispatch_async(_queue, ^{

#define UEX_DO_IN_SERIAL_QUEUE_END      });

-(void)dealloc{
	if (DBDict) {
		for (Database *db in [DBDict allValues]) {
			[db closeDataBase];
			[db release];
			db = nil;
		}
		[DBDict removeAllObjects];
	}
	[super dealloc];
}
-(void)clean{
	if (DBDict) {
		for (Database *db in [DBDict allValues]) {
			[db closeDataBase];
			[db release];
			db = nil;
		}
		[DBDict removeAllObjects];
	}
}

-(id)initWithBrwView:(EBrowserView *)eInBrwView{
	if (self==[super initWithBrwView:eInBrwView]) {
		DBDict = [[NSMutableDictionary alloc] initWithCapacity:0];
	}
	return self;
}
-(void)openDataBase:(NSMutableArray*)arguments{
    [BUtility setAppCanDocument];
	NSString *inDBName = [arguments objectAtIndex:0];
	NSString *inOpId = 0;
	if([arguments count]==2){
		inOpId = [arguments objectAtIndex:1];
	}
    NSString *label = [@"uexDataBaseMgr.cbOpenDataBase." stringByAppendingString:inDBName];
    _queue = [[DataBaseSingleton shareInstance] getQueue:label];

	Database *db = [DBDict objectForKey:inDBName];
	if (db) {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbOpenDataBase" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
		return;
		//db = [[Database alloc] init];
		//[DBDict setObject:db forKey:inOpId];
	}
	db = [[Database alloc] init];
	BOOL openStatus = NO;
    openStatus = [db openDataBase:inDBName];
	if (openStatus) {
        [DBDict setObject:db forKey:inDBName];
		[self jsSuccessWithName:@"uexDataBaseMgr.cbOpenDataBase" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	}else {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbOpenDataBase" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
	}
}
-(void)executeSql:(NSMutableArray *)arguments{
    
	NSString *inDBName = [arguments objectAtIndex:0];
	NSString *inOpId = [arguments objectAtIndex:1];
	NSString *inSQL = [arguments objectAtIndex:2];
    
    NSString *label = [@"uexDataBaseMgr.cbOpenDataBase." stringByAppendingString:inDBName];
    _queue = [[DataBaseSingleton shareInstance] getQueue:label];
    UEX_DO_IN_SERIAL_QUEUE_BEGIN;
    
	Database *db = [DBDict objectForKey:inDBName];
	if(!db){
		[self jsSuccessWithName:@"uexDataBaseMgr.cbExecuteSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		return;
	}
	BOOL execStatus = NO;
	const char *execSql;
	if (inSQL==NULL||[inSQL length]==0) {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbExecuteSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		return;
	}
	execSql = [inSQL UTF8String];
	execStatus = [db execSQL:execSql];
	if (execStatus) {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbExecuteSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	}else {
		rollTarget = YES;
		[self jsSuccessWithName:@"uexDataBaseMgr.cbExecuteSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
	}
    UEX_DO_IN_SERIAL_QUEUE_END;
}
-(void)selectSql:(NSMutableArray *)arguments{
	NSString *inDBName = [arguments objectAtIndex:0];
	NSString *inOpId = [arguments objectAtIndex:1];
	NSString *inSQL = [arguments objectAtIndex:2];
    
    NSString *label = [@"uexDataBaseMgr.cbOpenDataBase." stringByAppendingString:inDBName];
    _queue = [[DataBaseSingleton shareInstance] getQueue:label];
    UEX_DO_IN_SERIAL_QUEUE_BEGIN;
    
	Database *db = [DBDict objectForKey:inDBName];
	if(!db){
		[self jsSuccessWithName:@"uexDataBaseMgr.cbSelectSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		return;
	}
	const char *selectSql;
	if (inSQL==NULL||[inSQL length]==0) {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbSelectSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		return;
	}
	selectSql = [inSQL UTF8String];
	NSString *cbResult = [db selectSQL:selectSql];
	if (cbResult) {
        NSString *jsStr = [NSString stringWithFormat:@"if(uexDataBaseMgr.cbSelectSql){uexDataBaseMgr.cbSelectSql(%@,%@,%@)}",inOpId,@(UEX_CALLBACK_DATATYPE_JSON),[cbResult JSONFragment]];
        
        [EUtility brwView:self.meBrwView evaluateScript:jsStr];
		//[self jsSuccessWithName:@"uexDataBaseMgr.cbSelectSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_JSON strData:cbResult];
	}else {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbSelectSql" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
	}
    UEX_DO_IN_SERIAL_QUEUE_END;
}
-(void)beginTransaction:(NSMutableArray*)inArguments{
	NSString *inDBName = [inArguments objectAtIndex:0];
	NSString *inOpId = [inArguments objectAtIndex:1];
    
    NSString *label = [@"uexDataBaseMgr.cbOpenDataBase." stringByAppendingString:inDBName];
    _queue = [[DataBaseSingleton shareInstance] getQueue:label];
    UEX_DO_IN_SERIAL_QUEUE_BEGIN;
    
	Database *db = [DBDict objectForKey:inDBName];
	if(!db){
		[self jsSuccessWithName:@"uexDataBaseMgr.cbTransaction" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		return;
	}
	rollTarget = NO;
	BOOL tranStatus = NO;
	const char *tranSql = "BEGIN TRANSACTION";
	tranStatus = [db execSQL:tranSql];
	//if (tranStatus) {
	//	[self jsSuccessWithName:@"uexDataBaseMgr.cbTransaction" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	//}else {
	//	[self jsSuccessWithName:@"uexDataBaseMgr.cbTransaction" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
	//}
    UEX_DO_IN_SERIAL_QUEUE_END;
}
-(void)endTransaction:(NSMutableArray *)arguments{
    
	NSString *inDBName = [arguments objectAtIndex:0];
	NSString *inOpId = [arguments objectAtIndex:1];
    
    NSString *label = [@"uexDataBaseMgr.cbOpenDataBase." stringByAppendingString:inDBName];
    _queue = [[DataBaseSingleton shareInstance] getQueue:label];
    UEX_DO_IN_SERIAL_QUEUE_BEGIN;
    
	Database *db = [DBDict objectForKey:inDBName];
	if(!db){
		[self jsSuccessWithName:@"uexDataBaseMgr.cbTransaction" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		return;
	}
	BOOL tranStatus = NO;
	const char * tranSql = "";
	if (rollTarget) {
		tranSql = "ROLLBACK TRANSACTION";
	}else {
		tranSql = "COMMIT TRANSACTION";
	}
	tranStatus = [db execSQL:tranSql];
	if (rollTarget) {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbTransaction" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
	}else {
		if (tranStatus) {
			[self jsSuccessWithName:@"uexDataBaseMgr.cbTransaction" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
		}else {
			[self jsSuccessWithName:@"uexDataBaseMgr.cbTransaction" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		}
	}
    UEX_DO_IN_SERIAL_QUEUE_END;
}
-(void)closeDataBase:(NSMutableArray*)arguments{
	NSString *inDBName = [arguments objectAtIndex:0];
	NSString *inOpId = 0;
	if ([arguments count]==2) {
		inOpId = [arguments objectAtIndex:1];
	}
	Database *db = [DBDict objectForKey:inDBName];
	if(!db){
		[self jsSuccessWithName:@"uexDataBaseMgr.cbCloseDataBase" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
		return;
	}
	BOOL closeStatus = NO;
	closeStatus = [db closeDataBase];
	if (closeStatus) {
		[DBDict removeObjectForKey:inDBName];
		[self jsSuccessWithName:@"uexDataBaseMgr.cbCloseDataBase" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CSUCCESS];
	}else {
		[self jsSuccessWithName:@"uexDataBaseMgr.cbCloseDataBase" opId:[inOpId intValue] dataType:UEX_CALLBACK_DATATYPE_INT intData:UEX_CFAILED];
	}
}

@end
