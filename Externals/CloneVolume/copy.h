//
//  copy.h
//  CloneVolume
//
//  Created by Pumptheory P/L on 18/03/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

#ifndef COPY_H_
#define COPY_H_

#include <stdint.h>
#include <sys/attr.h>

static inline struct attrlist
copy_attrs_list (void)
{
  return (struct attrlist) {
    .bitmapcount = ATTR_BIT_MAP_COUNT,
    .commonattr = (ATTR_CMN_CRTIME | ATTR_CMN_MODTIME | ATTR_CMN_BKUPTIME 
		   | ATTR_CMN_FNDRINFO | ATTR_CMN_OWNERID | ATTR_CMN_GRPID
		   | ATTR_CMN_ACCESSMASK | ATTR_CMN_FLAGS | ATTR_CMN_FILEID),
    .dirattr = ATTR_DIR_LINKCOUNT,
    .fileattr = (ATTR_FILE_LINKCOUNT | ATTR_FILE_DEVTYPE 
		 | ATTR_FILE_DATALENGTH | ATTR_FILE_RSRCLENGTH),
  };
}

typedef struct copy_attrs copy_attrs_t;

#pragma pack(push,4)
typedef struct {
  uint8_t bytes[32];
} fndrinfo_t;

/* The following trickery is so that you can define other structures that
   add to it without then needing to add something like "ca." before 
   every member.  */

/* Note that if it's a directory, we use the space that files would use
   for our own purposes. */

#define COPY_ATTRS					      \
  union {						      \
    struct {						      \
      struct timespec crtime, modtime, bkuptime;	      \
    };							      \
    void *release_backtrace[4];				      \
  };							      \
  fndrinfo_t fndrinfo;					      \
  uid_t ownerid, grpid;					      \
  uint32_t accessmask;					      \
  uint32_t flags;					      \
  uint64_t file_id;					      \
  uint32_t link_count;					      \
  union {						      \
    struct {						      \
      uint32_t devtype;					      \
      off_t datalength, rsrclength;			      \
    };							      \
    struct {						      \
      uint32_t ref_count;				      \
      copy_attrs_t *parent;				      \
      struct dir *dir;					      \
    };							      \
  };

struct copy_attrs {
  COPY_ATTRS
};

#define COPY_ATTRSN					      \
  attrreference_t name;					      \
  union {						      \
    copy_attrs_t ca;					      \
    struct {						      \
      COPY_ATTRS					      \
    };							      \
  };

typedef struct copy_attrsn {
  COPY_ATTRSN
} copy_attrsn_t;

#pragma pack(pop)

static inline const char *
__attribute__ ((__pure__))
name_from_attrref (const attrreference_t *ref)
{
  if (!ref->attr_dataoffset || !ref->attr_length)
    return NULL;
  return (char *)ref + ref->attr_dataoffset;
}

struct dir {
  unsigned count;
  copy_attrsn_t *attrs[];
};

typedef struct copy_progress {
  void *ctx;
  enum progress_state {
    ST_STARTING_OP,
    ST_FINISHED_OP,
    ST_COPIED_DATA,
  } state;
  uint64_t done;
  copy_attrs_t *attrs;
  const char *dst_path;
} copy_progress_t;

typedef enum {
  HARD_LINK_IGNORE,
  HARD_LINK_COPY_TARGET,
  HARD_LINK_MAKE_LINK,
} hard_link_handler_ret_t;

typedef struct copy_options {
  void *ctx;
  int (* progress_fn) (copy_progress_t *progress);
  bool recursive;
#if DEBUG
  bool skip_data; // Useful for testing only
#endif
  bool meta_only;
  dev_t devid;
  hard_link_handler_ret_t 
    (* hard_link_handler_fn) (void *ctx,
			      struct copy_attrs *src_attrs,
			      char **ptarget_path);
} copy_options_t;

int copy_object (const char *src, const char *dst, copy_options_t *opts,
		 copy_attrs_t *attrs, void *buf, size_t buf_size);
int rm_object (const char *path);
int get_devid (int fd, dev_t *pdev_id);
int make_link (const char *target, const char *dst);

#endif // COPY_H_
