;;;-*- Mode: Lisp; Package: CONTAINERS -*-

#| simple-header

$Id: queues.lisp,v 1.5 2005/09/07 16:17:29 gwking Exp $

Copyright 1992 - 2004 Experimental Knowledge Systems Lab, 
University of Massachusetts Amherst MA, 01003-4610
Professor Paul Cohen, Director

Author: Gary King

DISCUSSION

|#
(in-package containers)

;;; ---------------------------------------------------------------------------
;;; Abstract Queue interface
;;;
;;; supports: enqueue (insert-item), dequeue (delete-first), empty!, 
;;; size, empty-p, first-item
;;; ---------------------------------------------------------------------------

(defclass* abstract-queue (initial-contents-mixin ordered-container-mixin)
  ())

(define-condition eksl-queue-empty (error)
                  ((message :initarg :message
                            :reader message))
  (:report (lambda (c stream)
             (format stream "~A" (message c)))))

;;; ---------------------------------------------------------------------------

(defmethod enqueue ((queue abstract-queue) item)
  (insert-item queue item))

(defmethod dequeue ((queue abstract-queue))
  (delete-first queue))

(defmethod empty! ((q abstract-queue))
  ;; Dequeue items until the queue is empty. Inefficient, but always works.
  (do ()
      ((empty-p q) q)
    (delete-first q))
  (values))

(defmethod first-item :before ((q abstract-queue))
  (error-if-queue-empty q "Tried to examine first-item from an empty queue."))

(defmethod delete-first :before ((q abstract-queue))
  (error-if-queue-empty q "Tried to dequeue from an empty queue."))

(defmethod error-if-queue-empty ((q abstract-queue) &optional
                                 (message "Cannot work with an empty queue")
                                 &rest rest)
  (when (empty-p q)
    (error message rest)))


;;; ---------------------------------------------------------------------------
;;; Priority Queues on 'arbitrary' containers
;;;
;;; The underlying container must support: insert-item, first-item
;;; delete-item, empty-p, empty!, size, find-item,
;;; delete-item and delete-item-if
;;; ---------------------------------------------------------------------------

