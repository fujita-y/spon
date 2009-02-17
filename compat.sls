(library (spon compat)
  (export do-cmd)
  (import (rnrs)
	  (spon base)
	  )

  ;; -- do-cmd :: (String, [String]) -> Boolean
  ;; Execute an external command `cmd' with arguments `args'.
  ;; If the command is successfully exited, returns #t,
  ;; otherwise returns #f.
  ;; When `verbose?' procedure (in the library (spon base)) returns #f,
  ;; standard output of the command is discarded.
  (define (do-cmd cmd . args)
    (raise (condition
	    (make-implementation-restriction-violation)
	    (make-who-condition 'do-cmd)
	    (make-message-condition
	     "Compatibility layer is not implemented. \
              Please contact the author of your implementation.")
	    (make-irritants-condition (cons cmd args)))))
  )