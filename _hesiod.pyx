cdef extern from "hesiod.h":
    int hesiod_init(void **context)
    void hesiod_end(void *context)
    char *hesiod_to_bind(void *context, char *name, char *type)
    char **hesiod_resolve(void *context, char *name, char *type)
    void hesiod_free_list(void *context, char **list)
    # This function isn't defined in 3.0.2, which is what Debian/Ubuntu use
    #void hesiod_free_string(void *context, char *str)

cdef extern from "errno.h":
    int errno

cdef extern from "string.h":
    char * strerror(int errnum)

cdef extern from "stdlib.h":
    void free(void *)

cdef void * __context

cdef class __ContextManager:
    def __init__(self):
        if hesiod_init(&__context) == -1:
            raise IOError(errno, strerror(errno))
    
    def __del__(self):
        hesiod_end(__context)

cdef object __cm
__cm = __ContextManager()

import threading
__lookup_lock = threading.Lock()

def bind(hes_name, hes_type):
    """
    Convert the provided arguments into a DNS name.
    
    The DNS name derived from the name and type provided is used to
    actually execute the Hesiod lookup.
    """
    cdef object py_result
    cdef char * c_result

    # N.B. libhesiod actually uses the locale, but
    # locale.getpreferredencoding is not threadsafe so we have to
    # assume utf-8.

    if isinstance(hes_name, unicode):
        hes_name = hes_name.encode('utf-8')
    if isinstance(hes_type, unicode):
        hes_type = hes_type.encode('utf-8')

    c_result = hesiod_to_bind(__context, hes_name, hes_type)
    if c_result is NULL:
        raise IOError(errno, strerror(errno))
    py_result = c_result
    
    free(c_result)
    return py_result

def resolve(hes_name, hes_type):
    """
    Return a list of records matching the given name and type.
    """
    cdef int i
    cdef object py_result
    py_result = list()
    cdef int err = 0
    cdef char ** c_result = NULL

    if isinstance(hes_name, unicode):
        hes_name = hes_name.encode('utf-8')
    if isinstance(hes_type, unicode):
        hes_type = hes_type.encode('utf-8')
    
    with __lookup_lock:
        c_result = hesiod_resolve(__context, hes_name, hes_type)
        err = errno
    
    if c_result is NULL:
        raise IOError(err, strerror(err))
    i = 0
    while True:
        if c_result[i] is NULL:
            break
        py_result.append(c_result[i].decode('utf-8', 'replace'))
        i = i + 1
    
    hesiod_free_list(__context, c_result)
    return py_result
