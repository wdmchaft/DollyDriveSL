//
//  copy.c
//  CloneVolume
//
//  Created by Pumptheory P/L on 18/03/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

/* NOTE: This code is designed to work when running as root; there are
   scenarios that won't work (but could be made to work) when not running
   as root---see tests. */

#include <sys/stat.h>
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
#include <pthread.h>
#include <stdlib.h>
#include <libkern/OSAtomic.h>
#include <libgen.h>

#include "copy.h"
#include "utils.h"

static int copy_xattrs (int src_fd, int dst_fd, bool compressed);
static int copy_acl (int src_fd, int dst_fd, const char *dst_path);
static int copy_file (const char *src, const char *dst,
		      copy_options_t *opts, copy_attrs_t *attrs, void *buf, size_t buf_size);
static int copy_dir (const char *src, const char *dst,
		     copy_options_t *opts, copy_attrs_t *attrs, void *buf, size_t buf_size);
int rm_object (const char *path);
static int copy_set_attrs (int fd, copy_attrs_t *attrs, 
			   bool include_finder_info);
static int copy_lnk (const char *src, const char *dst,
		     copy_options_t *opts, copy_attrs_t *attrs);
static int copy_dev (const char *src, const char *dst,
		     copy_options_t *opts, copy_attrs_t *attrs);
static int copy_fifo (const char *src, const char *dst,
		      copy_options_t *opts, copy_attrs_t *attrs);

static uint32_t unlock_fd (int fd)
{
  /* We're called in error scenarios so make things easier by
     preserving errno. */
  uint32_t ret = 0;
  int err = errno;
  
  struct attrlist attrlist = {
    .bitmapcount = ATTR_BIT_MAP_COUNT,
    .commonattr = ATTR_CMN_FLAGS,
  };
  
  struct {
    uint32_t len;
    uint32_t flags;
  } attrs;
  
  if (fgetattrlist (fd, &attrlist, &attrs, sizeof (attrs), 0))
    LEAVE ();

  enum {
    FLAG_MASK = UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND
  };

  if (attrs.flags & FLAG_MASK) {
    if (fchflags (fd, (attrs.flags & ~FLAG_MASK)))
      LEAVE ();
    ret = attrs.flags;
  }
  
LEAVE:
  
  errno = err;
  return ret;  
}

static uint32_t unlock_file (const char *path)
{
  /* We're called in error scenarios so make things easier by
     preserving errno. */
  uint32_t ret = 0;
  int err = errno;
  int fd = -1;

  fd = open (path, O_RDONLY);
  if (fd < 0)
    LEAVE ();

  ret = unlock_fd (fd);

LEAVE:

  if (fd >= 0)
    close (fd);

  errno = err;
  return ret;
}

static uint32_t unlock_parent (const char *dst)
{
  /* We're called in error scenarios so make things easier by
     preserving errno. */
  int err = errno;
  uint32_t ret = 0;
  char *copy = strdup (dst);
  char *parent;

  if (!(parent = dirname (copy)))
    LEAVE ();

  ret = unlock_file (parent);

LEAVE:

  free (copy);

  errno = err;
  return ret;
}

static void lock_parent (const char *dst, uint32_t flags)
{
  char *copy = strdup (dst);
  char *parent;

  if (!(parent = dirname (copy)))
    LEAVE ();

  if (chflags (parent, flags))
    LEAVE ();

LEAVE:
  free (copy);
}

static int copy_data (int src, int dst, void *buf, size_t buf_size,
		      uint64_t expected_size, copy_options_t *opts)
{
  int ret = -1;
  uint64_t done = 0;
  copy_progress_t prog = {
    .ctx = opts ? opts->ctx : NULL,
    .state = ST_COPIED_DATA,
  };

  if (expected_size) {
    fstore_t fs = {
      .fst_flags = F_ALLOCATECONTIG,
      .fst_posmode = F_PEOFPOSMODE,
      .fst_offset = 0,
      .fst_length = expected_size,
    };

    if (fcntl (dst, F_PREALLOCATE, &fs))
      fprintf (stderr, "warning: preallocate failed: %s\n", strerror (errno));
  }

  fcntl (src, F_NOCACHE, 1);
  fcntl (dst, F_NOCACHE, 1);
  
#if DEBUG
  if (opts && opts->skip_data) {
    fcntl (dst, F_SETSIZE, &expected_size);
    return 0;
  }
#endif

  for (;;) {			     
    ssize_t read = pread (src, buf, buf_size, done);		   
    if (read < 0) {
      if (errno == EINTR)
	continue;
      LEAVE ();
    }

    if (!read)
      break;

    prog.done = read;

    void *p = buf;			     
    do {
      ssize_t written = pwrite (dst, p, read, done);
      if (written < 0) {
	if (errno == EINTR)		     
	  continue;
	LEAVE ();
      }
      done += written;
      p += written;
      read -= written;
    } while (read);

    if (opts && opts->progress_fn && opts->progress_fn (&prog))
      LEAVE ();      
  }

  ret = 0;

LEAVE:

  return ret;
}

int make_link (const char *target, const char *dst)
{
  int ret = -1;
  uint32_t parent_flags = 0;
  
  if (rm_object (dst))
    LEAVEP (dst);

  if (link (target, dst)
      && (errno != EPERM
	  || (parent_flags = unlock_parent (dst))
	  || link (target, dst)))
    LEAVEP (dst);
  
  ret = 0;

LEAVE:

  if (parent_flags)
    lock_parent (dst, parent_flags);

  return ret;
}

