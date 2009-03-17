(library (spon tools)
  (export download verify decompress install
          system-name verbose? quiet? download-error? download-error-uri)
  (import (rnrs)
          (srfi :48)
          (spon base)
          (spon config)
          (spon compat))

  (define-condition-type &spon &error
    make-spon-error spon-error?)

  (define-condition-type &download &spon
    make-download-error download-error?
    (uri download-error-uri))

  (define-syntax do-procs
    (syntax-rules ()
      ((_ (pre cmd ok ng) ...)
       (and (begin
              (unless (quiet?)
                (format #t "----> ~A~%" pre))
              (let ((res cmd))
                (unless (quiet?)
                  (if res
                      (when ok
                        (format #t "----> ~A~%" ok))
                      (format #t "----> ERROR: ~A~%" ng)))
                res))
            ...))))

  (define (cmd-wget uri dir)
    (or (apply do-cmd
                ((get-config) "wget")
                "-N" "-P" dir uri (if (quiet?) '("-q") '()))
         (raise (make-download-error uri))))

  (define (cmd-gpg signature file)
    (let ((gpg ((get-config) "gpg" #f)))
      (or (not gpg)
          (apply do-cmd
                 gpg
                 `(,@(if (quiet?) '("-q") '()) "--verify" signature file)))))

  (define (cmd-tar file dir)
    (apply do-cmd
           ((get-config) "tar")
           "-xzf" file "-C" dir (if (quiet?) '() '("-v"))))

  (define (show-progress text)
    (unless (quiet?)
      (format #t "----> ~A" text)))

  (define (ok)
    (display " ok\n"))

  (define (download package)
    (let* ((config (get-config))
           (spon-uri (config "spon-uri" *spon-uri*))
           (pkg-uri  (format "~A/~A.tar.gz" spon-uri package))
           (sig-uri  (format "~A.asc" pkg-uri))
           (src-path (config "source-path" *source-path*)))
      (show-progress (format "Downloading package: ~A ..." pkg-uri))
      (cmd-wget pkg-uri src-path)
      (ok)
      (show-progress (format "Downloading signature: ~A ..." sig-uri))
      (cmd-wget sig-uri src-path)
      (ok)))

  (define (verify package)
    (let* ((config (get-config))
           (src-path (config "source-path" *source-path*))
           (pkg-file (format "~A/~A.tar.gz" src-path package))
           (sig-file (format "~A.asc" pkg-file)))
      (or (not (config "gpg" #f))
          (do-procs
           ("Veryfying package ..."
            (cmd-gpg sig-file pkg-file)
            #f
            "cannot verify package.")))))

  (define (decompress package)
    (let* ((config (get-config))
           (src-path (config "source-path" *source-path*))
           (pkg-file (format "~A/~A.tar.gz" src-path package)))
      (do-procs
       ("Decompressing package ..."
        (cmd-tar pkg-file src-path)
        #f
        "error in decompressing package"))))

  (define (setup package)
    (let* ((config (get-config))
           (src-path (config "source-path" *source-path*))
           (impl (current-implementation-name))
           (install.ss (format "~A/~A/install.~A.ss" src-path package impl)))
      (do-procs
       ((format "Setup package to ~A ..." impl)
        (do-cmd impl install.ss)
        #f
        (format "error in ~A/install.~A.ss" package impl)))))

  (define (install package)
    (let ((r (and (download package)
                  (verify package)
                  (decompress package)
                  (setup package))))
      (unless (quiet?)
        (if r
          (format #t "----> ~A is successfully installed.~%" package)
          (format #t "----> ~A install failed.~%" package)))
      r))
  )