(defclass* priority-queue-on-container (iteratable-container-mixin
                                          sorted-container-mixin
                                          findable-container-mixin
                                          concrete-container
                                          abstract-queue)
  ((container nil r))
  (:default-initargs 
    :container-type 'binary-search-tree))

;;; ---------------------------------------------------------------------------

(defmethod initialize-instance :around ((object priority-queue-on-container) &rest args 
                                        &key container-type &allow-other-keys)
  (remf args :container-type)
  (remf args :initial-contents)
  (setf (slot-value object 'container)
        (apply #'make-container container-type args))
  (call-next-method))

;;; ---------------------------------------------------------------------------

(defmethod insert-item ((q priority-queue-on-container) item)
  (insert-item (container q) item))

(defmethod delete-first ((q priority-queue-on-container))
  (let ((m (first-item (container q))))
    (delete-item (container q) m)
    (element m)))

(defmethod empty-p ((q priority-queue-on-container))
  (empty-p (container q)))

(defmethod empty! ((q priority-queue-on-container))
  (empty! (container q))
  (values))

(defmethod size ((q priority-queue-on-container))
  (size (container q)))

(defmethod first-item ((q priority-queue-on-container))
  (element (first-item (container q))))

(defmethod find-item ((q priority-queue-on-container) (item t))
  (let ((node (find-item (container q) item)))
    (when node (element node))))

;;; ---------------------------------------------------------------------------

(defmethod find-node ((q priority-queue-on-container) (item t))
  (find-node (container q) item))

;;; ---------------------------------------------------------------------------

(defmethod find-element ((q priority-queue-on-container) (item t))
  (find-element (container q) item))

;;; ---------------------------------------------------------------------------

(defmethod delete-item ((q priority-queue-on-container) (item t))
  (delete-item (container q) item))

;;; ---------------------------------------------------------------------------

(defmethod delete-node ((q priority-queue-on-container) (item t))
  (delete-node (container q) item))

;;; ---------------------------------------------------------------------------

(defmethod delete-element ((q priority-queue-on-container) (item t))
  (delete-element (container q) item))

;;; ---------------------------------------------------------------------------

(defmethod delete-item-if (test (q priority-queue-on-container))
  (delete-item-if test (container q)))

(defmethod iterate-nodes ((q priority-queue-on-container) fn)
  (iterate-nodes (container q) fn))

;;; ---------------------------------------------------------------------------

(defmethod iterate-elements ((q priority-queue-on-container) fn)
  (iterate-elements (container q) fn))


;;; ---------------------------------------------------------------------------
;;; Standard no frills queue
;;; ---------------------------------------------------------------------------

(defclass* basic-queue (abstract-queue iteratable-container-mixin 
                                         concrete-container)
  ((queue nil :accessor queue-queue)
   (indexer nil :accessor queue-header)))

;;; ---------------------------------------------------------------------------

;; Some semantically helpful functions
(defun front-of-queue (queue)
  (car (queue-header queue)))
(defun front-of-queue! (queue new)
  (setf (car (queue-header queue)) new))
(defsetf front-of-queue front-of-queue!)
(proclaim '(inline front-of-queue front-of-queue!))

(defun tail-of-queue (queue)
  (cdr (queue-header queue)))
(defun tail-of-queue! (queue new)
  (setf (cdr (queue-header queue)) new))
(defsetf tail-of-queue tail-of-queue!)
(proclaim '(inline tail-of-queue tail-of-queue!))

;;; ---------------------------------------------------------------------------

(defmethod insert-item ((q basic-queue) (item t))
  "Add an item to the queue."
  (let ((new-item (list item)))
    (cond ((empty-p q)
           (setf (queue-queue q) new-item
                 (queue-header q) (cons (queue-queue q) (queue-queue q))))
          (t
           (setf (cdr (tail-of-queue q)) new-item
                 (tail-of-queue q) new-item))))
  q)

;;; ---------------------------------------------------------------------------

(defmethod delete-first ((q basic-queue))
  (let ((result (front-of-queue q)))
    (setf (front-of-queue q) (cdr result)
          result (first result))
    
    ;; reset things when I'm empty
    (when (null (front-of-queue q))
      (empty! q))
    
    result))

;;; ---------------------------------------------------------------------------

(defmethod empty-p ((q basic-queue))
  (null (queue-header q)))

;;; ---------------------------------------------------------------------------

(defmethod iterate-nodes ((q basic-queue) fn)
  (let ((start (front-of-queue q)))
    (mapc fn start))
  (values q))

;;; ---------------------------------------------------------------------------

(defmethod size ((q basic-queue))
  ;;??slow
  (if (empty-p q)
    0
    (length (front-of-queue q))))

;;; ---------------------------------------------------------------------------

(defmethod first-item ((q basic-queue))
  "Returns the first item in a queue without changing the queue."
  (car (front-of-queue q)))

;;; ---------------------------------------------------------------------------

(defmethod empty! ((q basic-queue))
  "Empty a queue of all contents."
  (setf (queue-queue q) nil
        (queue-header q) nil)
  (values))

;;; ---------------------------------------------------------------------------

(defmethod delete-item ((queue basic-queue) item)
  (unless (empty-p queue)
    (cond ((eq item (first-item queue))
           (delete-first queue))
          ((eq item (car (tail-of-queue queue)))
           ;; expensive special case...
           (setf (queue-queue queue) (remove item (queue-queue queue))
                 (front-of-queue queue) (queue-queue queue)
                 (tail-of-queue queue) (last (front-of-queue queue))))
          (t
           (setf (queue-queue queue) (delete item (queue-queue queue)))))))


