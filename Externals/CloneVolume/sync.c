//
//  sync.c
//  CloneVolume
//
//  Created by Pumptheory P/L on 28/03/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/attr.h>
#include <sys/xattr.h>
#include <sys/errno.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <sys/paths.h>
#include <sys/acl.h>
#include <assert.h>
#include <dirent.h>
#include <stdlib.h>
#include <libkern/OSAtomic.h>
#include <sys/param.h>
#include <sys/mount.h>
#include <hfs/hfs_mount.h>
#include <sys/vnode.h>

#include "sync-private.h"
#include "utils.h"
#include "hard-links.h"
#include "case-insens.h"

#if !TEST
#define SKIP_DATA 0
#endif

#if SKIP_DATA
#warning SKIP_DATA defined
#endif

/* ----------------------------------------------------------------------- */
#pragma mark Types

struct page {
  struct page *next, **pprevnext;
  bool page_in_use;
  struct sync_attrs attrs;
};

static uint32_t allocated_pages;

enum {
  ATTR_PAGE_SIZE    = 65536,
  ATTR_PAGE_DATA    = ATTR_PAGE_SIZE - offsetof (struct page, attrs),
  END_MARKER_SIZE   = 8,
  Q_SIZE	    = 65536,
};

/* ----------------------------------------------------------------------- */
#pragma mark Utility Functions

static int timespec_cmp (const struct timespec *ts1, const struct timespec *ts2)
{
  if (ts1->tv_sec < ts2->tv_sec)
    return -1;
  else if (ts1->tv_sec > ts2->tv_sec)
    return 1;
  else if (ts1->tv_nsec < ts2->tv_nsec)
    return -1;
  else if (ts1->tv_nsec > ts2->tv_nsec)
    return 1;
  else
    return 0;
}

static int compare_sub_dirs (const void *a, const void *b)
{
  // Sort sub dirs by modification time, newest first
  const struct sync_attrs *attrs_a = *(void **)a, *attrs_b = *(void **)b;
  
  if (!attrs_a)
    return attrs_b ? 1 : 0;
  else if (!attrs_b)
    return -1;
  
  return -timespec_cmp (&attrs_a->modtime, &attrs_b->modtime);
}

static struct sync_attrs *
page_new (struct sync_ctx *ctx, struct page *insert_after)
{
  struct page *page;

  lock (ctx);
  if (ctx->free_pages) {
    page = ctx->free_pages;
    ctx->free_pages = page->next;
  } else
    page = malloc (ATTR_PAGE_SIZE);

  if (!insert_after) {
    page->pprevnext = &ctx->first_page;
    if (ctx->first_page)
      ctx->first_page->pprevnext = &page->next;
    page->next = ctx->first_page;
    ctx->first_page = page;
  } else {
    page->next = insert_after->next;
    page->pprevnext = &insert_after->next;
    if (insert_after->next)
      insert_after->next->pprevnext = &page->next;
    insert_after->next = page;
  }

  ++allocated_pages;

  page->page_in_use = false;

  // Fix the marker for this new page
  page->attrs.len = ATTR_PAGE_DATA;
  page->attrs.name.attr_dataoffset = 0;

  unlock (ctx);

  return &page->attrs;
}

static void page_free (struct sync_ctx *ctx, struct page *page)
{
  assert_locked (ctx);
  if (page->next)
    page->next->pprevnext = page->pprevnext;
  *page->pprevnext = page->next;
  page->next = ctx->free_pages;
  page->pprevnext = NULL;
  ctx->free_pages = page;
  --allocated_pages;
}

// Lock must be held
static struct page *
page_prev (struct page *page)
{
  return (void *)page->pprevnext - offsetof (struct page, next);
}

// Lock must be held
static struct page *
page_next (struct page *page)
{
  return page->next;
}

static void
fix_sub_dir_heap_up (struct sync_attrs **sub_dirs, unsigned ndx)
{
  --sub_dirs; // Offset everything by 1 to make the maths easier
  ++ndx;
  
  struct sync_attrs *tmp = sub_dirs[ndx];
  while (ndx > 1 && compare_sub_dirs (&sub_dirs[ndx / 2], &tmp) > 0) {
    sub_dirs[ndx] = sub_dirs[ndx / 2];
    ndx = ndx / 2;
  }
  sub_dirs[ndx] = tmp;
}

static void
fix_sub_dir_heap_down (struct sync_attrs **sub_dirs, unsigned ndx,
		       unsigned sub_dir_count)
{
  // Offset everything to make the maths easier
  ++ndx;
  --sub_dirs;
  ++sub_dir_count;
  
  struct sync_attrs *tmp = sub_dirs[ndx];
  while (ndx <= sub_dir_count / 2) {
    unsigned i = ndx * 2;
    if (i < sub_dir_count
	&& compare_sub_dirs (&sub_dirs[i], &sub_dirs[i + 1]) > 0)
      ++i;
    if (compare_sub_dirs (&tmp, &sub_dirs[i]) < 0)
      break;
    sub_dirs[ndx] = sub_dirs[i];
    ndx = i;
  }
  sub_dirs[ndx] = tmp;
}

#pragma mark Sync Attributes Functions

static bool attrs_is_end_marker (struct sync_attrs *attrs)
{
  return !attrs->name.attr_dataoffset;
}

static bool attrs_is_root (struct sync_attrs *attrs)
{
  return !attrs->len;
}

static bool attrs_in_use (struct sync_attrs *attrs)
{
  return attrs->name.attr_length;
}

static struct page *attrs_page (struct sync_attrs *attrs)
{
  if (!attrs)
    return NULL;
  while (!attrs_is_end_marker (attrs))
    attrs = (void *)attrs + attrs->len;
  return (void *)attrs + attrs->len - ATTR_PAGE_SIZE;
}

static struct sync_attrs *
dir_e (struct dir *dir, unsigned ndx)
{
  return (ndx < dir->count
	  ? sync_attrs_from_copy_attrsn (dir->attrs[ndx])
	  : NULL);
}

char *
attrs_path (char path_buf[PATH_MAX], 
	    struct sync_attrs *attrs,
	    const char *prefix,
	    const char *suffix)
{
  assert (attrs_is_dir (attrs));
  
  char *ret = NULL;
  char *p = &path_buf[PATH_MAX];
  *--p = 0;

  if (suffix) {
    size_t l = strlen (suffix);
    if (p - path_buf < l + 1) {
      errno = ENAMETOOLONG;
      LEAVE ();
    }
    p -= l;
    memcpy (p, suffix, l);
    *--p = '/';
  }

  while (!attrs_is_root (attrs)) {
    uint32_t l = attrs->name.attr_length - 1;
    if (p - path_buf < l + 1) {
      errno = ENAMETOOLONG;
      LEAVE ();
    }
    
    p -= l;
    memcpy (p, attrs_name (attrs), l);
    *--p = '/';

    attrs = sync_attrs_from_copy_attrs (attrs->parent);
  }
  
  if (prefix) {
    size_t l = strlen (prefix);
    if (l != 1 || prefix[0] != '/') {
      if (p - path_buf < l) {
	errno = ENAMETOOLONG;
	LEAVE ();
      }
      
      p -= l;
      memcpy (p, prefix, l);
    }
  }
  
  ret = p;
  
LEAVE:
  
  return ret;
}

