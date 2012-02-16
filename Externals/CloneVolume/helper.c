/*
 *  helper.c
 *  CloneVolume
 *
 *  Created by Pumptheory P/L on 1/02/11.
 *  Copyright 2011 Pumptheory P/L. All rights reserved.
 *
 */

#include <spawn.h>
#include <sys/errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <pthread.h>
#include <signal.h>
#include <assert.h>

#include "sync.h"

static void execute (void (*fn)(char **), char **args);

static void do_bless (char *folder);
static void do_format (char *target);
static void do_asr (char **args);
static void do_sync (char **args);
static void do_update_dyld(char *target);

static pthread_t thread;
static void (* abort_fn)(void);
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static bool aborted, thread_finished;

/* ----------------------------------------------------------------------- */

int parse_args (const char *line, size_t len, char ***pargs, unsigned reserved)
{
  const unsigned max_args = 16;
  void *arg_buf = malloc (65536);
  char **args = arg_buf;
  char *arg_ptr = arg_buf + (max_args + 1) * sizeof (char *);
  unsigned arg_count = reserved;
  
  char c;
  const char *p = line;
  for (;;) {
    while (len && *p == ' ') {
      ++p;
      --len;
    }
    if (!len || *p == '\n')
      break;
    if (arg_count == max_args) {
      free (args);
      return -1;
    }
    args[arg_count] = arg_ptr;
    while (len && (c = *p) != ' ' && c != '\n') {
      if (c == '\\') {
	if (!--len) {
	  free (args);
	  return -1;
	}
	switch ((c = *++p)) {
          case 'r':
            c = '\r';
            break;
          case 'n':
            c = '\n';
            break;
	}
      }
      *arg_ptr++ = c;
      ++p;
      --len;
    }
    *arg_ptr++ = 0;
    ++arg_count;
  }
  
  args[arg_count] = NULL;
  *pargs = args;
  
  return arg_count;
}

int main (void)
{
  /* TODO: Should mask out all possible signals for the threads since I know
   there are a few places where we don't catch EINTR. */
  sigignore (SIGPIPE); 
  
  setlinebuf (stdout);
  printf ("CloneVolume Helper started (pid:%u)\n", getpid());
  
  for (;;) {
    size_t len;
    char *line = fgetln (stdin, &len);
    if (!line) {
      // pipe closed
      if (ferror (stdin) && errno == EINTR)
	continue;
      
      return 0;
    }
    if (len > 65536) {
      fprintf (stderr, "CloneVolume Helper: bad command! (%s)\n", line);
      continue;
    }
    
    if (thread_finished) {
      pthread_join (thread, NULL);
      thread_finished = false;
      thread = NULL;
    }
    
    if (len > 11 && !memcmp (line, "LAUNCH_ASR ", 11)) {
      char **args;
      
      if (parse_args (line + 11, len - 11, &args, 1) < 0) {
	fprintf (stderr, "CloneVolume Helper: bad args to LAUNCH_ASR command\n");
	continue;
      }
      
      args[0] = "asr";
      
      execute (do_asr, args);
    } else if (len > 6 && !memcmp (line, "BLESS ", 6)) {
      int argc;
      char **args;
      
      if ((argc = parse_args (line + 6, len - 6, &args, 0)) < 0 || argc != 1) {
	if (argc >= 0)
	  free (args);
	fprintf (stderr, "CloneVolume Helper: bad args to BLESS command: %s\n",
		 line);
	continue;
      }
      
      do_bless(args[0]);
    } else if (len > 7 && !memcmp (line, "FORMAT ", 7)) {
      int argc;
      char **args;
      
      if ((argc = parse_args (line + 7, len - 7, &args, 0)) < 0 || argc != 1) {
	if (argc >= 0)
	  free (args);
	fprintf (stderr, "CloneVolume Helper: bad args to FORMAT command: %s\n",
		 line);
	continue;
      }
      
      do_format(args[0]);
    } else if (len > 5 && !memcmp (line, "SYNC ", 5)) {
      int argc;
      char **args;
      
      if ((argc = parse_args (line + 5, len - 5, &args, 0)) < 0 || argc != 2) {
	if (argc >= 0)
	  free (args);
	fprintf (stderr, "CloneVolume Helper: bad args to SYNC command: %s\n",
		 line);
	continue;
      }
      
      execute (do_sync, args);
    } else if (len > 12 && !memcmp(line, "UPDATE_DYLD ", 12)) {
      int argc;
      char **args;
      
      if ((argc = parse_args (line + 12, len - 12, &args, 0)) < 0 || argc != 1) {
	if (argc >= 0)
	  free (args);
	fprintf (stderr, "CloneVolume Helper: bad args to UPDATE_DYLD command: %s\n",
		 line);
	continue;
      }
      
      do_update_dyld(args[0]); // executes on foreground thread
    } else if (len == 6 && !memcmp (line, "ABORT\n", 6)) {
      pthread_mutex_lock (&mutex);
      aborted = true;
      if (abort_fn)
	abort_fn ();
      pthread_mutex_unlock (&mutex);
    } else
      fprintf (stderr, "Bad command: %.*s\n", (int)len, line);
  }
}