int copy_object (const char *src, const char *dst, copy_options_t *opts,
		 copy_attrs_t *attrs, void *buf, size_t buf_size)
{
  int ret = -1;

#pragma pack(push, 4)
  struct {
    uint32_t len;
    copy_attrs_t ca;
  } our_attrs;
#pragma pack(pop)

  if (!attrs) {
    attrs = &our_attrs.ca;
    struct attrlist attrlist = copy_attrs_list ();
    if (getattrlist (src, &attrlist, &our_attrs,
		     sizeof (our_attrs), FSOPT_NOFOLLOW))
      return -1;
    /* We don't bother checking the length because it varies depending upon
       the object type. */
    if (S_ISDIR (attrs->accessmask)) {
      attrs->ref_count = UINT32_MAX;
      attrs->parent = NULL;
      attrs->dir = NULL;
    }
  }

  if (opts && opts->progress_fn) {
    copy_progress_t prog = {
      .state = ST_STARTING_OP,
      .ctx = opts->ctx,
      .attrs = attrs,
      .dst_path = dst,
    };
    if (opts->progress_fn (&prog))
      return -1;
  }

  if (opts && opts->hard_link_handler_fn && !opts->meta_only) {
    char *target_path;
    hard_link_handler_ret_t hret
      = opts->hard_link_handler_fn (opts->ctx, attrs, &target_path);

    switch (hret) {
    case HARD_LINK_IGNORE:
      return 0;
    case HARD_LINK_MAKE_LINK:
      if (make_link (target_path, dst)) {
	int err = errno;
	free (target_path);
	errno = err;
	LEAVE ();
      } else {
	free (target_path);
	ret = 0;
	goto DONE;
      }
    case HARD_LINK_COPY_TARGET:
      // Fall through to code below
      break;
    }
  }

  switch (attrs->accessmask & S_IFMT) {
  case S_IFREG:
    ret = copy_file (src, dst, opts, attrs, buf, buf_size);
    break;
  case S_IFDIR:
    ret = copy_dir (src, dst, opts, attrs, NULL, 0);
    break;
  case S_IFIFO:
    ret = copy_fifo (src, dst, opts, attrs);
    break;
  case S_IFSOCK:
    // Just make sure the target doesn't exist
    ret = rm_object (dst);
    break;
  case S_IFLNK:
    ret = copy_lnk (src, dst, opts, attrs);  
    break;
  case S_IFCHR:
  case S_IFBLK:
    ret = copy_dev (src, dst, opts, attrs);
    break;
  default:
    fprintf (stderr, "Unsupported object type %o\n",
	     attrs->accessmask & S_IFMT);
    errno = ENOTSUP;
    ret = -1;  
  }

DONE:

  if (!ret && opts && opts->progress_fn) {
    copy_progress_t prog = {
      .state = ST_FINISHED_OP,
      .ctx = opts->ctx,
      .attrs = attrs,
      .dst_path = dst,
    };
    if (opts->progress_fn (&prog))
      return -1;
  }

LEAVE:

  return ret;
}

static int copy_open (const char *path, int oflag, 
		      mode_t mode, uint32_t *parent_flags)
{
  int fd = open (path, oflag, mode);

  if (fd >= 0 || errno != EPERM)
    return fd;

  // We might need to unlock the parent
  if ((*parent_flags = unlock_parent (path))
      && (fd = open (path, oflag, mode)) >= 0)
    return fd;

  // Try unlocking the file
  if (unlock_file (path))
    fd = open (path, oflag, mode);

  return fd;
}

static int copy_file (const char *src, const char *dst,
		      copy_options_t *opts, copy_attrs_t *attrs, void *buf, size_t buf_size)
{
  int ret = -1;
  int src_fd = -1, dst_fd = -1, rsrc_src_fd = -1, rsrc_dst_fd = -1;
  bool meta_only = opts && opts->meta_only;
  uint32_t parent_flags = 0;
  bool free_buf = false;

  // Open the source
  src_fd = open (src, O_RDONLY | O_NOFOLLOW | O_NONBLOCK);
  if (src_fd < 0)
    LEAVEP (src);

  // Create the file, but always unlink first to avoid permissions problems
  if (!meta_only && rm_object (dst))
    LEAVEP (dst);

  int oflag = meta_only ? O_RDONLY : O_EXCL | O_CREAT | O_RDWR;
  dst_fd = copy_open (dst, oflag, 0600, &parent_flags);
  if (dst_fd < 0)
    LEAVEP (dst);

  bool compressed = attrs->flags & UF_COMPRESSED;

  if (!meta_only) {
    if (!buf)
    {
      buf_size = 16 * 1024 * 1024;
      buf = malloc (buf_size);
      if (buf)
        free_buf = true;
      else
        LEAVE();
    }

    if (!compressed
	&& copy_data (src_fd, dst_fd, buf, buf_size, attrs->datalength, opts))
      LEAVE ();

    // Copy resource fork
    if (attrs->rsrclength) {
      static char rsrc_suffix[] = _PATH_RSRCFORKSPEC;

      size_t l = strlen (src);
      char *rsrc_fork_path = malloc (l + sizeof (rsrc_suffix));
      memcpy (rsrc_fork_path, src, l);
      memcpy (rsrc_fork_path + l, rsrc_suffix, sizeof (rsrc_suffix));

      rsrc_src_fd = open (rsrc_fork_path, O_RDONLY);
      free (rsrc_fork_path);

      if (rsrc_src_fd < 0)
	LEAVE ();

      l = strlen (dst);
      rsrc_fork_path = malloc (l + sizeof (rsrc_suffix));
      memcpy (rsrc_fork_path, dst, l);
      memcpy (rsrc_fork_path + l, rsrc_suffix, sizeof (rsrc_suffix));

      rsrc_dst_fd = open (rsrc_fork_path, O_RDWR);
      free (rsrc_fork_path);

      if (rsrc_dst_fd < 0)
	LEAVE ();

      if (copy_data (rsrc_src_fd, rsrc_dst_fd, buf, buf_size, 
		     attrs->rsrclength, opts))
	LEAVE ();
    }
  }

  if (copy_xattrs (src_fd, dst_fd, compressed && !meta_only)
      || copy_acl (src_fd, dst_fd, meta_only ? dst : NULL)
      || copy_set_attrs (dst_fd, attrs, true))
    LEAVE ();

  ret = 0;

LEAVE:;
  
  int err = errno;

  if (free_buf)
    free (buf);
  if (src_fd >= 0)
    close (src_fd);
  if (dst_fd >= 0)
    close (dst_fd);
  if (rsrc_src_fd >= 0)
    close (rsrc_src_fd);
  if (rsrc_dst_fd >= 0)
    close (rsrc_dst_fd);

  if (parent_flags)
    lock_parent (dst, parent_flags);
  
  errno = err;

  return ret;
}