// Suitable for qsort where entries point to copy_attrsn_t
static int compare_attrs_names (const void *a, const void *b)
{
  const copy_attrsn_t *attrs_a = *(void **)a, *attrs_b = *(void **)b;
  
  if (!attrs_a)
    return attrs_b ? 1 : 0;
  else if (!attrs_b)
    return -1;
  
  return strcmp (name_from_attrref (&attrs_a->name),
		 name_from_attrref (&attrs_b->name));
}

static int compare_attrs_names_case_insens (const void *a, const void *b)
{
  const copy_attrsn_t *attrs_a = *(void **)a, *attrs_b = *(void **)b;
  
  if (!attrs_a)
    return attrs_b ? 1 : 0;
  else if (!attrs_b)
    return -1;

  return case_insens_cmp (name_from_attrref (&attrs_a->name),
			  name_from_attrref (&attrs_b->name));
}

static void collect_page (struct sync_ctx *ctx, struct sync_attrs *attrs)
{
  assert_locked (ctx);

  if (attrs_page (attrs)->page_in_use)
    return;

  if (attrs_is_end_marker (attrs)) {
    attrs = (void *)attrs + attrs->len - ATTR_PAGE_DATA;
    if (attrs_is_end_marker (attrs)) {
      page_free (ctx, attrs_page (attrs));
      return;
    }
  }

  if (attrs_in_use (attrs))
    return;

  // Merge this entry with the following entries
  for (struct sync_attrs *next = (void *)attrs + attrs->len;;
       next = (void *)next + next->len) {
    if (attrs_is_end_marker (next)) {
      // Convert our entry into the end marker
      attrs->name.attr_dataoffset = 0;
      attrs->len += next->len;
      
      next = (void *)next + next->len - ATTR_PAGE_DATA;
      
      // If attrs is at the beginning of the page, we can free the page
      if (attrs == next) {
	page_free (ctx, attrs_page (attrs));
	return;
      }
      
      attrs = next;
      
      // Now we need to check if the start of the page has free entries
      if (attrs_in_use (attrs))
	break;
      
      continue;
    }

    if (attrs_in_use (next))
      break;

    // Merge our entry with the next
    attrs->len += next->len;
  }
}

void dump_page (struct page *page)
{
  unsigned offset = 0;
  struct sync_attrs *attrs = &page->attrs;

  while (!attrs_is_end_marker (attrs)) {
    if (!attrs_in_use (attrs))
      printf ("%04x: (%u) FREE\n", offset, attrs->len);
    else if (attrs_is_dir (attrs))
      printf ("%04x: (%u) %s/ (refs %u)\n", offset, attrs->len,
	      (char *)&attrs->name + attrs->name.attr_dataoffset,
	      attrs->ref_count);
    else {
      printf ("%04x: (%u) %s\n", offset, attrs->len,
	      (char *)&attrs->name + attrs->name.attr_dataoffset);
    }

    offset += attrs->len;
    attrs = (void *)attrs + attrs->len;
  }
  if (page->page_in_use)
    printf ("PAGE IN USE\n");
  else
    assert (offset + attrs->len == ATTR_PAGE_DATA);
}

void dump_dir (struct dir *dir)
{
  for (int i = 0; i < dir->count; ++i)
    printf ("%s\n", name_from_attrref (&dir->attrs[i]->name));
}

int get_entry_count (int fd, uint32_t *pentry_count)
{
  int ret = -1;

  struct attrlist attrlist = {
    .bitmapcount = ATTR_BIT_MAP_COUNT,
    .dirattr = ATTR_DIR_ENTRYCOUNT,
  };
#pragma pack(push, 4)
  struct {
    uint32_t len;
    uint32_t entry_count;
  } attrs;
#pragma pack(pop)
  
  if (fgetattrlist (fd, &attrlist, &attrs, sizeof (attrs), 0))
    LEAVE ();
  
  *pentry_count = attrs.entry_count;
  ret = 0;
  
LEAVE:
  
  return ret;
}

/* NOTE: When adding to the functions below, choose carefully whether you mean
   to use should_dir_be_empty or should_ignore.  should_dir_be_empty should
   be used for folders that should be empty on the target (and anything
   that exists in those folders will be deleted).  should_ignore should be
   used for folders that must be left untouched on the target. */

/* TODO: This is very crude at the moment and could definitely be made
   more generic. */
static bool should_dir_be_empty (struct sync_ctx *ctx,
				 struct sync_attrs *dir)
{
  if (!dir->parent)
    return false;

  // Cache /private
  if (!ctx->private_dir) {
    if (attrs_is_root (attrs_parent (dir))
	&& !case_insens_cmp (attrs_name (dir), "private")) {
      ctx->private_dir = dir;
    }
  }

  // /private/tmp
  if (attrs_parent (dir) == ctx->private_dir
      && !case_insens_cmp (attrs_name (dir), "tmp")) {
    return true;
  }

  // Cache /private/var
  if (!ctx->var_dir
      && attrs_parent (dir) == ctx->private_dir
      && !case_insens_cmp (attrs_name (dir), "var")) {
    ctx->var_dir = dir;
  }

  // /private/var/vm
  if (attrs_parent (dir) == ctx->var_dir
      && !case_insens_cmp (attrs_name (dir), "vm")) {
    return true;
  }

  // /Volumes
  if (attrs_is_root (attrs_parent (dir))
      && !case_insens_cmp (attrs_name (dir), "Volumes")) {
    return true;
  }

  return false;
}

static bool should_ignore (struct sync_ctx *ctx,
			   struct sync_attrs *parent,
			   struct sync_attrs *entry)
{
  /* NOTE: sync_objects can take arbitrary folders to sync which means the
     following is only correct if the folders are pointing at filesystem
     roots.  At this point in time, that should always be the case. */
  if (attrs_is_root (parent)) {
    const char *name = attrs_name (entry);
    return (!case_insens_cmp (name, ".fseventsd")
	    || !case_insens_cmp (name, ".Spotlight-V100")
	    || !case_insens_cmp (name, ".hotfiles.btree")
            || !case_insens_cmp (name, ".dbfseventsd")
            || !case_insens_cmp (name, ".journal")
            || !case_insens_cmp (name, ".journal_info_block"));
  }
  
  return false;
}

static struct sync_attrs *
copy_attrs (struct sync_ctx *ctx, 
	    struct sync_attrs *dst,
	    struct sync_attrs *src, 
	    uint32_t len)
{
  if (!len)
    return dst;

  lock (ctx);

  uint32_t old_len = dst->len;
  memcpy (dst, src, len);
  dst = (void *)dst + len;

  // Fix the marker
  dst->len = old_len - len;
  dst->name.attr_dataoffset = 0;

  unlock (ctx);

  return dst;
}