struct execute_ctx {
  void (* fn) (char **args);
  char **args;
};

static void * execute_thread (void *param)
{
  struct execute_ctx *ctx = param;
  ctx->fn (ctx->args);
  free (ctx->args);
  free (ctx);
  thread_finished = true;
  return NULL;
}

static void execute (void (*fn)(char **), char **args)
{
  if (thread) {
    fprintf (stderr, "helper: other command still running!\n");
    free (args);
    return;
  }
  
  pthread_mutex_lock (&mutex);
  aborted = false;
  pthread_mutex_unlock (&mutex);
  
  struct execute_ctx *ctx = malloc (sizeof (*ctx));
  ctx->fn = fn;
  ctx->args = args;
  thread_finished = false;
  pthread_create (&thread, NULL, execute_thread, ctx);
}

static void set_abort_fn (void (*new_abort_fn)(void)) 
{
  pthread_mutex_lock (&mutex);
  if (aborted)
    new_abort_fn ();
  abort_fn = new_abort_fn;
  pthread_mutex_unlock (&mutex);
}

#pragma mark do_update_dyld

static void do_update_dyld(char *target)
{
  static char *cmd_suffix = "/usr/bin/update_dyld_shared_cache";
  char *cmd = malloc(strlen(target) + strlen(cmd_suffix));
  if (!cmd)
    exit(2);
  
  // targets always end in a slash
  //TODO: check for that
  sprintf(cmd, "%s%s", target, cmd_suffix);
  
  // if cloning a non-system volume, can't do
  if( access( cmd, X_OK ) != 0 )
    goto FINISHED;
  
  char *args[5];
  args[0] = cmd;
  args[1] = "-universal_boot";
  args[2] = "-root";
  args[3] = target;
  args[4] = NULL;
  
  pid_t pid;
  
  if ((pid = fork()) == 0)
  {
    if (setuid(0) != 0)
    {
      fprintf(stderr, "Unable to change uid to 0: %s", strerror(errno));
      exit(3);
    }
    
    execv(cmd, args);
    fprintf(stderr, "couldn't exec!");
    exit(4);
  }
  
  free(cmd);
  
  fprintf(stderr, "waiting for update_dyld_shared_cache (%d)", pid);
  
  int ret = 0;
  
  wait(&ret);
  
  if(WIFEXITED(ret) && WEXITSTATUS(ret) == 0)
  {
  FINISHED:
    printf("UPDATE_DYLD: FINISHED 0\n");
  }
  else if (WIFEXITED(ret))
  {
    printf("UPDATE_DYLD: FINISHED %d\n", WEXITSTATUS(ret));
  }
  else
  {
  LEAVE:
    printf("UPDATE_DYLD: FINISHED -1\n");
  }
}

#pragma mark do_format