static bool should_skip_dirs (struct dirent *dirent)
{
  return ((dirent->d_namlen == 1
	  && dirent->d_name[0] == '.')
	  || (dirent->d_namlen == 2
	      && dirent->d_name[0] == '.'
	      && dirent->d_name[1] == '.'));
}

/* We use getattrlist rather than stat because stat will cause network
   activity (and is therefore slow) on some mounts whereas this won't. */
int get_devid (int fd, dev_t *pdevid)
{
  int ret = -1;

  struct attrlist attrlist = {
    .bitmapcount = ATTR_BIT_MAP_COUNT,
    .commonattr = ATTR_CMN_DEVID,
  };
#pragma pack(push, 4)
  struct {
    uint32_t len;
    dev_t devid;
    uint32_t entry_count;
  } attrs;
#pragma pack(pop)

  if (fgetattrlist (fd, &attrlist, &attrs, sizeof (attrs), 0))
    LEAVE ();

  *pdevid = attrs.devid;
  ret = 0;

LEAVE:

  return ret;
}

static int copy_dir (const char *src, const char *dst,
		     copy_options_t *opts, copy_attrs_t *attrs, void *buf, size_t buf_size)
{
  int ret = -1;
  int src_fd = -1, dst_fd = -1;
  DIR *dir = opendir (src);
  bool meta_only = opts && opts->meta_only;
  uint32_t parent_flags = 0;
  void *attrs_buf = NULL;

  if (!dir)
    LEAVEP (src);

  // Delete the target
  if (!meta_only && rm_object (dst))
    LEAVEP (dst);

  size_t src_len = strlen (src), dst_len = strlen (dst);
  if (src_len > PATH_MAX - 1 || dst_len > PATH_MAX - 1) {
    errno = ENAMETOOLONG;
    LEAVE ();
  }

  char src_file_path[PATH_MAX], dst_file_path[PATH_MAX];
  memcpy (src_file_path, src, src_len + 1);
  memcpy (dst_file_path, dst, dst_len + 1);

  if (!meta_only) {
    if (mkdir (dst_file_path, 0700)
	&& (errno != EPERM
	    || !(parent_flags = unlock_parent (dst))
	    || mkdir (dst_file_path, 0700))) {
      LEAVEP (dst_file_path);
    }
  }

  src_fd = open (src_file_path, O_RDONLY);
  if (src_fd < 0)
    LEAVEP (src_file_path);

  // Don't cross mount points
  bool xdev = false;
  if (opts && opts->devid && !attrs->dir) {
    dev_t devid;
    if (get_devid (src_fd, &devid))
      LEAVE ();
    xdev = devid != opts->devid;
  }

  if (!meta_only && opts && opts->recursive && !xdev) {
    src_file_path[src_len] = '/';
    dst_file_path[dst_len] = '/';

    if (attrs->dir) {
      for (unsigned i = 0; i < attrs->dir->count; ++i) {
	copy_attrsn_t *pattrs = attrs->dir->attrs[i];

	uint32_t name_len = pattrs->name.attr_length;
	const char *name = name_from_attrref (&pattrs->name);
	
	if (src_len + name_len > PATH_MAX - 1
	    || dst_len + name_len > PATH_MAX - 1) {
	  errno = ENAMETOOLONG;
	  LEAVE ();
	}

	memcpy (src_file_path + src_len + 1, name, name_len);
	memcpy (dst_file_path + dst_len + 1, name, name_len);

	if (copy_object (src_file_path, dst_file_path, opts, &pattrs->ca, buf, buf_size)) {
	  if (errno == ENOENT) {
	    fprintf (stderr, "warning: %s: %s, skipping\n",
		     src_file_path, strerror (ENOENT));
	  } else if (errno != EACCES && errno != EPERM)
	    LEAVE ();
	}
      }
    } else {
      // Get the devid to so that we don't cross devices
      if (!opts->devid && get_devid (src_fd, &opts->devid))
	LEAVE ();

      struct attrlist attrlist = copy_attrs_list ();
      attrlist.commonattr |= ATTR_CMN_NAME;

#pragma pack(push, 4)
      struct {
	uint32_t len;
	COPY_ATTRSN
      } *pattrs;
#pragma pack(pop)

      enum {
	MAX_ENTRIES = 64,
	BUF_SIZE = (sizeof (*pattrs) + 768) * MAX_ENTRIES,
      };
      
      attrs_buf = malloc (BUF_SIZE);

      for (;;) {
	unsigned int base, new_state, count = MAX_ENTRIES;
	int ret = getdirentriesattr (src_fd, &attrlist, attrs_buf,
				     BUF_SIZE, (void *)&count, 
				     (void *)&base, (void *)&new_state, 0);

	if (ret < 0) {
	  if (errno == EINTR)
	    continue;
	  LEAVE ();
	}

	pattrs = attrs_buf;
	for (unsigned i = 0; i < count; ++i) {
	  // Includes NUL terminator
	  uint32_t name_len = pattrs->name.attr_length;
	  const char *name = name_from_attrref (&pattrs->name);

	  if (src_len + name_len > PATH_MAX - 1
	      || dst_len + name_len > PATH_MAX - 1) {
	    errno = ENAMETOOLONG;
	    LEAVE ();
	  }

	  memcpy (src_file_path + src_len + 1, name, name_len);
	  memcpy (dst_file_path + dst_len + 1, name, name_len);

	  if (S_ISDIR (pattrs->accessmask)) {
	    pattrs->ref_count = UINT32_MAX;
	    pattrs->parent = NULL;
	    pattrs->dir = NULL;
	  }

	  if (copy_object (src_file_path, dst_file_path, opts, &pattrs->ca, buf, buf_size)) {
	    if (errno != EACCES && errno != EPERM)
	      LEAVE ();
	  }

	  pattrs = (void *)pattrs + pattrs->len;
	}

	if (ret == 1)
	  break;
      } // for (;;)
    }

    src_file_path[src_len] = 0;
    dst_file_path[dst_len] = 0;    
  }

  dst_fd = open (dst_file_path, O_RDONLY);
  if (dst_fd < 0)
    LEAVEP (dst_file_path);

  if (copy_xattrs (src_fd, dst_fd, false)
      || copy_acl (src_fd, dst_fd, dst_file_path)
      || copy_set_attrs (dst_fd, attrs, true))
    LEAVE ();

  ret = 0;

LEAVE:;
  
  int err = errno;

  free (attrs_buf);
  if (dir)
    closedir (dir);
  if (src_fd >= 0)
    close (src_fd);
  if (dst_fd >= 0)
    close (dst_fd);
  if (parent_flags)
    lock_parent (dst, parent_flags);

  errno = err;
  
  return ret;
}

