//
//  hard-links.c
//  CloneVolume
//
//  Created by Pumptheory P/L on 3/04/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

#include <unistd.h>

#include <CoreFoundation/CoreFoundation.h>

#include "hard-links.h"
#include "sync-private.h"

struct hard_link {
  uint64_t src_file_id;		  // MUST BE FIRST
  uint64_t dst_file_id;
  uint32_t count;
  uint32_t src_found;
  bool created_target;
  /* master is the index of the link that is the target of all the other
     links that we create. */  
  bool got_master;
  uint32_t master;
  struct link {
    struct sync_attrs *parent, *attrs;
  } links[0];
};

static Boolean hard_links_equal (const void *value1,
				 const void *value2)
{
  const struct hard_link *a = value1, *b = value2;
  return a->src_file_id == b->src_file_id;
}

static CFHashCode hard_link_hash (const void *value)
{
  const struct hard_link *a = value;
  return a->src_file_id;
}

/* Returnes true if it's a hard link and sets first if it's the first
   hard link that we've found. */
bool handle_src_hard_link (struct sync_ctx *ctx, 
			   struct sync_attrs *parent,
			   struct sync_attrs *attrs,
			   uint32_t *ndx)
{
  assert_locked (ctx);

  if (attrs->is_hard_link) {
    if (ndx)
      *ndx = attrs->link_count;
    return true;
  }

  if (attrs->link_count <= 1)
    return false;

  retain_attrs (ctx, parent);
  retain_attrs (ctx, attrs);

  attrs->is_hard_link = true;

  if (!ctx->hard_links) {
    CFSetCallBacks callBacks = {
      .version = 0,
      .retain = NULL,
      .release = NULL,
      .copyDescription = NULL,
      .equal = hard_links_equal,
      .hash = hard_link_hash,
    };

    ctx->hard_links = CFSetCreateMutable (NULL, 0, &callBacks);
  } else {
    struct hard_link *link;

    /* NOTE: The following works because the file ID is the first element
       in the structure and the only thing we check. */
    if ((link = (struct hard_link *)CFSetGetValue (ctx->hard_links, 
						   &attrs->file_id))) { 
      if (link->src_found == link->count) {
	// Hmm. We've found more links than we expected.
	CFSetRemoveValue (ctx->hard_links, link);
	link = realloc (link, (sizeof (link) 
			       + sizeof (link->links[0]) * ++link->count));
	CFSetAddValue (ctx->hard_links, link);
      }

      if (ndx)
	*ndx = link->src_found;
      attrs->link_count = link->src_found;
      link->links[link->src_found].attrs = attrs;
      link->links[link->src_found].parent = parent;
      ++link->src_found;

      return true;
    }
  }

  struct hard_link *link = calloc (1, (sizeof (*link) 
				       + (sizeof (link->links[0])
					  * attrs->link_count)));

  link->src_file_id = attrs->file_id;
  link->count = attrs->link_count;
  attrs->link_count = 0;
  link->links[0].attrs = attrs;
  link->links[0].parent = parent;
  link->src_found = 1;

  CFSetAddValue (ctx->hard_links, link);

  if (ndx)
    *ndx = 0;

  return true;
}

handle_dst_hard_link_ret_t
handle_dst_hard_link (struct sync_ctx *ctx,
		      struct sync_attrs *src_attrs,
		      struct sync_attrs *dst_attrs)
{
  assert_locked (ctx);
  assert (src_attrs->is_hard_link);

  struct hard_link *link 
    = (struct hard_link *)CFSetGetValue (ctx->hard_links,
					 &src_attrs->file_id);

  // Have we already got the master hard link?
  if (link->got_master) {
    return (dst_attrs->file_id == link->dst_file_id
	    ? LINK_SAME : LINK_NOT_SAME);
  }

  // Record the master file
  link->master = src_attrs->link_count;
  link->got_master = true;

  // If we've scanned the directory, move it to this folder instead
  struct dir *dir;
  if ((dir = link->links[0].attrs->dir)) {
    link->links[0].attrs->dir = NULL;
    for (unsigned i = 0; i < dir->count; ++i) {
      copy_attrsn_t *child = dir->attrs[i];
      if (S_ISDIR (child->accessmask))
	child->parent = &src_attrs->ca;
    }
    src_attrs->dir = dir;
  }

  return LINK_FIRST;
}

bool can_copy_hard_link (struct sync_ctx *ctx, struct sync_attrs *attrs)
{
  assert_locked (ctx);

  struct hard_link *link
    = (struct hard_link *)CFSetGetValue (ctx->hard_links,
					 &attrs->file_id);

  return link->got_master;
}

