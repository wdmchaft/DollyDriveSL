/*
 *  CloneTask.h
 
 
 */

#include "CVDisk.h"


@protocol CloneTaskDelegate;

@interface CloneTask : NSObject {
    CVDisk *sourceDisk;
    CVDisk *targetDisk;
    BOOL busy;
    BOOL aborted;
    BOOL formatting;
    BOOL paused;
    int helperStatus;
    int helperState;
    BOOL rebuildPending;
    BOOL incremental;
    double progress;
    int state;
    id<CloneTaskDelegate> delegate;
    NSDate *lastRunDate;
    NSDate *nextRunDate;
    int interval;
    NSError *error;
    NSMenuItem *menuItem;
    NSTask *myTask;
    FILE *readFilePtr;
}


@property (assign) BOOL formatting;
@property (assign) BOOL aborted;
@property (assign) BOOL incremental;
@property (assign) BOOL busy;
@property (assign) BOOL paused;

@property (assign) CVDisk *sourceDisk;
@property (assign) CVDisk *targetDisk;
@property (assign) double progress;
@property (assign) int state;
@property (assign) id<CloneTaskDelegate> delegate;
@property (assign) NSMenuItem *menuItem;
@property (assign) NSError *error;
@property (retain) NSDate *lastRunDate;
@property (retain) NSDate *nextRunDate;
@property (assign) int interval;


- (BOOL)isTargetSizeOk;
- (void)Start;
- (void)Abort:(id)sender;
- (BOOL)Continue;
- (BOOL)Pause;
- (void)startCloneThread;
- (void)updateSettings;
- (void)getSettings;
- (void)writePipe:(NSString *)stringdata;
- (void)monitorTM;

@end

@protocol CloneTaskDelegate <NSObject>
- (void)cloneDidFinishSuccessfully:(CloneTask *)task;
- (void)updateTaskProgress:(CloneTask *)task;
- (void)finishedWithError:(CloneTask *)task;
@end