static int copy_lnk (const char *src, const char *dst,
		     copy_options_t *opts, copy_attrs_t *attrs)
{
  int ret = -1;
  char link[PATH_MAX];
  int src_fd = -1, dst_fd = -1;
  uint32_t parent_flags = 0;

  ssize_t len = readlink (src, link, sizeof (link) - 1);

  if (len < 0)
    LEAVE ();

  link[len] = 0;

  // Delete the target
  if (rm_object (dst))
    LEAVEP (dst);

  if (symlink (link, dst)
      && (errno != EPERM
	  || !(parent_flags = unlock_parent (dst))
	  || symlink (link, dst))) {
    LEAVEP (dst);
  }

  src_fd = open (src, O_RDONLY | O_SYMLINK);
  if (src_fd < 0)
    LEAVE ();
  dst_fd = open (dst, O_RDWR | O_SYMLINK);
  if (dst_fd < 0)
    LEAVE ();

  if (copy_xattrs (src_fd, dst_fd, false)
      || copy_acl (src_fd, dst_fd, NULL)
      || copy_set_attrs (dst_fd, attrs, true))
    LEAVE ();

  ret = 0;

LEAVE:;
  int err = errno;

  if (src_fd >= 0)
    close (src_fd);
  if (dst_fd >= 0)
    close (dst_fd);

  if (parent_flags)
    lock_parent (dst, parent_flags);
  
  errno = err;

  return ret;
}

static int copy_dev (const char *src, const char *dst,
		     copy_options_t *opts, copy_attrs_t *attrs)
{
  int ret = -1;
  int src_fd = -1, dst_fd = -1;
  uint32_t parent_flags = 0;

  if (rm_object (dst))
    LEAVEP (dst);
  
  if (mknod (dst, 0600 | (attrs->accessmask & S_IFMT), attrs->devtype)
      && (errno != EPERM
	  || !(parent_flags = unlock_parent (dst))
	  || mknod (dst, 0600, attrs->devtype))) {
    LEAVEP (dst);
  }

  src_fd = open (src, O_RDONLY | O_SYMLINK);
  if (src_fd < 0)
    LEAVE ();

  dst_fd = open (dst, O_RDWR | O_SYMLINK);
  if (dst_fd < 0)
    LEAVE ();

  if (copy_acl (src_fd, dst_fd, NULL)
      || copy_set_attrs (dst_fd, attrs, false))
    LEAVE ();

  ret = 0;

LEAVE:;
  int err = errno;

  if (src_fd >= 0)
    close (src_fd);
  if (dst_fd >= 0)
    close (dst_fd);

  if (parent_flags)
    lock_parent (dst, parent_flags);

  errno = err;

  return ret;
}