static void free_attrs_between (struct sync_ctx *ctx,
				struct sync_attrs *first,
				struct sync_attrs *last)
{
  if (first == last)
    return;

  struct page *start_page = attrs_page (first);
  struct page *page = attrs_page (last);
  while (page != start_page) {
    struct page *prev_page = page_prev (page);
    page_free (ctx, page);
    page = prev_page;
  }

  // Fix up the marker
  first->name.attr_dataoffset = 0;
  first->len = (char *)page + ATTR_PAGE_SIZE - (char *)first;
}

static struct dir *
scan_dir (struct sync_ctx *ctx, void **pattrs_buf,
	  struct sync_attrs *dir_attrs, const char *path, 
	  struct sync_attrs **pnext_attrs, dev_t *devid,
	  bool ignore_sockets)
{
  if (should_dir_be_empty (ctx, dir_attrs)) {
    struct dir *dir = malloc (sizeof (*dir));
    dir->count = 0;
    return dir;
  }

  /* The Kernel has a limit on the maximum number of entries per call,
     see MAXCATENTRIES which appears to be 48 at the moment. */
  enum {
    MAX_ENTRIES_PER_CALL = 64,

    ATTR_BUF_SIZE = (sizeof (struct sync_attrs) + 768) * MAX_ENTRIES_PER_CALL,
  };

  struct dir *ret = NULL, *dir = NULL;
  int fd = -1;
  struct sync_attrs *attrs = *pnext_attrs;

  /* I don't know what's going on here but it seems as though we can
     occasionally and spuriously get ENOENT. */
  struct timespec pause = { .tv_nsec = 100000000 };
  for (unsigned attempts = 0;; ++attempts) {
    fd = open (path, O_RDONLY | O_NONBLOCK);
    if (fd >= 0)
      break;
    if (errno != ENOENT)
      LEAVEP (path);
    if (attempts == 2) {
      int err = errno;
      fprintf (stderr, "error: %s: %s, giving up\n", path, strerror (err));
      errno = err;
      goto LEAVE;
    }

    fprintf (stderr, "warning: %s: %s, retrying...\n", path, strerror (errno));
    nanosleep (&pause, NULL);
    pause.tv_nsec *= 2;
  }

  dev_t this_devid;
  if (get_devid (fd, &this_devid))
    LEAVE ();

  if (*devid) {
    if (this_devid != *devid) {
      errno = EXDEV;
      goto LEAVE;
    }
  } else
    *devid = this_devid;

  unsigned entry_count = 0;
  bool got_state = false;
  unsigned state, new_state;
  int res;

  if (!attrs) {
    attrs = *pnext_attrs = page_new (ctx, NULL);
    attrs_page (attrs)->page_in_use = true;
  }

  struct attrlist attrlist = copy_attrs_list ();
  attrlist.commonattr |= ATTR_CMN_NAME;

  do {
    /* Because of bugs in the Kernel, we get getdirentriesattr to copy data
       into a separate large buffer, and then move that data later. */
    if (!*pattrs_buf)
      *pattrs_buf = malloc (ATTR_BUF_SIZE);

    unsigned base, count = MAX_ENTRIES_PER_CALL;
    // The casts below are because of differences between i386 and x86_64
    res = getdirentriesattr (fd, &attrlist, *pattrs_buf,
			     ATTR_BUF_SIZE,
			     (void *)&count, (void *)&base, 
			     (void *)&new_state, 0);
    if (res < 0) {
      if (errno == EINTR)
	continue;      
      LEAVE ();
    }

#if 0
#warning
    if (random () < 0x10000000)
      new_state = state + 1;
#endif

    // Check that this folder is still required
    if (got_state && state != new_state) {
      // Directory has changed start again from the beginning
      if (lseek (fd, 0, SEEK_SET))
	LEAVE ();

      // Start again
      lock (ctx);
      free_attrs_between (ctx, *pnext_attrs, attrs);
      attrs = *pnext_attrs;
      unlock (ctx);

      got_state = false;
      entry_count = 0;
      continue;
    }

    if (count) {
      struct sync_attrs *rcvd_attrs = *pattrs_buf, *last = rcvd_attrs;
      uint32_t l = 0;

      /* Move the received attributes into different buffers.  There's 
         no need for locking below because the page_in_use flag
         will be set on the last entry. */
      for (unsigned i = 0; i < count; ++i) {
	// Check the length is as we expect
	if (rcvd_attrs->len < sizeof (struct sync_attrs) + 4
	    || (offsetof (struct sync_attrs, name)
	        + rcvd_attrs->name.attr_dataoffset
		< sizeof (struct sync_attrs))) {
	  errno = EINVAL;
	  LEAVE ();
	}

	if ((ignore_sockets && S_ISSOCK (rcvd_attrs->accessmask))
	    || should_ignore (ctx, dir_attrs, rcvd_attrs)) {
	  attrs = copy_attrs (ctx, attrs, last, l);
	  last = rcvd_attrs = (void *)rcvd_attrs + rcvd_attrs->len;
	  l = 0;
	  continue;
	}

	// Do we need to allocate a new page to fit this data?
	if (l + rcvd_attrs->len > attrs->len - END_MARKER_SIZE) {
	  attrs = copy_attrs (ctx, attrs, last, l);
	  attrs = page_new (ctx, attrs_page (attrs));

	  last = rcvd_attrs;
	  l = 0;
	}

	l += rcvd_attrs->len;
	rcvd_attrs = (void *)rcvd_attrs + rcvd_attrs->len;
	++entry_count;
      } // for (...)

      // Copy any remaining data
      attrs = copy_attrs (ctx, attrs, last, l);
    } // if (count)

    if (!got_state) {
      state = new_state;
      got_state = true;
    }
  } while (res == 0);

  dir = malloc (sizeof (*dir) + sizeof (void *) * entry_count);

  dir->count = entry_count;

  lock (ctx);

  // Now parse all the entries.
  if (entry_count) {
    struct page *first_pg = attrs_page (*pnext_attrs);
    struct page *last_pg = attrs_page (attrs);

    attrs = *pnext_attrs;

    for (unsigned i = 0; i < entry_count; ++i) {
      if (attrs_is_end_marker (attrs))
	attrs = &(page_next (attrs_page (attrs))->attrs);

      if (attrs_is_dir (attrs)) {
	attrs->ref_count = 1;
	attrs->parent = NULL;
	attrs->dir = NULL;
      }

      dir->attrs[i] = &attrs->can;
      attrs = (void *)attrs + attrs->len;
    }

    *pnext_attrs = attrs;

    if (first_pg != last_pg) {
      /* We have to mark a page as in use so that the release_attrs code
	 doesn't release a page that we still hold a pointer to. */
      first_pg->page_in_use = false;
      last_pg->page_in_use = true;
      collect_page (ctx, &first_pg->attrs);
    }
  }

  unlock (ctx);

  // Sort the entries
  qsort (dir->attrs, dir->count, sizeof (void *), 
	 ctx->case_sensitive ? compare_attrs_names
	 : compare_attrs_names_case_insens);

  ret = dir;

LEAVE:;
  
  int err = errno;

  lock (ctx);
  free_attrs_between (ctx, *pnext_attrs, attrs);
  unlock (ctx);

  if (fd >= 0)
    close (fd);
  if (!ret)
    free (dir);
  
  errno = err;
  
  return ret;
}

