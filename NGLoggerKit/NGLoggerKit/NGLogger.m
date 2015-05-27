//
//  NGLogger.m
//  NGate
//
//  Created by 汪潇翔 on 15/5/25.
//  Copyright (c) 2015年 Google. All rights reserved.
//

#import "NGLogger.h"
#import <pthread.h>

#if !__has_feature(objc_arc)
#error NGLogger must be built with ARC.
// You can turn on ARC for files by adding -fobjc-arc to the build phase for each of its files.
#endif
static NGLogger* gSharedLogger = nil;

#pragma mark - NGLogger_Internal
@interface NGLogger ()
/*!
 写log操作对象
 */
@property(atomic,strong,readwrite) id<NGLogWriter> writer;

/*!
 格式化对象
 */
@property(atomic,strong,readwrite) id<NGLogFormatter> formatter;

/*!
 过滤
 */
@property(atomic,strong,readwrite) id<NGLogFilter> filter;
@end

@implementation NGLogger

+(instancetype)sharedLogger
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSharedLogger = [NGLogger standardLogger];
    });
    return gSharedLogger;
}

+(void)setSharedLogger:(NGLogger *)logger
{
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        gSharedLogger = logger;
    });
}

+(instancetype)standardLogger
{
    @try {
        id<NGLogWriter> writer = [NSFileHandle fileHandleWithStandardOutput];
        id<NGLogFormatter> formatter = [NGLogStandardFormatter new];
        id<NGLogFilter> filter = [NGLogLevelFilter new];
        return [[self alloc] initWithWriter:writer
                                  formatter:formatter
                                     filter:filter];
    }
    @catch (NSException *exception)
    {
        // Ignored
    }
    return nil;
}
+(instancetype)standardLoggerWithStderr
{
    @try {
        NGLogBasicFormatter *formatter = [[NGLogBasicFormatter alloc] init];
        NGLogger *stdoutLogger =
        [self loggerWithWriter:[NSFileHandle fileHandleWithStandardOutput]
                     formatter:formatter
                        filter:[[NGLogMaximumLevelFilter alloc]
                                 initWithMaximumLevel:NGLoggerLevelInfo]];
        NGLogger *stderrLogger =
        [self loggerWithWriter:[NSFileHandle fileHandleWithStandardError]
                     formatter:formatter
                        filter:[[NGLogMininumLevelFilter alloc]
                                 initWithMinimumLevel:NGLoggerLevelError]];
        NGLogger *compositeWriter =
        [self loggerWithWriter:@[stdoutLogger, stderrLogger]
                     formatter:formatter
                        filter:[[NGLogNoFilter alloc] init]];
        NGLogger *outerLogger = [self standardLogger];
        [outerLogger setWriter:compositeWriter];
        return outerLogger;
    }
    @catch (id e) {
        // Ignored
    }
    return nil;
}

+(instancetype)standardLoggerWithPath:(NSString *)path
{
    @try {
        NSFileHandle* fileHandle = [NSFileHandle fileHandleForLoggingAtPath:path mode:0644];
        if (fileHandle == nil) return nil;
        id standardLogger = [self standardLogger];
        [standardLogger setWriter:fileHandle];
        return standardLogger;
    }
    @catch (NSException *exception) {
        //Ignored
    }
    return nil;
}

+(instancetype)loggerWithWriter:(id<NGLogWriter>)writer
                      formatter:(id<NGLogFormatter>)formatter
                         filter:(id<NGLogFilter>)filter
{
    return [[self alloc] initWithWriter:writer
                              formatter:formatter
                                 filter:filter];
}

+(instancetype)logger
{
    return [[self alloc] init];
}

-(instancetype)init
{
    return [self initWithWriter:nil
                      formatter:nil
                         filter:nil];
}

-(instancetype)initWithWriter:(id<NGLogWriter>)writer
                    formatter:(id<NGLogFormatter>)formatter
                       filter:(id<NGLogFilter>)filter
{
    if (self = [super init]) {
        self.writer = writer;
        self.formatter = formatter;
        self.filter = filter;
    }
    return self;
}

-(void)logDebug:(NSString *)fmt, ...
{
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:NULL format:fmt valist:args level:NGLoggerLevelDebug];
    va_end(args);
}

- (void)logInfo:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:NULL format:fmt valist:args level:NGLoggerLevelInfo];
    va_end(args);
}

- (void)logError:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:NULL format:fmt valist:args level:NGLoggerLevelError];
    va_end(args);
}
- (void)logAssert:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:NULL format:fmt valist:args level:NGLoggerLevelAssert];
    va_end(args);
}

- (void)logFunctionDebug:(const char *)func message:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:func format:fmt valist:args level:NGLoggerLevelDebug];
    va_end(args);
}

