;;; snarf-guile-m4-docs --- Parse guile.m4 comments for texi documentation

;; 	Copyright (C) 2002, 2006, 2011 Free Software Foundation, Inc.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU Lesser General Public License
;; as published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.
;;
;; You should have received a copy of the GNU Lesser General Public
;; License along with this software; see the file COPYING.LESSER.  If
;; not, write to the Free Software Foundation, Inc., 51 Franklin
;; Street, Fifth Floor, Boston, MA 02110-1301 USA

;;; Author: Thien-Thi Nguyen <ttn@gnu.org>

;;; Commentary:

;; Usage: snarf-guile-m4-docs FILE
;;
;; Grep FILE for comments preceding macro definitions, massage
;; them into valid texi, and display to stdout.  For each comment,
;; lines preceding "^# Usage:" are discarded.
;;
;; TODO: Generalize.

;;; Code:

(define-module (scripts snarf-guile-m4-docs)
  :use-module (ice-9 rdelim)
  :export (snarf-guile-m4-docs))

(define %include-in-guild-list #f)
(define %summary "Snarf out texinfo documentation from .m4 files.")

(define (display-texi lines)
  (display "@deffn {Autoconf Macro}")
  (for-each (lambda (line)
              (display (cond ((and (>= (string-length line) 2)
				   (string=? "# " (substring line 0 2)))
			      (substring line 2))
			     ((string=? "#" (substring line 0 1))
			      (substring line 1))
			     (else line)))
              (newline))
            lines)
  (display "@end deffn")
  (newline) (newline))

(define (prefix? line sub)
  (false-if-exception
   (string=? sub (substring line 0 (string-length sub)))))

(define (massage-usage line)
  (let loop ((line (string->list line)) (acc '()))
    (if (null? line)
        (list (list->string (reverse acc)))
        (loop (cdr line)
              (cons (case (car line)
                      ((#\( #\) #\,) #\space)
                      (else (car line)))
                    acc)))))

(define (snarf-guile-m4-docs . args)
  (let* ((p (open-file (car args) "r"))
         (next (lambda () (read-line p))))
    (let loop ((line (next)) (acc #f))
      (or (eof-object? line)
          (cond ((prefix? line "# Usage:")
                 (loop (next) (massage-usage (substring line 8))))
                ((prefix? line "AC_DEFUN")
                 (display-texi (reverse acc))
                 (loop (next) #f))
                ((and acc (prefix? line "#"))
                 (loop (next) (cons line acc)))
                (else
                 (loop (next) #f)))))))

(define main snarf-guile-m4-docs)

;;; snarf-guile-m4-docs ends here