hard_link_handler_ret_t
copy_hard_link_handler (void *ctx_param,
			struct copy_attrs *ca,
			char **ptarget_path)
{
  struct sync_ctx *ctx = ctx_param;
  struct sync_attrs *attrs = sync_attrs_from_copy_attrs (ca);

  lock (ctx);

  hard_link_handler_ret_t ret = copy_hard_link_handler_unlocked (ctx_param,
								 attrs,
								 ptarget_path);

  if (ret == HARD_LINK_IGNORE)
    attrs->deferred_hard_link = true;

  unlock (ctx);

  return ret;  
}

hard_link_handler_ret_t
copy_hard_link_handler_unlocked (struct sync_ctx *ctx,
				 struct sync_attrs *attrs,
				 char **ptarget_path)
{
  assert_locked (ctx);

  if (!attrs->is_hard_link)
    return HARD_LINK_COPY_TARGET;

  struct hard_link *link
    = (struct hard_link *)CFSetGetValue (ctx->hard_links,
					 &attrs->file_id);

  if (link->got_master
      && attrs == link->links[link->master].attrs) {
    /* It's possible for the handler to get called twice for the master link:
       once when copying a parent folder recursively and then again for
       the operation queued by finish_hard_link.  We can simply ignore the
       second call. */
    return link->created_target ? HARD_LINK_IGNORE : HARD_LINK_COPY_TARGET;
  }

  if (!link->created_target)
    return HARD_LINK_IGNORE;

  if (ptarget_path) {
    char path_buf[PATH_MAX], *path;

    path = attrs_path (path_buf, link->links[link->master].parent, ctx->dst,
		       attrs_name (link->links[link->master].attrs));

    *ptarget_path = strdup (path);
  }

  return HARD_LINK_MAKE_LINK;
}

int got_hard_link_target (struct sync_ctx *ctx, 
			  struct sync_attrs *attrs,
			  uint64_t file_id,
			  const char *target_path)
{
  assert_locked (ctx);

  struct hard_link *link
    = (struct hard_link *)CFSetGetValue (ctx->hard_links,
					 &attrs->file_id);

  if (!link->created_target) {
    assert (link->got_master && attrs == link->links[link->master].attrs);

    link->created_target = true;
    link->dst_file_id = file_id;

    char path_buf[PATH_MAX];

    // And now we need to make the other links
    for (unsigned i = 0; i < link->src_found; ++i) {
      if (i == link->master)
	continue;

      struct link *lnk = &link->links[i];
      if (!lnk->attrs->deferred_hard_link)
	continue;

      if (target_path) {
	char *path = attrs_path (path_buf, lnk->parent, ctx->dst,
				 attrs_name (lnk->attrs)); 

	if (make_link (target_path, path))
	  return -1;

	ctx->progress.done += OBJ_PROGRESS_FACTOR;
      } else
	queue_copy_op (ctx, lnk->parent, lnk->attrs, NULL);
    }
  }

  return 0;
}

static void finish_hard_link (struct hard_link *link, struct sync_ctx *ctx)
{
  if (!link->got_master) {
    link->master = 0;
    link->got_master = true;
    queue_copy_op (ctx, link->links[0].parent, link->links[0].attrs, NULL);
  }
}

void finish_hard_links (struct sync_ctx *ctx)
{
  assert_locked (ctx);

  if (ctx->hard_links) {
    CFSetApplyFunction (ctx->hard_links, 
			(CFSetApplierFunction)finish_hard_link, 
			ctx);
  }
}

void destroy_hard_links (struct sync_ctx *ctx)
{
  assert_locked (ctx);
  if (!ctx->hard_links)
    return;

  CFIndex count = CFSetGetCount (ctx->hard_links);
  struct hard_link **links = malloc (count * sizeof (void *));
  CFSetGetValues (ctx->hard_links, (const void **)links);
  CFRelease (ctx->hard_links);
  ctx->hard_links = NULL;
  for (CFIndex i = 0; i < count; ++i) {
    struct hard_link *lnk = links[i];
    for (unsigned j = 0; j < lnk->src_found; ++j) {
      struct sync_attrs *parent = lnk->links[j].parent;
      struct sync_attrs *attrs = lnk->links[j].attrs;
      free_dir (ctx, parent, parent->dir);
      release_attrs (ctx, parent);
      if (attrs_is_dir (attrs))
	release_attrs (ctx, attrs);
      else
	destroy_entry (ctx, attrs);
    }
    free (lnk);
  }
}

struct sync_attrs *hard_link_master (struct sync_ctx *ctx,
				     struct sync_attrs *attrs)
{
  assert_locked (ctx);

  if (!attrs->is_hard_link)
    return attrs;

  struct hard_link *link
    = (struct hard_link *)CFSetGetValue (ctx->hard_links,
					 &attrs->file_id);

  return link->links[link->master].attrs;
}