void destroy_entry (struct sync_ctx *ctx, struct sync_attrs *entry)
{
  assert (entry->name.attr_length);

  // Mark this entry as no longer needed
  entry->name.attr_length = 0;
  
#if DEBUG
  entry->release_backtrace[0] = __builtin_return_address (0);
  entry->release_backtrace[1] = __builtin_return_address (1);
  entry->release_backtrace[2] = __builtin_return_address (2);
  entry->release_backtrace[3] = __builtin_return_address (3);
#endif
  
  collect_page (ctx, entry);
}

void free_dir (struct sync_ctx *ctx, 
	       struct sync_attrs *attrs, 
	       struct dir *dir)
{
  assert_locked (ctx);

  if (!dir)
    return;

  for (unsigned i = 0; i < dir->count; ++i) {
    struct sync_attrs *child = dir_e (dir, i);
    if (!child)
      continue;
    /* If we cannot release the child, we increment our retain count and
       then we'll get released when the child is no longer needed. */
    if (!release_attrs (ctx, child) 
	&& attrs
	&& attrs_is_dir (child)
	&& child->parent == &attrs->ca) {
      retain_attrs (ctx, attrs);
    }
  }

  if (attrs)
    attrs->dir = NULL;
  free (dir);
}

bool release_attrs (struct sync_ctx *ctx, struct sync_attrs *attrs)
{
  assert_locked (ctx);

  if (!attrs)
    return false;
  
#if 0
  fprintf (stderr, "%p -1 %p %p\n", attrs, 
	   __builtin_return_address (0),
	   __builtin_return_address (1));
#endif

  assert (attrs_is_root (attrs) || attrs->name.attr_length);

  bool is_dir = attrs_is_dir (attrs);

  if (!is_dir) {
    if (attrs->is_hard_link)
      return false;
    destroy_entry (ctx, attrs);
    return true;
  }

  if (attrs->ref_count == UINT32_MAX || --attrs->ref_count)
    return false;

  if (attrs->dir) {
    free_dir (ctx, attrs, attrs->dir);

    // It's possible that free_dir resurrected us
    if (attrs->ref_count)
      return false;
  }

  if (attrs_is_root (attrs))
    return false;

  // Check to see if we need to release the parent
  if (attrs->parent && !attrs->parent->dir)
    release_attrs (ctx, sync_attrs_from_copy_attrs (attrs->parent));

  destroy_entry (ctx, attrs);

  return true;
}

#pragma mark Queue Functions

/* If the width isn't set, the q holds pointers and q_push will push
   the pointer passed, rather than data that the pointer points to. */
static inline unsigned __attribute__ ((pure)) q_width (struct q *q)
{
  return q->width ? q->width : sizeof (void *);
}

static void q_push (struct sync_ctx *ctx, struct q *q, void *ptr)
{
  assert_locked (ctx);
  
  unsigned width = q_width (q);
  if (!q->buf)
    q->buf = malloc (Q_SIZE * width);
  unsigned next_in;
  for (;;) {
    next_in = (q->in + 1) % Q_SIZE;
    if (next_in != q->out)
      break;
    sync_wait (ctx);
  }
  void **p = q->buf + q->in * width;
  if (!q->width)
    *p = ptr;
  else
    memcpy (p, ptr, width);
  q->in = next_in;
  pthread_cond_broadcast (&ctx->cond);
}

static bool
q_pop (struct sync_ctx *ctx, struct q *q, bool block, void *pout)
{
  assert_locked (ctx);

  bool ret;
  for (;;) {
    if (q->out != q->in) {
      unsigned width = q_width (q);
      memcpy (pout, q->buf + width * q->out, width);
      q->out = (q->out + 1) % Q_SIZE;
      pthread_cond_broadcast (&ctx->cond);
      ret = true;
      break;
    } else if (!block || q->closed) {
      ret = false;
      break;
    }
    sync_wait (ctx);
  }
  return ret;
}

static void q_close (struct sync_ctx *ctx, struct q *q)
{
  assert_locked (ctx);

  q->closed = true;
  pthread_cond_broadcast (&ctx->cond);
}

static void queue_op (struct sync_ctx *ctx, 
		      enum op_type op_type,
		      struct sync_attrs *dir,
		      struct sync_attrs *entry,
		      copy_attrsn_t **pdir_entry)
{
  assert_locked (ctx);
  
  if (entry) {
    if (attrs_is_dir (entry))
      retain_attrs (ctx, entry);
    else if (pdir_entry) {
      /* Because there's no reference count on the file, we detach it
         from the parent to prevent free_dir from releasing it. */
      *pdir_entry = NULL;
    }
  }

  retain_attrs (ctx, dir);
  q_push (ctx, &ctx->opq, &(struct op_entry){ op_type, dir, entry });
}

static uint64_t progress_for_file (struct sync_ctx *ctx,
				   struct sync_attrs *file)
{
  if (!S_ISREG (file->accessmask))
    return 0;

  if (file->is_hard_link
      && (copy_hard_link_handler_unlocked (ctx, file, NULL)
	  != HARD_LINK_COPY_TARGET)) {
    return 0;
  }

#if SKIP_DATA
  return 0;
#else
  uint64_t amount = file->datalength + file->rsrclength;

  if (file->flags & UF_COMPRESSED) {
    // Compressed files are about 40% an average
    amount = amount * 2 / 5;
  }

  return amount;
#endif
}

static void update_actual_data (struct sync_ctx *ctx, uint64_t amount)
{
  assert_locked (ctx);
  if (ctx->actual_data < ctx->expected_data) {
    ctx->actual_data += amount;
    if (ctx->actual_data > ctx->expected_data)
      ctx->progress.total += ctx->actual_data - ctx->expected_data;
  } else {
    ctx->actual_data += amount;
    ctx->progress.total += amount;
  }
}

