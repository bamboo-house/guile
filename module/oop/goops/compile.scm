;;;; 	Copyright (C) 1999, 2001, 2006 Free Software Foundation, Inc.
;;;; 
;;;; This library is free software; you can redistribute it and/or
;;;; modify it under the terms of the GNU Lesser General Public
;;;; License as published by the Free Software Foundation; either
;;;; version 2.1 of the License, or (at your option) any later version.
;;;; 
;;;; This library is distributed in the hope that it will be useful,
;;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;;; Lesser General Public License for more details.
;;;; 
;;;; You should have received a copy of the GNU Lesser General Public
;;;; License along with this library; if not, write to the Free Software
;;;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
;;;; 


;; There are circularities here; you can't import (oop goops compile)
;; before (oop goops). So when compiling, make sure that things are
;; kosher.
(eval-case ((compile-toplevel) (resolve-module '(oop goops))))

(define-module (oop goops compile)
  :use-module (oop goops)
  :use-module (oop goops util)
  :export (compute-cmethod compile-make-procedure)
  :no-backtrace
  )

;;;
;;; Method entries
;;;

(define code-table-lookup
  (letrec ((check-entry (lambda (entry types)
			  (if (null? types)
			      (and (not (struct? (car entry)))
				   entry)
			      (and (eq? (car entry) (car types))
				   (check-entry (cdr entry) (cdr types)))))))
    (lambda (code-table types)
      (cond ((null? code-table) #f)
	    ((check-entry (car code-table) types))
	    (else (code-table-lookup (cdr code-table) types))))))

(define (compute-cmethod methods types)
  (or (code-table-lookup (slot-ref (car methods) 'code-table) types)
      (let* ((method (car methods))
             (cmethod (compile-method methods types))
	     (entry (append types cmethod)))
	(slot-set! method 'code-table
		   (cons entry (slot-ref method 'code-table)))
	cmethod)))

;;;
;;; Compiling next methods into method bodies
;;;

;;; So, for the reader: there basic idea is that, given that the
;;; semantics of `next-method' depend on the concrete types being
;;; dispatched, why not compile a specific procedure to handle each type
;;; combination that we see at runtime. There are two compilation
;;; strategies implemented: one for the memoizer, and one for the VM
;;; compiler.
;;;
;;; In theory we can do much better than a bytecode compilation, because
;;; we know the *exact* types of the arguments. It's ideal for native
;;; compilation. A task for the future.
;;;
;;; I think this whole generic application mess would benefit from a
;;; strict MOP.

;;; Temporary solution---return #f if x doesn't refer to `next-method'.
(define (next-method? x)
  (and (pair? x)
       (or (eq? (car x) 'next-method)
	   (next-method? (car x))
	   (next-method? (cdr x)))))

;; Called by the `method' macro in goops.scm.
(define (compile-make-procedure formals specializers body)
  (and (next-method? body)
       (let ((next-method-sym (gensym " next-method"))
             (args-sym (gensym)))
         `(lambda (,next-method-sym)
            (lambda ,formals
              (let ((next-method (lambda ,args-sym
                                   (if (null? ,args-sym)
                                       ,(if (list? formals)
                                            `(,next-method-sym ,@formals)
                                            `(apply
                                              ,next-method-sym
                                              ,@(improper->proper formals)))
                                       (apply ,next-method-sym ,args-sym)))))
                ,@(if (null? body)
                      '((begin))
                      body)))))))

(define (compile-method methods types)
  (let ((make-procedure (slot-ref (car methods) 'make-procedure)))
    (if make-procedure
        (make-procedure
         (if (null? methods)
             (lambda args
               (no-next-method (method-generic-function (car methods)) args))
             (compute-cmethod (cdr methods) types)))
        (method-procedure (car methods)))))
