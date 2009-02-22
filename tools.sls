(library (spon tools)
  (export download verify decompress install
          system-name verbose? quiet?)
  (import (rnrs)
          (srfi :48)
          (srfi :98)
          (spon base)
          (spon compat))

  (define *default-spon-uri* "http://scheme-users.jp/spon")
  (define *default-spon-dir* "/usr/local/share/spon")

  (define-condition-type &i/o-download &i/o-read
    make-i/o-download-error i/o-download-error?)

  (define *config-search-path*
    `(,@(cond
         ((get-environment-variable "HOME")
          => (lambda (home)
               (list (string-append home "/.spon"))))
         (else '()))
      "/usr/local/share/spon/sponrc"
      "/usr/share/spon/sponrc"
      "/etc/sponrc"))

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

  (define (load-config)
    (let ((config (make-hashtable string-hash string=?))
          (config-path (find file-exists? *config-search-path*)))
      (when config-path
        (call-with-input-file config-path
          (lambda (in)
            (for-each
             (lambda (x)
               (if (not (pair? x))
                   (error 'load-config "invalid configuration" x)
                   (hashtable-set! config (format "~A" (car x)) (cdr x))))
             (read in)))))
      (letrec (($ (case-lambda
                   ((key)
                    ($ key key))
                   ((key default)
                    (hashtable-ref config key default)))))
        $)))

  (define (get-config)
    (let ((config #f))
      (lambda x
        (unless config
          (set! config (load-config)))
        (apply config x))))

  (define (cmd-wget uri dir)
    (do-cmd ((get-config) "wget") "-N" "-P" dir uri))

  (define (cmd-gpg signature file)
    (do-cmd ((get-config) "gpg") "--verify" signature file))

  (define (cmd-tar file dir)
    (do-cmd ((get-config) "tar") "-xvzf" file "-C" dir))

  (define (download package)
    (let* ((config (get-config))
           (spon-dir (config "spon-dir" *default-spon-dir*))
           (spon-uri (config "spon-uri" *default-spon-uri*))
           (pkg-uri  (format "~A/~A.tar.gz" spon-uri package))
           (sig-uri  (format "~A.asc" pkg-uri))
           (src-dir  (format "~A/src" spon-dir)))
      (do-procs
       ((format "Downloading package: ~A ..." pkg-uri)
        (cmd-wget pkg-uri src-dir)
        #f
        "failed to download package.")
       ((format "Downloading signature: ~A ..." sig-uri)
        (cmd-wget sig-uri src-dir)
        #f
        "failed to download signature."))))

  (define (verify package)
    (let* ((config (get-config))
           (spon-dir (config "spon-dir" *default-spon-dir*))
           (pkg-file (format "~A/src/~A.tar.gz" spon-dir package))
           (sig-file (format "~A.asc" pkg-file)))
      (do-procs
       ("Veryfying package ..."
        (cmd-gpg sig-file pkg-file)
        #f
        "cannot verify package."))))

  (define (decompress package)
    (let* ((config (get-config))
           (spon-dir (config "spon-dir" *default-spon-dir*))
           (pkg-file (format "~A/src/~A.tar.gz" spon-dir package)))
      (do-procs
       ("Decompressing package ..."
        (cmd-tar pkg-file spon-dir)
        #f
        "error in decompressing package"))))

  (define (install package)
    (let ((r (and (download package)
                  (verify package)
                  (decompress package))))
      (unless (quiet?)
        (if r
          (format #t "----> ~A is successfully installed.~%" package)
          (format #t "----> ~A install failed.~%" package)))
      r))
  )