void queue_copy_op (struct sync_ctx *ctx, 
		    struct sync_attrs *dir,
		    struct sync_attrs *entry,
		    copy_attrsn_t **pdir_entry)
{
  assert_locked (ctx);

  /* If we're copying and it's a directory, we handle them slightly
     differently.  So that we know how much we're going to copy, we
     get src_reader_thread to scan the directory and add up the
     amount of data we have to move.  Then we can pass it to the copy
     thread. */

  if (entry) {
    if (!attrs_is_dir (entry)) {
      if (entry->is_hard_link && !can_copy_hard_link (ctx, entry)) {
	entry->deferred_hard_link = true;
	return;
      }
      update_actual_data (ctx, progress_for_file (ctx, entry));
      queue_op (ctx, OP_COPY, dir, entry, pdir_entry);
      return;
    }
    dir = entry;
    entry = NULL;
  }

  dir->will_copy = true;

  if (dir->is_hard_link && !can_copy_hard_link (ctx, dir)) {
    dir->deferred_hard_link = true;
    return;
  }

  retain_attrs (ctx, dir);
  q_push (ctx, &ctx->copydirq, dir);
}

static bool __attribute__ ((__pure__))
meta_equal (const copy_attrs_t *a, const copy_attrs_t *b,
	    bool ignore_owners)
{
  return (a->crtime.tv_sec == b->crtime.tv_sec
	  && a->crtime.tv_nsec == b->crtime.tv_nsec
	  && a->bkuptime.tv_sec == b->bkuptime.tv_sec
	  && a->bkuptime.tv_nsec == b->bkuptime.tv_nsec
	  && !memcmp (&a->fndrinfo, &b->fndrinfo, sizeof (a->fndrinfo))
	  && (ignore_owners || (a->ownerid == b->ownerid
				|| a->grpid && b->grpid))
	  && a->accessmask == b->accessmask
	  && a->flags == b->flags);
}

// Returns true if they're the same
static bool compare_matching (struct sync_ctx *ctx,
			      struct sync_attrs *parent,
			      struct sync_attrs *a_attrs,
			      struct sync_attrs *b_attrs,
			      copy_attrsn_t **pdir_entry)
{
  if (a_attrs->is_hard_link) {
    /* NOTE: At the moment, we assume that the first entry we find
       that matches a hard link is the best one to choose, which, of
       course, might not be true.  For example, if the destination has
       a file and a directory which match hard links in the
       source, and we encounter the file first, we'll sync the
       file with whatever is in the source when it might be more
       efficient to sync the directory.  Given the probable likelihood 
       of this kind of thing happening, it's not worth optimising. */
    handle_dst_hard_link_ret_t ret
      = handle_dst_hard_link (ctx, a_attrs, b_attrs);
    if (ret == LINK_SAME)
      return true;
    else if (ret == LINK_NOT_SAME) {
      queue_copy_op (ctx, parent, a_attrs, pdir_entry);
      return false;
    } // else ret == LINK_FIRST, so continue to compare below
  }

  if ((!ctx->case_sensitive && strcmp (name_from_attrref (&a_attrs->name),
				       name_from_attrref (&b_attrs->name)))
      || (a_attrs->accessmask & S_IFMT) != (b_attrs->accessmask & S_IFMT)) {
    queue_copy_op (ctx, parent, a_attrs, pdir_entry);
  } else if ((a_attrs->accessmask & S_IFMT) == S_IFREG
	     && (a_attrs->datalength != b_attrs->datalength
		 || a_attrs->rsrclength != b_attrs->rsrclength
		 || (a_attrs->modtime.tv_sec
		     != b_attrs->modtime.tv_sec)
		 || (a_attrs->modtime.tv_nsec
		     != b_attrs->modtime.tv_nsec))) {
     queue_copy_op (ctx, parent, a_attrs, pdir_entry);
  } else {
    if (a_attrs->is_hard_link)
      got_hard_link_target (ctx, a_attrs, b_attrs->file_id, NULL);

    if (!meta_equal (&a_attrs->ca, &b_attrs->ca, ctx->ignore_owners))
      queue_op (ctx, OP_COPY_META, parent, a_attrs, pdir_entry);
    else
      return true;
  }

  return false;
}

static void compare_dirs (struct sync_ctx *ctx, struct sync_attrs *attrs,
			  struct dir *src_dir, struct dir *dst_dir)
{
  lock (ctx);

  unsigned a = 0, b = 0;
  int (*cmp_fn)(const char *a, const char *b)
    = ctx->case_sensitive ? strcmp : case_insens_cmp;

  for (;;) {
    struct sync_attrs *a_attrs = dir_e (src_dir, a);
    struct sync_attrs *b_attrs = dir_e (dst_dir, b);
    int cmp;
    
    if (!a_attrs) {
      if (!b_attrs)
	break;
      cmp = 1;
    } else if (!b_attrs)
      cmp = -1;
    else
      cmp = cmp_fn (attrs_name (a_attrs), attrs_name (b_attrs));

    if (cmp < 0) {
      queue_copy_op (ctx, attrs, a_attrs, &src_dir->attrs[a]);
      ++a;
    } else if (cmp > 0) {
      queue_op (ctx, OP_REMOVE, attrs, b_attrs, &dst_dir->attrs[b]);
      ++b;
    } else {
      if (compare_matching (ctx, attrs, a_attrs, b_attrs, 
			    &src_dir->attrs[a])) {
	ctx->progress.done += OBJ_PROGRESS_FACTOR;
	uint64_t prog = progress_for_file (ctx, a_attrs);
	update_actual_data (ctx, prog);
	ctx->progress.done += prog;
      }
      ++a;
      ++b;
    }
  }

  unlock (ctx);
}

static int report_progress (struct sync_ctx *ctx)
{
  assert_locked (ctx);

  // We preserve the total in case it gets adjusted later
  uint64_t old_total = ctx->progress.total;

  if (ctx->progress.done > ctx->progress.total)
    ctx->progress.total = ctx->progress.done;

  int ret = 0;

  if (ctx->opts && ctx->opts->progress_fn
      && ctx->opts->progress_fn (&ctx->progress)) {
    ctx->aborted = true;
    ret = -1;
  }

  ctx->progress.total = old_total;

  return ret;
}

static struct sync_attrs *next_child_dir (struct sync_ctx *ctx,
					  struct sync_attrs *parent,
					  unsigned *ndx)
{
  assert_locked (ctx);

  while (*ndx < parent->dir->count) {
    struct sync_attrs *child = dir_e (parent->dir, *ndx);
    if (attrs_is_dir (child)) {
      hard_link_handler_ret_t ret
	= copy_hard_link_handler_unlocked (ctx, child, NULL);

      if (ret == HARD_LINK_COPY_TARGET)
	return child;
    }
    ++*ndx;
  }

  return NULL;
}

static int scan_tree (struct sync_ctx *ctx, 
		      void **pattrs_buf,
		      struct sync_attrs *dir_attrs,
		      struct sync_attrs **pnext_attrs)
{
  int ret = -1;

  struct {
    struct sync_attrs *dir;
    unsigned ndx;
  } stack[1024];
  unsigned stack_ndx = 0;
  struct dir *dir;

