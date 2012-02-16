//
//  sync-private.h
//  CloneVolume
//
//  Created by Pumptheory P/L on 3/04/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

#ifndef SYNC_PRIVATE_H_
#define SYNC_PRIVATE_H_

#include <pthread.h>
#include <sys/stat.h>

#include "copy.h"
#include "sync.h"

/* This is how much progress we allocate to each item that we scan.
   For each file we copy, 1 unit of progress equals 1 byte of data
   that we have to copy, so this is relative to that i.e. we consider
   the processing of 1 entry to be equal to x bytes. */
#define OBJ_PROGRESS_FACTOR   1000ull

#pragma pack(push, 4)
struct sync_attrs {
  /* NOTE: This is a bit of a hack and is generally frowned upon, bit I'm
     sacrificing portability for the sake of readability.  The length must
     match up with that returned by getdirentriesattr. */
#if __LITTLE_ENDIAN__
  uint16_t len;
  bool will_copy : 1;
  bool is_hard_link : 1;
  bool deferred_hard_link : 1;
  uint16_t padding : 13;
#else
  bool will_copy : 1;
  bool is_hard_link : 1;
  bool deferred_hard_link : 1;
  uint16_t padding : 13;
  uint16_t len;
#endif
  union {
    copy_attrsn_t can;
    struct {
      COPY_ATTRSN
    };
  };
};
#pragma pack(pop)

struct q {
  bool closed;
  unsigned width;
  void *buf;
  unsigned in, out;
};

struct op_entry {
  enum op_type {
    OP_COPY = 1,
    OP_REMOVE,
    OP_COPY_META,
  } op;
  struct sync_attrs *dir, *file;
};

struct sync_ctx {
  const char *src;
  const char *dst;
  
  bool aborted;
  bool ignore_owners;
  bool case_sensitive;

  pthread_t lock_owner;
  pthread_mutex_t mutex;
  pthread_cond_t cond;
  
  dev_t src_devid;
  
  struct page *free_pages;
  struct page *first_page;
  
  struct sync_attrs root;
  
  struct q scannedq, opq, copydirq;
  
  sync_options_t *opts;
  sync_progress_t progress;

  uint32_t src_entry_count, expected_entry_count;
  uint64_t actual_data, expected_data;

  struct sync_attrs *private_dir, *var_dir;

  struct __CFSet *hard_links;
};

static inline void lock (struct sync_ctx *ctx)
{
#if DEBUG
  assert (!pthread_equal (ctx->lock_owner, pthread_self()));
#endif
  pthread_mutex_lock (&ctx->mutex);
#if DEBUG
  ctx->lock_owner = pthread_self ();
#endif
}

static inline void unlock (struct sync_ctx *ctx)
{
  // Unlock is called in a few error scenarios, so preserve errno here
  int err = errno;
#if DEBUG
  assert (pthread_equal (ctx->lock_owner, pthread_self ()));
  ctx->lock_owner = NULL;
#endif
  pthread_mutex_unlock (&ctx->mutex);
  errno = err;
}

static inline void sync_wait (struct sync_ctx *ctx)
{
#if DEBUG
  assert (pthread_equal (ctx->lock_owner, pthread_self ()));
  ctx->lock_owner = NULL;
#endif
  pthread_cond_wait (&ctx->cond, &ctx->mutex);
#if DEBUG
  ctx->lock_owner = pthread_self ();
#endif
}

static inline void assert_locked (struct sync_ctx *ctx)
{
#if DEBUG
  assert (pthread_equal (ctx->lock_owner, pthread_self ()));
#endif
}

static inline bool attrs_is_dir (const struct sync_attrs *attrs)
{
  return S_ISDIR (attrs->accessmask);
}

void free_dir (struct sync_ctx *ctx, 
	       struct sync_attrs *attrs, 
	       struct dir *dir);

/* File entries don't have a retain count so it's up to the caller to ensure
   that they survive. */
static inline void retain_attrs (struct sync_ctx *ctx, 
				 struct sync_attrs *attrs)
{
  assert_locked (ctx);

#if 0
  fprintf (stderr, "%p +1 %p %p\n", attrs,
	   __builtin_return_address (0),
	   __builtin_return_address (1));
#endif
  
  if (attrs_is_dir (attrs))
    ++attrs->ref_count;
}

// Returns true if attrs was destroyed
bool release_attrs (struct sync_ctx *ctx, struct sync_attrs *attrs);
void destroy_entry (struct sync_ctx *ctx, struct sync_attrs *entry);

static inline struct sync_attrs *
sync_attrs_from_copy_attrs (copy_attrs_t *copy_attrs)
{
  return (copy_attrs ?
	  (void *)copy_attrs - offsetof (struct sync_attrs, ca)
	  : NULL);
}

static inline struct sync_attrs *
__attribute__ ((__pure__))
sync_attrs_from_copy_attrsn (copy_attrsn_t *copy_attrsn)
{
  return (copy_attrsn
	  ? (void *)copy_attrsn - offsetof (struct sync_attrs, can)
	  : NULL);
}

static inline const char *
__attribute__ ((__pure__))
attrs_name (const struct sync_attrs *attrs)
{
  if (!attrs)
    return NULL;
  return name_from_attrref (&attrs->name);
}

static inline struct sync_attrs *
__attribute__ ((__pure__))
attrs_parent (const struct sync_attrs *attrs)
{
  return sync_attrs_from_copy_attrs (attrs->parent);
}

char *
attrs_path (char path_buf[PATH_MAX], 
	    struct sync_attrs *attrs,
	    const char *prefix,
	    const char *suffix);

void queue_copy_op (struct sync_ctx *ctx, 
		    struct sync_attrs *dir,
		    struct sync_attrs *entry,
		    copy_attrsn_t **pdir_entry);

#endif // SYNC_PRIVATE_H_
