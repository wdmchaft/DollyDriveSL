//
//  hard-links.h
//  CloneVolume
//
//  Created by Pumptheory P/L on 3/04/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

#ifndef HARD_LINKS_H_
#define HARD_LINKS_H_

#include <stdbool.h>
#include "copy.h"

struct sync_ctx;
struct sync_attrs;

bool handle_src_hard_link (struct sync_ctx *ctx, 
			   struct sync_attrs *parent,
			   struct sync_attrs *attrs,
			   uint32_t *ndx);

typedef enum {
  LINK_FIRST,
  LINK_SAME,
  LINK_NOT_SAME,
} handle_dst_hard_link_ret_t;

handle_dst_hard_link_ret_t
  handle_dst_hard_link (struct sync_ctx *ctx,
			struct sync_attrs *src_attrs,
			struct sync_attrs *dst_attrs);

hard_link_handler_ret_t
  copy_hard_link_handler (void *ctx_param,
			  struct copy_attrs *src_attrs,
			  char **ptarget_path);
hard_link_handler_ret_t
  copy_hard_link_handler_unlocked (struct sync_ctx *ctx,
				   struct sync_attrs *attrs,
				   char **ptarget_path);

bool can_copy_hard_link (struct sync_ctx *ctx, struct sync_attrs *attrs);

int got_hard_link_target (struct sync_ctx *ctx, 
			  struct sync_attrs *attrs,
			  uint64_t file_id,
			  const char *target_path);
void finish_hard_links (struct sync_ctx *ctx);
void destroy_hard_links (struct sync_ctx *ctx);
struct sync_attrs *hard_link_master (struct sync_ctx *ctx,
				     struct sync_attrs *attrs);

#endif // HARD_LINKS_H_