  while (!ctx->aborted) {
    if (!(dir = dir_attrs->dir)) {
      char path_buf[PATH_MAX];
      char *path = attrs_path (path_buf, dir_attrs, ctx->src, NULL);
      if (!path)
	LEAVE ();

      dir = scan_dir (ctx, pattrs_buf, dir_attrs, path, 
		      pnext_attrs, &ctx->src_devid, true);
      if (!dir) {
	if (errno == EXDEV || errno == EACCES || errno == EPERM) {
	  /* This means we've encountered a mount point---we assume the
	     folder is empty. */
	  dir = malloc (sizeof (struct dir));
	  dir->count = 0;
	} else 
	  LEAVEP (path);
      }

      ctx->src_entry_count += dir->count;      

      // Sort out the pointers to the parent
      lock (ctx);
      for (unsigned i = 0; i < dir->count; ++i) {
	struct sync_attrs *child = dir_e (dir, i);
	if (attrs_is_dir (child))
	  child->parent = &dir_attrs->ca;
	handle_src_hard_link (ctx, dir_attrs, child, NULL);
      }
      dir_attrs->dir = dir;
      unlock (ctx);
    }

    lock (ctx);

    /* Update our progress total with the amount of data we will need
       to copy. */
    uint64_t data = 0;
    for (unsigned i = 0; i < dir->count; ++i) {
      struct sync_attrs *child = dir_e (dir, i);
      data += progress_for_file (ctx, child);
    }

    update_actual_data (ctx, data);

    unsigned i = 0;
    struct sync_attrs *child = next_child_dir (ctx, dir_attrs, &i);

    if (!child) {
      // Pop one off the stack
      if (!stack_ndx) {
	unlock (ctx);
	break;
      } else {
	--stack_ndx;
	dir_attrs = stack[stack_ndx].dir;
	i = stack[stack_ndx].ndx;
	dir = dir_attrs->dir;
	child = dir_e (dir, i);
      }
    }

    child->parent = &dir_attrs->ca;
    struct sync_attrs *next = child;

    ++i;
    // Figure out the next child dir and push it onto the stack if we find one
    if (next_child_dir (ctx, dir_attrs, &i)) {
      assert (stack_ndx < 1024);
      stack[stack_ndx].dir = dir_attrs;
      stack[stack_ndx].ndx = i;
      ++stack_ndx;
    }

    unlock (ctx);

    dir_attrs = next;
  }

  ret = 0;

LEAVE:

  return ret;
}

static void *
src_reader_thread (void *param)
{
  int err = -1;
  struct sync_ctx *ctx = param;
  unsigned max_sub_dirs = 1024;
  unsigned sub_dir_count = 0;
  struct sync_attrs *parent = &ctx->root;
  struct sync_attrs **sub_dirs = malloc (max_sub_dirs * sizeof (void *));
  const char *path = ctx->src;
  char path_buf[PATH_MAX];
  struct sync_attrs *next_attrs = NULL;
  unsigned dir_count = 0;
  void *attrs_buf = NULL;

  for (;;) {
    if (ctx->aborted) {
      err = 0;
      goto LEAVE;
    }

    ++dir_count;

    struct dir *dir = scan_dir (ctx, &attrs_buf, parent, path, &next_attrs, 
				&ctx->src_devid, true);

    if (!dir) {
      if (errno == EXDEV || errno == EACCES || errno == EPERM) {
	/* This means we've encountered a mount point or something that
	   we cannot scan, so we just ignore it.  Any files in this folder
	   on the target will be left. */
	lock (ctx);
	parent->dir = malloc (sizeof (struct dir));
	parent->dir->count = 0;
	release_attrs (ctx, parent);
	goto TRY_NEXT;
      }

      LEAVE ();
    }

    // Look for sub directories
    lock (ctx);

    parent = hard_link_master (ctx, parent);
    assert (!parent->dir);

    for (unsigned i = 0; i < dir->count; ++i) {
      struct sync_attrs *attrs = dir_e (dir, i);
      uint32_t ndx;

      if (!handle_src_hard_link (ctx, parent, attrs, &ndx))
	ndx = 0;

      if (!attrs_is_dir (attrs))
	continue;

      attrs->parent = &parent->ca;

      if (ndx)
	continue;

      if (sub_dir_count == max_sub_dirs) {
	sub_dirs = realloc (sub_dirs, 
			    (max_sub_dirs += 1024) * sizeof (void *));
      }
      retain_attrs (ctx, attrs);
      sub_dirs[sub_dir_count] = attrs;
      fix_sub_dir_heap_up (sub_dirs, sub_dir_count++);
    }
    parent->dir = dir;

    q_push (ctx, &ctx->scannedq, parent);
    parent = NULL;

    ctx->src_entry_count += dir->count;

  TRY_NEXT:;

    /* If there are no more sub directories, tell dst_reader_thread that
       we've finished. */
    if (!sub_dir_count) {
      fprintf (stderr, "Scanned %u records (expected: %u)\n",
	       ctx->src_entry_count, ctx->expected_entry_count);

      // Adjust the total to represent what we actually processed
      ctx->progress.total += (((int64_t)ctx->src_entry_count
			       - ctx->expected_entry_count)
			      * OBJ_PROGRESS_FACTOR);

      q_close (ctx, &ctx->scannedq);
    }

    // Check copydirq
    while (q_pop (ctx, &ctx->copydirq, !sub_dir_count, &parent)) {
      unlock (ctx);

      if (scan_tree (ctx, &attrs_buf, parent, &next_attrs))
	LEAVE ();

      lock (ctx);

      /* We've scanned this entire tree so we can pass this directory over to
         the copy thread. */
      queue_op (ctx, OP_COPY, parent, NULL, NULL);
      release_attrs (ctx, parent);
    }

    if (!sub_dir_count) {
      // We've finished
      unlock (ctx);
      parent = NULL;
      err = 0;
      goto LEAVE;
    }

    // Look at the next sub-dir for us to check
    for (;;) {
      parent = sub_dirs[0];

      // Remove the entry from sub_dirs
      sub_dirs[0] = sub_dirs[--sub_dir_count];
      fix_sub_dir_heap_down (sub_dirs, 0, sub_dir_count);

      assert (parent->name.attr_length && parent->ref_count);

      parent = hard_link_master (ctx, parent);

      // We might have scanned this dir in scan_tree above
      if (!parent->dir)
	break;

      release_attrs (ctx, parent);

      if (!sub_dir_count)
	goto TRY_NEXT;
    }

    path = attrs_path (path_buf, parent, ctx->src, NULL);

    unlock (ctx);
  } // for (;;)

LEAVE:
  
  if (err == -1)
    err = errno;
  
  free (attrs_buf);
  
  lock (ctx);

  release_attrs (ctx, parent);

  if (next_attrs) {
    attrs_page (next_attrs)->page_in_use = false;
    collect_page (ctx, next_attrs);
  }

  q_close (ctx, &ctx->scannedq);
  q_close (ctx, &ctx->opq);

  for (unsigned i = 0; i < sub_dir_count; ++i)
    release_attrs (ctx, sub_dirs[i]);
  free (sub_dirs);

  unlock (ctx);

  return (void *)(uintptr_t)err;
}