- (void)logFunctionInfo:(const char *)func message:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:func format:fmt valist:args level:NGLoggerLevelInfo];
    va_end(args);
}

- (void)logFunctionError:(const char *)func message:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:func format:fmt valist:args level:NGLoggerLevelError];
    va_end(args);
}

- (void)logFunctionAssert:(const char *)func message:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    [self logInternalFunc:func format:fmt valist:args level:NGLoggerLevelAssert];
    va_end(args);
}

-(void)logMessage:(NSString *)message level:(NGLoggerLevel)level
{
    
    switch (level) {
        case NGLoggerLevelDebug:
            [self logDebug:message,nil];
            break;
        case NGLoggerLevelAssert:
            [self logAssert:message,nil];
            break;
        case NGLoggerLevelError:
            [self logError:message,nil];
            break;
        case NGLoggerLevelInfo:
            [self logInfo:message,nil];
            break;
        default:
            // Ignore the message.
            break;
    }

}


- (void)logInternalFunc:(const char *)func
                 format:(NSString *)fmt
                 valist:(va_list)args
                  level:(NGLoggerLevel)level {
    // Primary point where logging happens, logging should never throw, catch
    // everything.
    @try {
        NSString *fname = func ? [NSString stringWithUTF8String:func] : nil;
        NSString *msg = [self.formatter stringForFunc:fname
                                           withFormat:fmt
                                               valist:args
                                                level:level];
        if (msg && [self.filter filterAllowsMessage:msg level:level])
            [self.writer logMessage:msg level:level];
    }
    @catch (id e) {
        // Ignored
    }
}

@end

@implementation NSArray (NGArrayCompositeLogWriter)

- (void)logMessage:(NSString *)msg level:(NGLoggerLevel)level {
    @synchronized(self) {
        id<NGLogWriter> child = nil;
        for (child in self) {
            if ([child conformsToProtocol:@protocol(NGLogWriter)])
                [child logMessage:msg level:level];
        }
    }
}

@end


@implementation NSFileHandle (NGFileHandleLogWriter)

