/*
 *  CloneTask.h
 
 
 */

#include "DSDisk.h"


@protocol DSCloneTaskDelegate;

@interface DSCloneTask : NSObject {
    DSDisk *sourceDisk;
    DSDisk *targetDisk;
    BOOL busy;
    BOOL aborted;
    BOOL paused;
    int helperStatus;
    int helperState;
    BOOL rebuildPending;
    BOOL incremental;
    double progress;
    int state;
    id<DSCloneTaskDelegate> delegate;
    NSDate *lastRunDate;
    NSDate *nextRunDate;
    int interval;
    NSError *error;
   // NSMenuItem *menuItem;
    NSTask *myTask;
    FILE *readFilePtr;
}



@property (assign) BOOL aborted;
@property (assign) BOOL incremental;
@property (assign) BOOL busy;
@property (assign) BOOL paused;

@property (assign) DSDisk *sourceDisk;
@property (assign) DSDisk *targetDisk;
@property (assign) double progress;
@property (assign) int state;
@property (assign) id<DSCloneTaskDelegate> delegate;
//@property (assign) NSMenuItem *menuItem;
@property (assign) NSError *error;
@property (retain) NSDate *lastRunDate;
@property (retain) NSDate *nextRunDate;
@property (assign) int interval;


- (BOOL)isTargetSizeOk;
- (void)Start;
- (void)Abort:(id)sender;
- (void)Continue;
- (void)Pause;
- (void)startCloneThread;
- (void)updateSettings;
- (void)getSettings;
- (void)writePipe:(NSString *)stringdata;
- (void)monitorTM;

@end

@protocol DSCloneTaskDelegate <NSObject>
- (void)cloneDidFinishSuccessfully:(DSCloneTask *)task;
- (void)updateTaskProgress:(DSCloneTask *)task;
- (void)finishedWithError:(DSCloneTask *)task;
@end