void *dst_reader_thread (void *param)
{
  int err = -1;
  struct sync_ctx *ctx = param;
  
  char path_buf[1024];
  struct sync_attrs *next_attrs = NULL;
  dev_t devid;
  void *attrs_buf = NULL;

  while (!ctx->aborted) {
    struct sync_attrs *src_dir;

    lock (ctx);

    if (!q_pop (ctx, &ctx->scannedq, true, &src_dir)) {
      finish_hard_links (ctx);
      unlock (ctx);
      break;
    }

    if (src_dir->will_copy
	|| (src_dir->parent
	    && sync_attrs_from_copy_attrs (src_dir->parent)->will_copy)) {
      src_dir->will_copy = true;
      release_attrs (ctx, src_dir);
      unlock (ctx);
      continue;
    }

    char *path = attrs_path (path_buf, src_dir, ctx->dst, NULL);

    unlock (ctx);

    struct dir *dst_dir = scan_dir (ctx, &attrs_buf, src_dir,
				    path, &next_attrs, &devid, false);

    if (!dst_dir) {
      int err = errno;
      lock (ctx);
      release_attrs (ctx, src_dir);
      unlock (ctx);

      if (errno == EACCES) {
	fprintf (stderr, "warning: %s: %s\n", path, strerror (errno));
	continue;
      }

      errno = err;
      LEAVEP (path);
    }

    compare_dirs (ctx, src_dir, src_dir->dir, dst_dir);

    lock (ctx);
    release_attrs (ctx, src_dir);
    free_dir (ctx, NULL, dst_dir);

    if (report_progress (ctx)) {
      unlock (ctx);
      LEAVE ();
    }

    unlock (ctx);
  }

  fprintf (stderr, "Finished scanning destination (data: %llu bytes, "
	   "expected %llu)\n", ctx->actual_data, ctx->expected_data);

  if (ctx->actual_data < ctx->expected_data) {
    lock (ctx);
    ctx->progress.total -= ctx->expected_data - ctx->actual_data;
    unlock (ctx);
  }

  err = 0;

LEAVE:

  if (err == -1)
    err = errno;

  free (attrs_buf);

  lock (ctx);

  if (next_attrs) {
    attrs_page (next_attrs)->page_in_use = false;
    collect_page (ctx, next_attrs);
  }

  q_close (ctx, &ctx->copydirq);

  unlock (ctx);

  return (void *)(uintptr_t)err;
}

static void release_op_entry (struct sync_ctx *ctx, struct op_entry *entry)
{
  assert_locked (ctx);

  release_attrs (ctx, entry->dir);
  release_attrs (ctx, entry->file);

  entry->dir = entry->file = NULL;
}

static int copy_op_progress (copy_progress_t *progress)
{
  struct sync_ctx *ctx = progress->ctx;

  lock (ctx);

  if (progress->state == ST_FINISHED_OP) {
    struct sync_attrs *attrs = sync_attrs_from_copy_attrs (progress->attrs);

    ctx->progress.done += OBJ_PROGRESS_FACTOR;
    if (progress->attrs->flags & UF_COMPRESSED)
      ctx->progress.done += progress_for_file (ctx, attrs);

    if (attrs->is_hard_link
	&& got_hard_link_target (ctx, attrs, 0, progress->dst_path)) {
      unlock (ctx);
      return -1;
    }
  } else
    ctx->progress.done += progress->done;

  int ret = report_progress (ctx);

  unlock (ctx);

  return ret;
}

static int copy_op (struct sync_ctx *ctx, struct op_entry *entry, void *buf, size_t buf_size)
{
  int ret = -1;
  struct copy_options opts = {
    .recursive = true,
    .meta_only = entry->op == OP_COPY_META,
    .progress_fn = copy_op_progress,
    .ctx = ctx,
    .hard_link_handler_fn = copy_hard_link_handler,
#if SKIP_DATA
    .skip_data = true,
#endif
  };

  char *src_path_buf = malloc (PATH_MAX);
  char *dst_path_buf = malloc (PATH_MAX);

  char *src_path = attrs_path (src_path_buf, entry->dir, 
			       ctx->src, attrs_name (entry->file));
  if (!src_path)
    LEAVE ();

  char *dst_path = attrs_path (dst_path_buf, entry->dir,
			       ctx->dst, attrs_name (entry->file));
  if (!dst_path)
    LEAVE ();

  copy_attrs_t *a = entry->file ? &entry->file->ca : &entry->dir->ca;

  if (copy_object (src_path, dst_path, &opts, a, buf, buf_size)) {
    if (errno == EACCES)
      goto LEAVE;
    LEAVEP (src_path);
  }

  ret = 0;

LEAVE:;
  int err = errno;

  free (src_path_buf);
  free (dst_path_buf);

  lock (ctx);
  release_op_entry (ctx, entry);
  unlock (ctx);

  errno = err;

  return ret;
}

static int remove_op (struct sync_ctx *ctx, struct op_entry *entry)
{
  int ret = -1;
  char *path_buf = malloc (PATH_MAX);
  
  lock (ctx);
  char *path = attrs_path (path_buf, entry->dir,
			   ctx->dst, attrs_name (entry->file));
  int err = errno;

  release_op_entry (ctx, entry);
  unlock (ctx);

  if (!path) {
    errno = err;
    LEAVE ();
  }

  if (rm_object (path))
    LEAVEP (path);

  ret = 0;

LEAVE:;
  err = errno;

  free (path_buf);

  errno = err;
  return ret;
}

static void *
copy_thread (void *param)
{
  int err = -1;
  struct sync_ctx *ctx = param;
  struct op_entry entry;
  unsigned logged_entries = 0;
  
  size_t buf_size = 16 * 1024 * 1024;
  void *buf = malloc(buf_size);
  if (!buf)
    buf_size = 0; // although we're unlikely to get much further

  while (!ctx->aborted) {
    lock (ctx);
    if (!q_pop (ctx, &ctx->opq, true, &entry)) {
      unlock (ctx);
      break;
    }

    int res = 0;

    if (logged_entries < 200) {
      const char *file_name = attrs_name (entry.file);
      assert (!file_name || file_name[0]);
      
      char path_buf[PATH_MAX];
      char *path = attrs_path (path_buf, entry.dir,
			       NULL, file_name);
      static char *ops[] = { [OP_COPY] = "COPY", [OP_REMOVE] = "REMOVE",
	[OP_COPY_META] = "COPY_META" };
      fprintf (stderr, "%s %s\n", ops[entry.op], path);
      ++logged_entries;
    } else if (logged_entries == 200) {
      fprintf (stderr, "More operations follow (silenced)\n");
      ++logged_entries;
    }

    unlock (ctx);

    switch (entry.op) {
      case OP_COPY_META: 
      case OP_COPY:
	res = copy_op (ctx, &entry, buf, buf_size);
	break;
      case OP_REMOVE:
	res = remove_op (ctx, &entry);
	break;
    }

    lock (ctx);
    release_op_entry (ctx, &entry);
    unlock (ctx);

    // It's possible to get ENOENT errors because of other activity going on
    if (res) {
      if (errno != EPERM && errno != EACCES && errno != ENOENT)
	LEAVE ();
      /* NOTE: We don't bother fixing up the progress as we shouldn't be here
         for very many files. */
    }
  } // for (;;)

DONE:

  err = 0;

LEAVE:
  
  if (buf_size)
    free(buf);
  
  if (err == -1)
    err = errno;

  return (void *)(uintptr_t)err;
}