static int copy_fifo (const char *src, const char *dst,
		      copy_options_t *opts, copy_attrs_t *attrs)
{
  int ret = -1;
  int src_fd = -1, dst_fd = -1;
  uint32_t parent_flags = 0;
  
  // Delete the target
  if (rm_object (dst))
    LEAVEP (dst);

  if (mkfifo (dst, 0600) 
      && (errno != EPERM
	  || !(parent_flags = unlock_parent (dst))
	  || mkfifo (dst, 0600))) {
    LEAVEP (dst);
  }

  src_fd = open (src, O_RDONLY | O_NONBLOCK);
  if (src_fd < 0)
    LEAVE ();
  dst_fd = open (dst, O_RDWR | O_NONBLOCK);
  if (dst_fd < 0)
    LEAVE ();

  if (copy_acl (src_fd, dst_fd, NULL)
      || copy_set_attrs (dst_fd, attrs, false))
    LEAVE ();

  ret = 0;

LEAVE:;
  int err = errno;

  if (src_fd >= 0)
    close (src_fd);
  if (dst_fd >= 0)
    close (dst_fd);

  if (parent_flags)
    lock_parent (dst, parent_flags);

  errno = err;
  return ret;
}

static int copy_xattrs (int src_fd, int dst_fd, bool compressed)
{
  int ret = -1;
  char *xattr_name_buf = NULL;
  size_t xattr_name_buf_size = 65536;
  char *buf = NULL;
  size_t buf_size = 0;
  ssize_t xattr_name_len;
  int xattr_opts = compressed ? XATTR_SHOWCOMPRESSION : 0;
  ssize_t xattr_len;

  for (;;) {
    xattr_name_buf = malloc (xattr_name_buf_size);
    xattr_name_len = flistxattr (src_fd, xattr_name_buf, xattr_name_buf_size,
				 xattr_opts);
    if (xattr_name_len < 0) {
      if (errno == ERANGE) {
	xattr_name_len = flistxattr (src_fd, NULL, 0, xattr_opts);
	if (xattr_name_len > 0) {
	  xattr_name_buf_size = xattr_name_len;
	  free (xattr_name_buf);
	  continue;
	}
      }
      
      LEAVE();
    }
    break;
  }

  for (char *xattr = xattr_name_buf;
       xattr < &xattr_name_buf[xattr_name_len];
       xattr += strlen (xattr) + 1) {
    // Skip the finder info and resource fork because we copy them elsewhere
    if (!strcmp (xattr, XATTR_FINDERINFO_NAME))
      continue;

    bool can_use_offset = false;
    if (!strcmp (xattr, XATTR_RESOURCEFORK_NAME)) {
      if (!compressed)
	continue;
      /* We have to copy the resource fork for compressed files using the
	 xattr routines. */
      can_use_offset = true;
    }

    if (!buf)
      buf = malloc (buf_size = 65536);
    
    uint32_t done = 0;
    do {
      for (;;) {
	xattr_len = fgetxattr (src_fd, xattr, buf, buf_size, done, xattr_opts);
	if (xattr_len >= 0)
	  break;
	if (errno == ERANGE) {
	  xattr_len = fgetxattr (src_fd, xattr, NULL, 0, 0, xattr_opts);
	  if (xattr_len < 0)
	    LEAVE ();
	  free (buf);
	  buf = malloc (buf_size = xattr_len);
	} else if (errno != EINTR)
	  LEAVE ();
      }

      for (;;) {
	int res = fsetxattr (dst_fd, xattr, buf, xattr_len, done, xattr_opts);
	if (!res)
	  break;
	if (errno == EPERM && unlock_fd (dst_fd)) {
	  /* We don't worry about fixing up the flags because we can fix
	     those later. */
	} else if (errno != EINTR)
	  LEAVE ();
      }

      done += xattr_len;
    } while (can_use_offset && (size_t)xattr_len == buf_size);
  }
  
  ret = 0;

LEAVE:;
  int err = errno;
  
  free (xattr_name_buf);
  free (buf);

  errno = err;
  return ret;
}
		