+(instancetype)fileHandleForLoggingAtPath:(NSString *)path mode:(mode_t)mode
{
    int fd = -1;
    if (path) {
        int flags = O_WRONLY | O_APPEND | O_CREAT;
        fd = open([path fileSystemRepresentation], flags, mode);
    }
    if (fd == -1) return nil;
    return [[self alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
}

-(void)logMessage:(NSString *)message level:(NGLoggerLevel)level
{
    @synchronized(self) {
        // Closed pipes should not generate exceptions in our caller. Catch here
        // as well [GTMLogger logInternalFunc:...] so that an exception in this
        // writer does not prevent other writers from having a chance.
        @try {
            NSString *line = [NSString stringWithFormat:@"%@\n", message];
            [self writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        }
        @catch (id e) {
            // Ignored
        }
    }
}

@end

#pragma mark - formatter

@implementation NGLogBasicFormatter

-(NSString *)prettyNameForFunc:(NSString *)func
{
    NSString* name = [func stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString* function = @"(Unkown)";
    if (name.length) {
        if (// Objective C __func__ and __PRETTY_FUNCTION__
            [name hasPrefix:@"-["] || [name hasPrefix:@"+["] ||
            // C++ __PRETTY_FUNCTION__ and other preadorned formats
            [name hasSuffix:@")"]) {
            function = name;
        } else {
            // Assume C99 __func__
            function = [NSString stringWithFormat:@"%@()", name];
        }
    }
    return function;
}

-(NSString *)stringForFunc:(NSString *)func
                withFormat:(NSString *)fmt
                    valist:(va_list)args
                     level:(NGLoggerLevel)level
{
    if (!(fmt && args)) return nil;
    return [[NSString alloc] initWithFormat:fmt arguments:args];
}

@end

static NSString* const NGLoggerLevelAssertString    = @"Assert";
static NSString* const NGLoggerLevelDebugString     = @"Debug";
static NSString* const NGLoggerLevelInfoString      = @"Info";
static NSString* const NGLoggerLevelUnknownString    = @"Unkown";
static NSString* const NGLoggerLevelErrorString     = @"Error";
@implementation NGLogStandardFormatter


-(instancetype)init
{
    if (self = [super init]) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [_dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        _pname = [[[NSProcessInfo processInfo] processName] copy];
        _pid = [[NSProcessInfo processInfo] processIdentifier];
        if (!(_dateFormatter && _pname)) {
            return nil;
        }
    }
    return self;
}

-(NSString *)stringForFunc:(NSString *)func
                withFormat:(NSString *)fmt
                    valist:(va_list)args
                     level:(NGLoggerLevel)level
{
    NSString *tstamp = nil;
    @synchronized (_dateFormatter) {
        tstamp = [_dateFormatter stringFromDate:[NSDate date]];
    }
    //取得级别字符串
    NSString* levelString = nil;
    switch (level) {
        case NGLoggerLevelAssert:
            levelString = NGLoggerLevelAssertString;
            break;
        case NGLoggerLevelDebug:
            levelString = NGLoggerLevelDebugString;
            break;
        case NGLoggerLevelError:
            levelString = NGLoggerLevelErrorString;
            break;
        case NGLoggerLevelInfo:
            levelString = NGLoggerLevelInfoString;
            break;
        case NGLoggerLevelUnknown:
            levelString = NGLoggerLevelUnknownString;
            break;
        default:
            break;
    }
    return [NSString stringWithFormat:@"\n%@ %@[%d/%p] [level=%@]\nFunction: %@\n %@\n",
            tstamp, self.pname, self.pid, pthread_self(),
            levelString, [self prettyNameForFunc:func],
            // |super| has guard for nil |fmt| and |args|
            [super stringForFunc:func withFormat:fmt valist:args level:level]];
}

@end


#pragma mark - Filter
static BOOL IsVerboseLoggingEnabled(void) {
    static NSString *const kVerboseLoggingKey = @"NGVerboseLogging";
    NSString *value = [[[NSProcessInfo processInfo] environment]
                       objectForKey:kVerboseLoggingKey];
    if (value) {
        // Emulate [NSString boolValue] for pre-10.5
        value = [value stringByTrimmingCharactersInSet:
                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([[value uppercaseString] hasPrefix:@"Y"] ||
            [[value uppercaseString] hasPrefix:@"T"] ||
            [value intValue]) {
            return YES;
        } else {
            return NO;
        }
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:kVerboseLoggingKey];
}

@implementation NGLogLevelFilter
- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(defaultsChanged:)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];
        
        verboseLoggingEnabled_ = IsVerboseLoggingEnabled();
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSUserDefaultsDidChangeNotification
                                                  object:nil];
}

-(BOOL)filterAllowsMessage:(NSString *)msg level:(NGLoggerLevel)level
{
#if defined(DEBUG) && DEBUG
    return YES;
#endif
    
    BOOL allow = YES;
    
    switch (level) {
        case NGLoggerLevelDebug:
            allow = NO;
            break;
        case NGLoggerLevelInfo:
            allow = verboseLoggingEnabled_;
            break;
        case NGLoggerLevelError:
            allow = YES;
            break;
        case NGLoggerLevelAssert:
            allow = YES;
            break;
        default:
            allow = YES;
            break;
    }
    
    return allow;
}

- (void)defaultsChanged:(NSNotification *)note {
    verboseLoggingEnabled_ = IsVerboseLoggingEnabled();
}

@end

@implementation NGLogNoFilter

- (BOOL)filterAllowsMessage:(NSString *)msg level:(NGLoggerLevel)level {
    return YES;  // Allow everything through
}

@end

@implementation NGLogAllowedLevelFilter

- (instancetype)initWithAllowedLevels:(NSIndexSet *)levels
{
    self = [super init];
    if (self != nil) {
        allowedLevels_ = levels;
        // Cap min/max level
        if (!allowedLevels_ ||
            // NSIndexSet is unsigned so only check the high bound, but need to
            // check both first and last index because NSIndexSet appears to allow
            // wraparound.
            ([allowedLevels_ firstIndex] > NGLoggerLevelAssert) ||
            ([allowedLevels_ lastIndex] > NGLoggerLevelAssert)) {
            return nil;
        }
    }
    return self;
}


-(instancetype)init
{
    return [self initWithAllowedLevels:[NSIndexSet indexSetWithIndexesInRange:
                                        NSMakeRange(NGLoggerLevelUnknown,
                                                    (NGLoggerLevelAssert - NGLoggerLevelUnknown + 1))]];
}

-(BOOL)filterAllowsMessage:(NSString *)msg level:(NGLoggerLevel)level
{
    return [allowedLevels_ containsIndex:level];
}
@end

@implementation NGLogMininumLevelFilter

- (id)initWithMinimumLevel:(NGLoggerLevel)level {
    return [super initWithAllowedLevels:[NSIndexSet indexSetWithIndexesInRange:
                                         NSMakeRange(level,
                                                     (NGLoggerLevelAssert - level + 1))]];
}

@end  // GTMLogMininumLevelFilter


@implementation NGLogMaximumLevelFilter

- (id)initWithMaximumLevel:(NGLoggerLevel)level {
    return [super initWithAllowedLevels:[NSIndexSet indexSetWithIndexesInRange:
                                         NSMakeRange(NGLoggerLevelUnknown, level + 1)]];
}

@end