int sync_objects (const char *src, const char *dst, sync_options_t *opts)
{
  int err = -1;
  
  fprintf (stderr, "SYNC %s %s\n", src, dst);

  struct sync_ctx ctx = {
    .src = src,
    .dst = dst,
    .root = {
      .accessmask = S_IFDIR,
      .ref_count = 1,
    },
    .opq = {
      .width = sizeof (struct op_entry),
    },
    .mutex = PTHREAD_MUTEX_INITIALIZER,
    .cond = PTHREAD_COND_INITIALIZER,  
    .opts = opts,
    .progress = {
      .ctx = opts ? opts->ctx : NULL,
    },
    .ignore_owners = geteuid () ? true : false
  };

  // Get the number of filesystem objects
  struct attrlist attrlist = {
    .bitmapcount = ATTR_BIT_MAP_COUNT,
    .volattr = (ATTR_VOL_INFO | ATTR_VOL_SIZE | ATTR_VOL_SPACEFREE
		| ATTR_VOL_OBJCOUNT | ATTR_VOL_MOUNTFLAGS),
  };
  
#pragma pack (push, 4)
  struct {
    uint32_t len;
    off_t size, space_free;
    uint32_t objcount;
    uint32_t mount_flags;
  } vol;
#pragma pack (pop)

  /* NOTE: Using mount directly isn't really supported (you're supposed
     to use /sbin/mount), but this is easier and will do for now. */
  struct hfs_mount_args	mount_args = {
    .flags = VNOVAL,
    .hfs_uid = (uid_t)VNOVAL,
    .hfs_gid = (gid_t)VNOVAL,
    .hfs_mask = (mode_t)VNOVAL,
    .hfs_encoding = (uint32_t)VNOVAL,
  };

  if (getattrlist (src, &attrlist, &vol, sizeof (vol), 0))
    vol.objcount = 0;
  else {
    if (vol.mount_flags & MNT_IGNORE_OWNERSHIP) {
      vol.mount_flags &= ~MNT_IGNORE_OWNERSHIP;
      if (mount ("hfs", src, vol.mount_flags | MNT_UPDATE, &mount_args)) {
	fprintf (stderr, "warning: unable to enable owners on source: %s\n",
		 strerror (errno));
	ctx.ignore_owners = true;
      }
    }

    /* Update the progress info. Start by assuming that we'll have to
       copy everything (which we estimate from the used space on the
       volume). */
    fprintf (stderr, "Source used: %llu bytes\n", vol.size - vol.space_free);
    ctx.expected_data = vol.size - vol.space_free;

    /* This calculation is based on emperical evidence and may need to be
       updated as we collect more data.  The objective is to get the
       estimate of the amount of data as close as possible to the actual
       amount of data. */

#define GB * 1024ull * 1024 * 1024
    if (ctx.expected_data < 200 GB)
      ctx.expected_data = ctx.expected_data * 86 / 100;
    else
      ctx.expected_data = ctx.expected_data * 95 / 100;

    ctx.progress.total += ctx.expected_data;

    /* Emperical tests have shown that the we only scan about 95% of the
       objects. */
    ctx.expected_entry_count = vol.objcount * 19ull / 20;
    ctx.progress.total += ctx.expected_entry_count * OBJ_PROGRESS_FACTOR;
  }

#pragma pack (push, 4)
  struct {
    uint32_t len;
    uint32_t mount_flags;
    vol_capabilities_attr_t vol_cap;
  } dst_vol;
#pragma pack (pop)

  attrlist.volattr = (ATTR_VOL_INFO | ATTR_VOL_MOUNTFLAGS 
		      | ATTR_VOL_CAPABILITIES);
  if (!getattrlist (dst, &attrlist, &dst_vol, sizeof (dst_vol), 0)) {
    if (dst_vol.mount_flags & MNT_IGNORE_OWNERSHIP) {
      dst_vol.mount_flags &= ~MNT_IGNORE_OWNERSHIP;
      if (mount ("hfs", dst, dst_vol.mount_flags | MNT_UPDATE, &mount_args)) {
	fprintf (stderr, "warning: unable to enable owners on target: %s\n",
		 strerror (errno));
	ctx.ignore_owners = true;
      }
    }

    if (dst_vol.vol_cap.capabilities[VOL_CAPABILITIES_FORMAT] 
	& VOL_CAP_FMT_CASE_SENSITIVE) {
      ctx.case_sensitive = true;
    }
  }

  pthread_t src_reader_thr, dst_reader_thr;
  pthread_create (&src_reader_thr, NULL, src_reader_thread, &ctx);
  pthread_create (&dst_reader_thr, NULL, dst_reader_thread, &ctx);

  err = (int)(uintptr_t)copy_thread (&ctx);

LEAVE:;
  
  ctx.aborted = true;
  
  int e = (int)(uintptr_t)pthread_join (src_reader_thr, NULL);
  if (!err)
    err = e;

  e = (int)(uintptr_t)pthread_join (dst_reader_thr, NULL);
  if (!err)
    err = e;

  // Drain queues
  lock (&ctx);
  struct sync_attrs *attrs;
  while (q_pop (&ctx, &ctx.scannedq, false, &attrs)) {
    assert (err);
    release_attrs (&ctx, attrs);
  }
  struct op_entry op_entry;
  while (q_pop (&ctx, &ctx.opq, false, &op_entry)) {
    assert (err);
    release_op_entry (&ctx, &op_entry);
  }
  while (q_pop (&ctx, &ctx.copydirq, false, &attrs)) {
    assert (err);
    release_attrs (&ctx, attrs);
  }
  destroy_hard_links (&ctx);  
  unlock (&ctx);

  free (ctx.scannedq.buf);
  free (ctx.opq.buf);
  free (ctx.copydirq.buf);

  if (allocated_pages) {
    fprintf (stderr, "Leaked %u pages!\n", allocated_pages);
    struct page *page = ctx.first_page;
    while (page) {
      dump_page (page);
      struct page *next_page = page_next (page);
      free (page);
      page = next_page;
    }
  }

  while (ctx.free_pages) {
    struct page *next_page = ctx.free_pages->next;
    free (ctx.free_pages);
    ctx.free_pages = next_page;
  }

  fprintf (stderr, "Sync done %llu/%llu\n", 
	   ctx.progress.done, ctx.progress.total);

  errno = err;
  return err ? -1 : 0;
}
