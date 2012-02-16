//
//  utils.h
//  CloneVolume
//
//  Created by Pumptheory P/L on 28/03/11.
//  Copyright 2011 Pumptheory P/L. All rights reserved.
//

#ifndef UTILS_H_
#define UTILS_H_

#define LEAVE()						    \
  ({							    \
    int err = errno;					    \
    fprintf (stderr, "%s:%u: error: %s\n",		    \
	     __func__, __LINE__, strerror (err));	    \
    errno = err;					    \
    goto LEAVE;						    \
  })

#define LEAVEP(path)					    \
  ({							    \
    int err = errno;					    \
    fprintf (stderr, "%s:%u: error: %s: %s\n",		    \
	     __func__, __LINE__, path, strerror (err));	    \
    errno = err;					    \
    goto LEAVE;						    \
  })

#endif // UTILS_H_