static void do_format (char *target)
{
  //char *cmd = "diskutil";
  //char *const cmd_args[] = {"/usr/sbin/diskutil", "eraseVolume", "JournaledHFS+", "Untitled", target, NULL};
  char *const cmd_args[] = {"/usr/sbin/diskutil", "eraseVolume", "HFS+", "Untitled", target, NULL};
  pid_t pid;
  
  if ((pid = fork()) == 0)
  {
    if (setuid(0) != 0)
    {
      fprintf(stderr, "Unable to change uid to 0: %s", strerror(errno));
      exit(3);
    }
    
    execv("/usr/sbin/diskutil", cmd_args);
    fprintf(stderr, "couldn't exec! error(%s)", strerror(errno));
    exit(4);
  }
  
  fprintf(stderr, "waiting for format(%d)", pid);
  
  int ret = 0;
  
  wait(&ret);
  
  if(WIFEXITED(ret) && WEXITSTATUS(ret) == 0)
  {
  FINISHED:
    printf("FORMAT: FINISHED 0\n");
  }
  else if (WIFEXITED(ret))
  {
    printf("FORMAT: FINISHED %d\n", WEXITSTATUS(ret));
  }
  else
  {
  LEAVE:
    printf("FORMAT: FINISHED -1\n");
  }
}


#pragma mark do_bless
static void do_bless (char *folder)
{
  char *const cmd_args[] = {"/usr/sbin/bless", "-folder", folder,  NULL};
  pid_t pid;
  
  if ((pid = fork()) == 0)
  {
    if (setuid(0) != 0)
    {
      fprintf(stderr, "Unable to change uid to 0: %s", strerror(errno));
      exit(3);
    }
    
    execv("/usr/sbin/bless", cmd_args);
    fprintf(stderr, "couldn't exec! error(%s)", strerror(errno));
    exit(4);
  }
  
  fprintf(stderr, "waiting for bless(%d)", pid);
  
  int ret = 0;
  
  wait(&ret);
  
  if(WIFEXITED(ret) && WEXITSTATUS(ret) == 0)
  {
  FINISHED:
    printf("BLESS: FINISHED 0\n");
  }
  else if (WIFEXITED(ret))
  {
    printf("BLESS: FINISHED %d\n", WEXITSTATUS(ret));
  }
  else
  {
  LEAVE:
    printf("BLESS: FINISHED -1\n");
  }
}
#pragma mark do_asr

static pid_t asr_pid;

static void cancel_asr (void)
{
  kill (asr_pid, SIGTERM);
}

static void do_asr (char **args)
{
  pid_t wpid;
  int status;
  
  if (posix_spawn (&asr_pid, "/usr/sbin/asr", NULL, NULL, args, NULL))
    perror ("posix_spawn failed");
  
  set_abort_fn (cancel_asr);
  
  while ((wpid = waitpid (asr_pid, &status, 0)) == -1 && errno == EINTR)
    ;
  
  set_abort_fn (NULL);
  
  if (wpid != asr_pid)
    printf ("CloneVolume Helper: FINISHED -1\n");
  else
    printf ("CloneVolume Helper: FINISHED %d\n", status);
}

#pragma mark do_sync

struct do_sync_ctx {
  uint64_t last_done;
  double last_progress;
  bool abort;
} sync_ctx;

static void * sync_thread (void *param);

static int sync_progress (sync_progress_t *progress)
{
  struct do_sync_ctx *ctx = progress->ctx;
  if (ctx->abort) {
    errno = ECANCELED;
    return -1;
  }
  
  /* Because the totals can vary, we do things this way to make sure that
   progress always increments. */
  uint64_t t = progress->total - ctx->last_done;
  double delta;
  if (t && ((delta = ((double)(progress->done - ctx->last_done) / t
                      * (1 - ctx->last_progress))) > 0.005
	    || (ctx->last_progress == 0 && delta))) {
    ctx->last_progress += delta;
    printf ("PROGRESS %f\n", ctx->last_progress);
    ctx->last_done = progress->done;
  }
  
  return 0;
}

struct do_sync_ctx do_sync_ctx;

static void abort_sync (void)
{
  do_sync_ctx.abort = true;
}

static void do_sync (char **args)
{
  bzero (&do_sync_ctx, sizeof (do_sync_ctx));
  
  struct sync_options opts = {
    .progress_fn = sync_progress,
    .ctx = &do_sync_ctx,
  };
  
  set_abort_fn (abort_sync);
  
  if (sync_objects (args[0], args[1], &opts))
    printf ("CloneVolume Helper: FINISHED %d\n", errno);
  else
    printf ("CloneVolume Helper: FINISHED 0\n");
}