static int copy_acl (int src_fd, int dst_fd, const char *dst_path)
{
  int ret = -1;
  acl_t src_acl = NULL, cur_dst_acl = NULL, dst_acl = NULL;

  if (!(src_acl = acl_get_fd (src_fd))) {
    if (errno == ENOENT)
      return 0;
  }

  // First copy over the inherited acls
  dst_acl = acl_init (4);
  
  if (dst_fd < 0)
    cur_dst_acl = acl_get_file (dst_path, ACL_TYPE_EXTENDED);
  else 
    cur_dst_acl = acl_get_fd (dst_fd);

  if (cur_dst_acl) {
    acl_flagset_t flags;
    acl_entry_t src_entry = NULL, dst_entry;

    while (!acl_get_entry (cur_dst_acl,
			   src_entry ? ACL_NEXT_ENTRY : ACL_FIRST_ENTRY,
			   &src_entry)) {
      if (acl_get_flagset_np (src_entry, &flags))
	LEAVE ();

      if (acl_get_flag_np (flags, ACL_ENTRY_INHERITED)) {
	if (acl_create_entry(&dst_acl, &dst_entry))
	  LEAVE ();
	if (acl_copy_entry(dst_entry, src_entry))
	  LEAVE ();
      }
    }
  }

  // Now copy the source ACL
  acl_flagset_t flags;
  acl_entry_t src_entry = NULL, dst_entry;

  while (!acl_get_entry (src_acl,
			 src_entry ? ACL_NEXT_ENTRY : ACL_FIRST_ENTRY,
			 &src_entry)) {
    acl_get_flagset_np (src_entry, &flags);
    if (!acl_get_flag_np(flags, ACL_ENTRY_INHERITED)) {
      if (acl_create_entry(&dst_acl, &dst_entry))
	LEAVE ();

      if (acl_copy_entry (dst_entry, src_entry))
	LEAVE ();
    }
  }

  if (!dst_path) {
    if (acl_set_fd (dst_fd, dst_acl))
      LEAVE ();
  } else if (acl_set_file (dst_path, ACL_TYPE_EXTENDED, dst_acl))
    LEAVE ();

  ret = 0;

LEAVE:;
  
  int err = errno;
  
  if (src_acl)
    acl_free (src_acl);
  if (cur_dst_acl)
    acl_free (cur_dst_acl);
  if (dst_acl)
    acl_free (dst_acl);
  
  errno = err;

  return ret;
}

static int copy_set_attrs (int fd, 
			   copy_attrs_t *attrs, 
			   bool include_finder_info)
{
  int ret = -1;
  
  if (geteuid ()) {
    if (attrs->ownerid != getuid ()) {
      attrs->ownerid = getuid ();
      attrs->accessmask &= ~S_ISUID;
    }
    /* NOTE: This isn't exactly what you want because you can be a memeber
       of many groups, but it's just for testing. */
    if (attrs->grpid != getgid ()) {
      attrs->grpid = getgid ();
      attrs->accessmask &= ~S_ISGID;
    }
  }

#pragma pack(push, 4)
  union x {
    struct {
      struct timespec crtime, modtime, bkuptime;
      fndrinfo_t fndrinfo;
      uid_t ownerid, grpid;
      uint32_t accessmask;
      uint32_t flags;
    } a;
    struct {
      struct timespec crtime, modtime, bkuptime;
      uid_t ownerid, grpid;
      uint32_t accessmask;
      uint32_t flags;
    } b;
  } x;
#pragma pack(pop)

  size_t attrs_len;
  struct attrlist attr_list = {
    .bitmapcount = ATTR_BIT_MAP_COUNT,    
    .commonattr = (ATTR_CMN_CRTIME | ATTR_CMN_MODTIME
		   | ATTR_CMN_BKUPTIME 
		   | ATTR_CMN_OWNERID | ATTR_CMN_GRPID
		   | ATTR_CMN_ACCESSMASK | ATTR_CMN_FLAGS),
  };

  if (include_finder_info) {
    x = (union x) { .a = {
      attrs->crtime, attrs->modtime, attrs->bkuptime,
      attrs->fndrinfo, attrs->ownerid, attrs->grpid, attrs->accessmask,
      attrs->flags,
    } };
    attr_list.commonattr |= ATTR_CMN_FNDRINFO;
    attrs_len = sizeof (x.a);
  } else {
    x = (union x) { .b = {
      attrs->crtime, attrs->modtime, 
      attrs->bkuptime, attrs->ownerid, attrs->grpid, attrs->accessmask,
      attrs->flags 
    } };
    attrs_len = sizeof (x.b);
  }

  if (fsetattrlist (fd, &attr_list, &x, attrs_len, 0)
      && (errno != EPERM
	  || !unlock_fd (fd)
	  || fsetattrlist (fd, &attr_list, &x, attrs_len, 0))) {
    LEAVE ();
  }

  ret = 0;

LEAVE:

  return ret;
}

int rm_object (const char *path)
{
  int ret = -1;
  DIR *dir = NULL;
  uint32_t parent_flags = 0;

  struct attrlist attrlist = {
    .bitmapcount = ATTR_BIT_MAP_COUNT,
    .commonattr = ATTR_CMN_ACCESSMASK | ATTR_CMN_FLAGS,
    .dirattr = ATTR_DIR_LINKCOUNT,
  };

#pragma pack(push, 4)
  struct {
    uint32_t len;
    uint32_t access_mask;
    uint32_t flags;
    uint32_t link_count;
  } attrs;
#pragma pack(pop)

  if (getattrlist (path, &attrlist, &attrs, sizeof (attrs), FSOPT_NOFOLLOW)) {
    if (errno == ENOENT) {
      ret = 0;
      goto LEAVE;
    }
    LEAVEP (path);
  }

  if (attrs.flags & (UF_IMMUTABLE | SF_IMMUTABLE)) {
    uint32_t new_flags = attrs.flags & ~(UF_IMMUTABLE | SF_IMMUTABLE);
    if (lchflags (path, new_flags)
	&& (errno != EPERM
	    || !(parent_flags = unlock_parent (path))
	    || lchflags (path, new_flags))) {
      LEAVEP (path);
    }
  }

  switch (attrs.access_mask & S_IFMT) {
  case S_IFDIR: {
    if (attrs.link_count > 1)
      goto HARD_LINK_DIR;

    struct dirent *dirent;
    char file_path[PATH_MAX];
    size_t l = strlen (path);

    if (l > PATH_MAX - 1) {
      errno = ENAMETOOLONG;
      return -1;
    }
    memcpy (file_path, path, l);
    file_path[l++] = '/';

    dir = opendir (path);
    if (!dir)
      LEAVEP (path);
    while ((dirent = readdir (dir))) {
      if (should_skip_dirs (dirent))
	continue;
      if (dirent->d_namlen + l > PATH_MAX - 1) {
	errno = ENAMETOOLONG;
	LEAVE ();
      }
      memcpy (file_path + l, dirent->d_name, dirent->d_namlen + 1);

      if (rm_object (file_path))
	LEAVE ();
    }
    closedir (dir); dir = NULL;
    if (rmdir (path)
	&& (errno != EPERM
	    || parent_flags
	    || !(parent_flags = unlock_parent (path))
	    || rmdir (path))) {
      LEAVEP (path);
    }
  } break;
  default:
  HARD_LINK_DIR:
    if (unlink (path)
	&& (errno != EPERM
	    || parent_flags
	    || !(parent_flags = unlock_parent (path))
	    || unlink (path)))
      LEAVEP (path);
  }

  ret = 0;

LEAVE:;
  int err = errno;

  if (dir)
    closedir (dir);
  if (parent_flags)
    lock_parent (path, parent_flags);

  errno = err;
  return ret;
}

