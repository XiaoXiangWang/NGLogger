//
//  NGLogger.h
//  NGate

//  此类是Google GTMLogger 的Copy版本,只是做了少许改变。原文地址：https://github.com/XiaoXiangWang/google-toolbox-for-mac

//  Created by 汪潇翔 on 15/5/25.
//  Copyright (c) 2015年 Google. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef NGLoggerInfo

#define NGLoggerDebug(...) \
    [[NGLogger sharedLogger] logFunctionDebug:__func__ message:__VA_ARGS__,nil]

#define NGLoggerInfo(...) \
    [[NGLogger sharedLogger] logFunctionInfo:__func__ message:__VA_ARGS__,nil]

#define NGLoggerError(...) \
    [[NGLogger sharedLogger] logFunctionError:__func__ message:__VA_ARGS__,nil]

#define NGLoggerAssert(...) \
    [[NGLogger sharedLogger] logFunctionAssert:__func__ message:__VA_ARGS__,nil]

#endif




/*!
 Log级别
 */
typedef NS_ENUM(NSUInteger, NGLoggerLevel){
    /*!
     未知
     */
    NGLoggerLevelUnknown,
    /*!
     调试
     */
    NGLoggerLevelDebug,
    /*!
     信息
     */
    NGLoggerLevelInfo,
    /*!
     错误
     */
    NGLoggerLevelError,
    /*!
     断言
     */
    NGLoggerLevelAssert,
};

@protocol NGLogWriter,NGLogFormatter,NGLogFilter;

/*!
 @abstract 日志类
 */
@interface NGLogger : NSObject

/*!
 写log操作对象
 */
@property(atomic,readonly) id<NGLogWriter> writer;

/*!
 格式化对象
 */
@property(atomic,readonly) id<NGLogFormatter> formatter;

/*!
 过滤
 */
@property(atomic,readonly) id<NGLogFilter> filter;


/*!
 放回一个单例对象
 
 @return 单例对象
 */
+ (instancetype)sharedLogger;

/*!
 设置日志类
 
 @param logger 日志类
 */
+ (void)setSharedLogger:(NGLogger *)logger;

/*!
 返回一个标准日志类
 
 @return 日志类
 */
+ (instancetype)standardLogger;

+ (instancetype)standardLoggerWithStderr;

+ (instancetype)standardLoggerWithPath:(NSString *)path;

+ (id)loggerWithWriter:(id<NGLogWriter>)writer
             formatter:(id<NGLogFormatter>)formatter
                filter:(id<NGLogFilter>)filter;

+ (instancetype)logger;

- (instancetype)initWithWriter:(id<NGLogWriter>)writer
                     formatter:(id<NGLogFormatter>)formatter
                        filter:(id<NGLogFilter>)filter;

// Logs a message at the debug level (kGTMLoggerLevelDebug).
- (void)logDebug:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1, 2);
// Logs a message at the info level (kGTMLoggerLevelInfo).
- (void)logInfo:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1, 2);
// Logs a message at the error level (kGTMLoggerLevelError).
- (void)logError:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1, 2);
// Logs a message at the assert level (kGTMLoggerLevelAssert).
- (void)logAssert:(NSString *)fmt, ... NS_FORMAT_FUNCTION(1, 2);
@end

@interface NGLogger (NGLoggerMacroHelpers)
- (void)logFunctionDebug:(const char *)func message:(NSString *)fmt, ...
NS_FORMAT_FUNCTION(2, 3);
- (void)logFunctionInfo:(const char *)func message:(NSString *)fmt, ...
NS_FORMAT_FUNCTION(2, 3);
- (void)logFunctionError:(const char *)func message:(NSString *)fmt, ...
NS_FORMAT_FUNCTION(2, 3);
- (void)logFunctionAssert:(const char *)func message:(NSString *)fmt, ...
NS_FORMAT_FUNCTION(2, 3);
@end  // NGLoggerMacroHelpers

// For subclasses only
@interface NGLogger (PrivateMethods)

- (void)logInternalFunc:(const char *)func
                 format:(NSString *)fmt
                 valist:(va_list)args
                  level:(NGLoggerLevel)level NS_FORMAT_FUNCTION(2, 0);

@end


#pragma mark - NGLogWriter
@protocol NGLogWriter <NSObject>

-(void)logMessage:(NSString*)message level:(NGLoggerLevel)level;

@end

@interface NSArray (NGArrayCompositeLogWriter) <NGLogWriter>
@end  // NGArrayCompositeLogWriter

@interface NGLogger (NGLoggerLogWriter) <NGLogWriter>
@end

#pragma mark NSFileHandle+NGFileHandleLogWriter

@interface NSFileHandle (NGFileHandleLogWriter)<NGLogWriter>

+(instancetype)fileHandleForLoggingAtPath:(NSString *)path mode:(mode_t)mode;

@end

#pragma mark - Log formatter

@protocol NGLogFormatter <NSObject>

- (NSString *)stringForFunc:(NSString *)func
                 withFormat:(NSString *)fmt
                     valist:(va_list)args
                      level:(NGLoggerLevel)level NS_FORMAT_FUNCTION(2, 0);
@end
@interface NGLogBasicFormatter : NSObject<NGLogFormatter>

- (NSString *)prettyNameForFunc:(NSString *)func;

@end

@interface NGLogStandardFormatter : NGLogBasicFormatter

@property(nonatomic,strong,readonly) NSDateFormatter* dateFormatter;

@property(nonatomic,strong,readonly) NSString* pname;

@property(nonatomic,assign,readonly) pid_t pid;
@end




#pragma mark - Log Filters

@protocol NGLogFilter <NSObject>
// Returns YES if |msg| at |level| should be logged; NO otherwise.
- (BOOL)filterAllowsMessage:(NSString *)msg level:(NGLoggerLevel)level;
@end  // GTMLogFilter


@interface NGLogLevelFilter : NSObject <NGLogFilter> {
@private
    BOOL verboseLoggingEnabled_;
}
@end  // NGLogLevelFilter

@interface NGLogNoFilter : NSObject <NGLogFilter>
@end  // GTMLogNoFilter

@interface NGLogAllowedLevelFilter : NSObject <NGLogFilter> {
@private
    NSIndexSet *allowedLevels_;
}
@end

@interface NGLogMininumLevelFilter : NGLogAllowedLevelFilter

- (id)initWithMinimumLevel:(NGLoggerLevel)level;

@end

@interface NGLogMaximumLevelFilter : NGLogAllowedLevelFilter

- (id)initWithMaximumLevel:(NGLoggerLevel)level;

@end