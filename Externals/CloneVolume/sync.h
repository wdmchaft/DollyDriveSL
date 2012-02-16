//
//  sync.h
//  CloneVolume
//
//  Created by Pumptheory P/L on 28/03/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

#ifndef SYNC_H_
#define SYNC_H_

typedef struct sync_progress {
  uint64_t done, total;
  void *ctx;
} sync_progress_t;

typedef struct sync_options {
  int (*progress_fn) (sync_progress_t *progress);
  void *ctx;
} sync_options_t;

int sync_objects (const char *src, const char *dst, sync_options_t *opts);

#endif // SYNC_H_