#if TEST

#include <sys/un.h>
#include <sys/socket.h>
#include <stdarg.h>
#include "sync.h"

int __attribute__((format(printf, 1, 2))) system_fmt (const char *fmt, ...)
{
  char *cmd;
  
  va_list args;
  va_start (args, fmt);
  
  if (vasprintf (&cmd, fmt, args) < 0)
    return -1;
  
  va_end (args);
  
  //  fprintf (stderr, "%s\n", cmd);
  int ret = system (cmd);
  
  free (cmd);
  
  return ret;
}

int main (void)
{  
  struct stat sb;
  char tmp[] = "/tmp/copy-test.XXXXXXXX";
  
  assert (mkdtemp (tmp));
  
  assert (!chdir (tmp));
  
  fprintf (stderr, "%s\n", tmp);
  
  assert (!system ("dd if=/dev/random count=3072 of=obj1"));
  assert (!system ("dd if=/dev/random count=3072 of=obj1" _PATH_RSRCFORKSPEC));
  assert (!system ("xattr -w test hello obj1"));

  chflags ("obj1", UF_IMMUTABLE);

  // To force different time
  sleep (1);

  assert (!copy_object ("obj1", "obj2", NULL, NULL, NULL, 0));
  
  assert (!system ("diff -q obj1 obj2"));
  assert (!system ("diff -q obj1" _PATH_RSRCFORKSPEC
		   " obj2" _PATH_RSRCFORKSPEC));
  assert (!system ("[ \"`xattr -p test obj2`\" == 'hello' ] "
		   "|| exit 1"));

  // Check flags got copied
  assert (!stat ("obj2", &sb));
  assert (sb.st_flags & UF_IMMUTABLE);

  // Check timestamps
  struct stat sb2;
  assert (!stat ("obj1", &sb2));
  assert (sb.st_mtime == sb2.st_mtime
	  && sb.st_birthtime == sb2.st_birthtime);
  
  // Create an immutable directory and then sync the metadata
  if (!geteuid ()) {
    assert (!system ("mkdir im-test ;"
		     "mkdir im-test/dir1 ; chmod ugo-rwx im-test/dir1 ; "
		     "xattr -w test hello im-test/dir1 ;"
		     "mkdir im-test/dir2 ; echo >im-test/dir2/file ; "
		     "chflags uchg im-test/dir2 ;"
		     "chflags uchg im-test"));
    assert (!copy_object ("im-test/dir1", "im-test/dir2", 
			  &(copy_options_t){ .meta_only = true }, NULL, NULL, 0));
    assert (!chflags ("im-test/dir1", UF_IMMUTABLE)
	    && !chflags ("im-test/dir2", UF_IMMUTABLE));
    assert (!copy_object ("im-test/dir2", "im-test/dir1",
			  &(copy_options_t){ .recursive = true }, NULL, NULL, 0));
  } else {
    fprintf (stderr,
	     "NOTE: Some tests only work when running as root and "
	     "have been skipped.\n");
  }

  // Fix flags on obj1 so that the below works
  assert (!chflags ("obj1", 0));

  // Create a compressed file that is kept in the attributes file
  assert (!system ("echo 'The quick brown fox jumps over the lazy dog.' "
		   ">comp_src ; ditto --hfsCompression comp_src obj1"
		   "; chmod +a 'guest deny read' obj1"));

  assert (!copy_object ("obj1", "obj2", NULL, NULL, NULL, 0));

  // Check that dest is compressed
  assert (!stat ("obj2", &sb));
  assert (sb.st_flags & UF_COMPRESSED);

  assert (!system ("diff -q comp_src obj2 "
		   "&& ( ls -le obj2 | grep '0: group:_guest deny read' )"));

  // Now create a compressed file that is kept in the resource fork
  assert (!system ("ditto --hfsCompression /usr/share/dict/web2a obj1"));

  assert (!copy_object ("obj1", "obj2", NULL, NULL, NULL, 0));

  // Check that dest is compressed
  assert (!stat ("obj2", &sb));
  assert (sb.st_flags & UF_COMPRESSED);

  assert (!system ("diff -q /usr/share/dict/web2a obj2"));

  assert (!system ("rm -f obj1 ; mkdir obj1 ; chmod +a 'guest deny read' obj1 "
		   "; chmod g+w obj1"));

  assert (!copy_object ("obj1", "obj2", NULL, NULL, NULL, 0));

  assert (!system ("ls -led obj2 | grep '0: group:_guest deny list'"));
  
  assert (!system ("ln -s obj1 lnk1 ; chmod -h g+w lnk1"));
  
  assert (!copy_object ("lnk1", "lnk2", NULL, NULL, NULL, 0));

  assert (!system ("ls -l lnk2 | grep 'lrwxrwxr-x '"));

  assert (!mkdir ("dir1", 0700));
  assert (!mkfifo ("dir1/fifo1", 0600));
  assert (!copy_object ("dir1", "dir2",
			&(copy_options_t){ .recursive = true }, NULL, NULL, 0));
  
  assert (!system ("echo file1 >dir1/file1 ; ln dir1/file1 dir1/file2"));

  assert (!sync_objects ("dir1", "dir2", NULL));
  
  assert (!stat ("dir2/file1", &sb) && sb.st_nlink == 2);

  assert (!system ("mkdir -p dir1/dir1/dir ; mkdir dir1/dir2")
	  && !link ("dir1/dir1/dir", "dir1/dir2/dir"));

  assert (!sync_objects ("dir1", "dir2", NULL));

  assert (!system ("echo hello > dir2/dir1/dir/test123 ; "
		   "[ \"$(<dir2/dir2/dir/test123)\" == \"hello\" ]"));

  // Test overwriting hard link files
  assert (!system ("echo different >dir1/file3 ; ln dir2/file2 dir2/file3"));

  assert (!sync_objects ("dir1", "dir2", NULL));

  assert (!system ("[ \"$(<dir2/file1)\" == \"file1\" ] && "
		   "[ \"$(<dir2/file2)\" == \"file1\" ] && "
		   "[ \"$(<dir2/file3)\" == \"different\" ]"));

  // Test overwriting hard link folders with some hard link files
  assert (!system ("rmdir dir1/dir1/dir ; rmdir dir1/dir2/dir ;"
		   "echo test456 >dir1/dir1/dir ; "
		   "ln dir1/dir1/dir dir1/dir2/dir"));

  assert (!sync_objects ("dir1", "dir2", NULL));

  assert (!system ("[ \"$(<dir2/dir1/dir)\" == \"test456\" ] && "
		   "[ \"$(<dir2/dir2/dir)\" == \"test456\" ]"));
  
  assert (!symlink ("dummy", "dir2/symlink")
	  && !lchflags ("dir2/symlink", UF_IMMUTABLE));

  assert (!sync_objects ("dir1", "dir2", NULL));
  
  // Check that syncing meta on compressed files works
  if (!geteuid ()) {
    assert (!system ("ditto --hfsCompression /usr/share/dict/web2a "
		     "dir1/compressed_file"));
    assert (!sync_objects ("dir1", "dir2", NULL));
    assert (!stat ("dir2/compressed_file", &sb) 
	    && (sb.st_flags & UF_COMPRESSED)
	    && sb.st_mode != 0400);
    assert (!chmod ("dir1/compressed_file", 0400));
    assert (!sync_objects ("dir1", "dir2", NULL));
    assert (!stat ("dir2/compressed_file", &sb) && sb.st_mode == 0100400);
  }
  
  // Check that changing the case of a file works
  assert (!system ("echo test > dir1/case-test\xE1\x82\xB0\xF0\x9D\x90\x80 "
		   "&& touch -t 01010000 dir1/case-test\xE1\x82\xB0\xF0\x9D\x90\x80"));
  assert (!sync_objects ("dir1", "dir2", NULL));
  assert (!system ("rm dir1/case-test\xE1\x82\xB0\xF0\x9D\x90\x80 "
		   "&& echo Test > dir1/Case-test\xE1\x83\xA0\xF0\x9D\x90\x80 "
		   "&& touch -t 01010000 dir1/Case-test\xE1\x83\xA0\xF0\x9D\x90\x80"));
  assert (!sync_objects ("dir1", "dir2", NULL));
  assert (!system ("[ \"$(<dir2/Case-test\xE1\x83\xA0\xF0\x9D\x90\x80)\" == \"Test\" ]"));

  if (!geteuid ()) {
    if (mknod ("dir1/dev", 0600 | S_IFBLK, makedev (1, 2)))
      perror ("mknod failed!");
    assert (!sync_objects ("dir1", "dir2", NULL));
    assert (!stat ("dir1/dev", &sb) && sb.st_rdev == makedev (1, 2));
  }

  // Create a socket on the target and see if we can delete it
  int sock = socket (PF_UNIX, SOCK_STREAM, 0);

  struct sockaddr_un addr = {
    .sun_family = AF_UNIX,
    .sun_path = "dir2/socket"
  };

  assert (!bind (sock, (struct sockaddr *)&addr, sizeof (addr)));
  assert (!sync_objects ("dir1", "dir2", NULL));
  close (sock);

  fprintf (stderr, "Finished.\n");

  return 0;
}

#endif

/* TODO: After setting the ACL, it might not be possible to set the attributes
   on an object.  To fix this, we need to set the ACL last. */
// TODO: Check meta only with copying xattrs
// TODO: Check copying xattrs on directories
// TODO: Check for UF_APPEND
// TODO: handle dev nodes
// TODO: check the attempted deletion of a mount point
