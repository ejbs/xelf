;;; buffers.lisp --- emacsy worlds of gamey objects

;; Copyright (C) 2006-2013  David O'Toole

;; Author: David O'Toole dto@blocky.io
;; Keywords: 

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see %http://www.gnu.org/licenses/

(in-package :xelf)

(defparameter *combine-buffers-destructively* t)

(defblock buffer
  (name :initform nil)
  (buffer-name :initform "*untitled-buffer*")
  (variables :initform nil 
	     :documentation "Hash table mapping values to values, local to the current buffer.")
  (cursor :initform nil)
  (point :initform nil :documentation "The currently highlighted word.")
  (modified-p :initform nil)
  (followed-object :initform nil)
  (background-image :initform nil)
  (background-color :initform nil)
  (redraw-cursor :initform t)
  (category :initform :data)
  (x :initform 0)
  (y :initform 0)
  (paused :initform nil)
  (heading :initform 0.0)
  (height :initform 256)
  (width :initform 256)
  (depth :initform *z-far*)
  (layered :initform nil)
  (field-of-view :initform *field-of-view*)
  (was-key-repeat-p :initform nil)
  ;; objects and collisions
  (objects :initform nil :documentation "A hash table with all the buffer's objects.")
  (quadtree :initform nil)
  (quadtree-depth :initform 4)
  ;; viewing window 
  (window-x :initform 0)
  (window-y :initform 0)
  (window-z :initform 0)
  (window-x0 :initform nil)
  (window-y0 :initform nil)
  (window-z0 :initform nil)
  (horizontal-scrolling-margin :initform 1/4)
  (vertical-scrolling-margin :initform 1/4)
  (window-scrolling-speed :initform 5)
  (window-scale-x :initform 1)
  (window-scale-y :initform 1)
  (window-scale-z :initform 1)
  (projection-mode :initform :orthographic)
  (rewound-selection :initform nil)
  (future :initform nil)
  (future-steps :initform 32)
  (future-step-interval :initform 8)
  (default-events :initform nil)
		  ;; '(;;((:pause) :transport-toggle-play)
		    ;; ((:e :alt) :edit-word)
		    ;; ((:x :control) :exec)
		    ;; ((:d :control) :delete-word)
		    ;; ((:c :control) :copy-selected-word)
		    ;; ((:x :alt) :command-prompt)
		    ;; ((:g :control) :cancel)
		    ;; ((:c :alt) :clear-stack)
		    ;; ((:s :alt) :show-stack)
		    ;; ((:m :alt) :show-messages)
;		    ((:p :control) :paste)
;		    ((:return) :enter)
		    ;; ((:escape) :cancel)
;		    ((:f1) :help)
		    ;; ((:h :control) :help)
		    ;; ((:x :control) :edit-cut)
		    ;; ((:c :control) :edit-copy)
		    ;; ((:v :control) :edit-paste)
		    ;; ((:v :control :shift) :paste-here)
		    ;; ((:f9) :toggle-shell)
		    ;; ((:f12) :transport-toggle-play)
		    ;; ((:g :control) :escape)
		    ;; ((:d :control) :drop-selection)))
		    ;; ((:f12) :toggle-other-windows)
		    ;; ))
  ;; prototype control
  (excluded-fields :initform
		   '(:events :quadtree :click-start :click-start-block :drag-origin :drag-start :drag-offset :focused-block :shell :drag :hover :highlight 
		     ;; program objects are not saved:
		     :inputs)
		   :documentation "Don't serialize the menu bar.")
  (field-collection-type :initform :hash)
  ;; rectangle-select
  (region :initform nil)
  (region-start :initform nil)
  ;; dragging info
  already-failed
  (drag :initform nil 
  	:documentation "Block being dragged, if any.")
  (drag-button :initform nil)
  (hover :initform nil
	 :documentation "Block being hovered over, if any.")
  (highlight :initform nil
	     :documentation "Block being highlighted, if any.")
  (ghost :initform nil
	 :documentation "Dummy block to hold original place of currently dragged block onscreen.")
  (focused-block :initform nil
		 :documentation "Block having current input focus, if any.")
  (last-focus :initform nil)
  (click-start :initform nil
	      :documentation "A cons (X . Y) of widget location at moment of click.")
  (click-start-block :initform nil
		     :documentation "The block indicated at the beginning of a drag.")
  (drag-origin :initform nil
	       :documentation "The parent block originally holding the dragged block.")
  (object-p :initform nil
		 :documentation "When non-nil, the dragged object is in the buffer.")
  (drag-start :initform nil
	      :documentation "A cons (X . Y) of widget location at start of dragging.")
  (drag-offset :initform nil
	       :documentation "A cons (X . Y) of relative mouse click location on dragged block."))

(defun uniquify-buffer-name (name)
  (let ((n 1)
	(name0 name))
    (block naming
      (loop while name0 do
	(if (find-buffer name0 :noerror t)
	    (setf name0 (format nil "~A<~S>" name n)
		  n (1+ n))
	    (return-from naming name0))))))

(define-method buffer-file-name buffer ()
  (when %buffer-name
    (concatenate 'string %buffer-name ".xelf")))

;; (define-method buffer-name buffer ()
;;   (or %buffer-name (uniquify-buffer-name "*untitled-buffer*")))

(define-method begin-region buffer ()
  (setf %region-start (list (window-pointer-x) (window-pointer-y))))

(define-method update-region buffer ()
  (when %region-start
    (let ((x (window-pointer-x))
	  (y (window-pointer-y)))
      (destructuring-bind (x0 y0) %region-start
	;; always normalize it
	(setf %region
	      (list (min x x0)
		    (min y y0)
		    (abs (- x x0))
		    (abs (- y y0))))))))

(define-method end-region buffer ()
  (setf %region-start nil))
	
(define-method draw-region buffer ()
  (when (consp %region)
    (destructuring-bind (x y width height) %region
      (draw-box x y width height :color "gray60" :alpha (max 0.2 (+ 0.2 (sin (/ *updates* 2))))))))

(define-method clear-region buffer ()
  (setf %region nil %region-start nil))

(defun make-buffer-name (name)
  (uniquify-buffer-name (or name "*untitled*")))

(defmacro define-buffer (name &body body)
  `(defblock (,name buffer)
     ,@body))

(defmacro with-buffer (buffer &rest body)
  `(let* ((*buffer* (find-uuid ,buffer)))
     ,@body))

(define-method toggle-other-windows buffer ()
  (glass-toggle))

(define-method set-modified-p buffer (&optional (value t))
  (setf %modified-p value))

(defun buffer-modified-p (&optional (buffer (current-buffer)))
  (%modified-p buffer))

(defun selection ()
  (get-selection (current-buffer)))

(defun selected-object ()
  (let ((sel (selection)))
    (assert (consp sel))
    (first sel)))

(defun clear-selection ()
  (clear-halos (current-buffer))
  (clear-deleted-program-objects (current-buffer)))

(defun select-all ()
  (with-local-fields 
    (clear-halos (current-buffer))
    (loop for thing being the hash-values in 
					  (%objects (current-buffer))
	  do (make-halo thing))))

(define-method get-objects buffer ()
  (loop for object being the hash-values in (field-value :objects self)
	when (xelfp object) collect (find-object object)))

(defun z-sort (objects)
  (sort objects #'< :key #'%z))

(define-method maximum-z-value buffer ()
  (if (not (xelfp (current-buffer)))
      0
      (let ((z 0))
	(loop for object being the hash-values in (field-value :objects (current-buffer)) 
	      do (setf z (max z (field-value :z (find-object object)))))
	z)))
  ;; (let ((things (mapcar #'%z (get-objects self))))
  ;;   (if things 
  ;; 	(apply #'max things)
  ;; 	0)))

(define-method has-object buffer (thing)
  (with-local-fields
    (gethash (find-uuid thing) %objects)))

(define-method region-objects buffer ()
  (when %region
    (destructuring-bind (x y width height) %region
      (loop for thing being the hash-values of (field-value :objects self)
	    when (colliding-with-rectangle thing y x width height)
	      collect thing))))

(define-method select-region buffer ()
  (when %region
    (clear-selection)
    (dolist (each (region-objects self))
      (make-halo each))
    (clear-region self)))

(define-method destroy-region buffer ()
  (when %region
    (clear-selection)
    (prog1 nil
      (dolist (each (region-objects self))
	(destroy each)))))

(define-method destroy-selection buffer ()
  (prog1 nil (mapc #'destroy (selection))))

(define-method emptyp buffer ()
  (with-fields (objects) self
    (or (null objects)
	(zerop (hash-table-count objects)))))

(defmethod initialize ((self buffer) &key name)
  (setf (field-value :objects self) (make-hash-table :test 'equal))
  (when name
    (let ((buffer-name (make-buffer-name name)))
      (setf (field-value :buffer-name self) buffer-name)
      (add-buffer buffer-name self))))

(define-method rename buffer (name)
  (assert (stringp name))
  (when (find-buffer name :noerror t)
    (kill-buffer name))
  (add-buffer name self))

(defun point ()
  (%point (current-buffer)))

(defun set-point (word)
  (setf (%point (current-buffer)) word))

;; Defining and scrolling the screen viewing window

(defun window-y () (%window-y (current-buffer)))
(defun window-x () (%window-x (current-buffer)))

(define-method window-bounding-box buffer ()
  (values (cfloat %window-y)
	  (cfloat %window-x)
	  (cfloat (+ %window-x *gl-screen-width*))
	  (cfloat (+ %window-y *gl-screen-height*))))

;; (define-method bounding-box buffer ()
;;   (values (cfloat 0) (cfloat 0)
;; 	  (cfloat %height) (cfloat %width)))

(define-method move-window-to buffer (x y &optional z)
  (setf %window-x x 
	%window-y y)
  (when z (setf %window-z z)))

(define-method move-window-to-object buffer (object)
  (multiple-value-bind (top left right bottom) 
      (bounding-box object)
    (declare (ignore right bottom))
    (move-window-to 
     self 
     (max 0 (- left (/ *gl-screen-width* 2)))
     (max 0 (- top (/ *gl-screen-width* 2))))))

(define-method move-window-to-cursor buffer ()
  (when %cursor
    (move-window-to-object self %cursor)))

(define-method snap-window-to-object buffer (object)
  (multiple-value-bind (top left right bottom) 
      (bounding-box (find-object object))
    (declare (ignore right bottom))
    (move-window-to 
     self 
     (min (- %width (+ %window-x *gl-screen-width*))
	  (max 0 (- left (/ *gl-screen-width* 2))))
     (min (- %height (+ %window-y *gl-screen-height*))
	  (max 0 (- top (/ *gl-screen-width* 2)))))))

(define-method snap-window-to-cursor buffer ()
  (when %cursor
    (snap-window-to-object self %cursor)))

(define-method move-window buffer (dx dy &optional dz)
  (incf %window-x dx)
  (incf %window-y dy)
  (when dz (setf %window-dz dz)))

(define-method glide-window-to buffer (x y &optional z)
  (setf %window-x0 x)
  (setf %window-y0 y)
  (when z (setf %window-z z)))

(define-method glide-window-to-object buffer (object)
  (multiple-value-bind (top left right bottom) 
      (bounding-box (find-object object))
    (declare (ignore right bottom))
    (glide-window-to 
     self 
     (max 0 (- left (/ *gl-screen-width* 2)))
     (max 0 (- top (/ *gl-screen-width* 2))))))

(define-method glide-window-to-cursor buffer ()
  (when %cursor
    (glide-window-to-object self %cursor)))

(define-method follow-with-camera buffer (thing)
  (assert (or (null thing) (xelfp thing)))
  (setf %followed-object thing)
  (glide-window-to-object self %followed-object))

(define-method glide-follow buffer (object)
  (with-fields (window-x window-y width height) self
    (let ((margin-x (* %horizontal-scrolling-margin *gl-screen-width*))
	  (margin-y (* %vertical-scrolling-margin *gl-screen-height*))
	  (object-x (field-value :x object))
	  (object-y (field-value :y object)))
    ;; are we outside the "comfort zone"?
    (if (or 
	 ;; too far left
	 (> (+ window-x margin-x) 
	    object-x)
	 ;; too far right
	 (> object-x
	    (- (+ window-x *gl-screen-width*)
	       margin-x))
	 ;; too far up
	 (> (+ window-y margin-y) 
	    object-y)
	 ;; too far down 
	 (> object-y 
	    (- (+ window-y *gl-screen-height*)
	       margin-y)))
	;; yes. recenter.
	(glide-window-to self
			 (max 0
			      (min (- width *gl-screen-width*)
				   (- object-x 
				      (truncate (/ *gl-screen-width* 2)))))
			 (max 0 
			      (min (- height *gl-screen-height*)
				   (- object-y 
				      (truncate (/ *gl-screen-height* 2))))))))))

(define-method update-window-glide buffer ()
  (with-fields (window-x window-x0 window-y window-y0 window-scrolling-speed) self
    (labels ((nearby (a b)
	       (> window-scrolling-speed (abs (- a b))))
	     (jump (a b)
	       (if (< a b) window-scrolling-speed (- window-scrolling-speed))))
      (when (and window-x0 window-y0)
	(if (nearby window-x window-x0)
	    (setf window-x0 nil)
	    (incf window-x (jump window-x window-x0)))
	(if (nearby window-y window-y0)
	    (setf window-y0 nil)
	    (incf window-y (jump window-y window-y0)))))))

(define-method scale-window buffer (&optional (window-scale-x 1.0) (window-scale-y 1.0))
  (setf %window-scale-x window-scale-x)
  (setf %window-scale-y window-scale-y))

(define-method project-window buffer ()
  (ecase %projection-mode 
    (:orthographic (project-orthographically %layered))
    (:perspective (project-with-perspective :field-of-view %field-of-view :depth %depth)))
  (transform-window :x %window-x :y %window-y :z %window-z 
		    :scale-x %window-scale-x 
		    :scale-y %window-scale-y
		    :scale-z %window-scale-z))

;;; Transport control

(define-method transport-pause buffer ()
  (setf %paused t)
  (setf %rewound-selection
	(mapcar #'duplicate
		(get-selection self))))

(define-method transport-play buffer ()
  (setf %paused nil)
  (clear-future self)
  (mapc #'destroy (get-selection self))
  (dolist (each %rewound-selection)
    (add-object (current-buffer) each))
  (setf %rewound-selection nil))

(define-method transport-toggle-play buffer ()
  (if %paused 
      (transport-play self)
      (transport-pause self)))

(define-method show-future buffer ()
  (prog1 nil
    (let ((selection (get-selection self)))
      (let (future)
	(dolist (thing selection)
	  (remove-object self thing)
	  (let (trail)
	    (dotimes (i %future-steps)
	      (let ((ghost (duplicate thing)))
		(with-buffer self
		  (with-quadtree %quadtree
		    (add-object self ghost)
		    (assert (%quadtree-node ghost))
		    (dotimes (j (* i %future-step-interval))
		      (update ghost)
		      (run-tasks ghost)
		      (quadtree-collide ghost))))
		(remove-object self ghost)
		(push ghost trail)))
	    (push trail future))
	  (add-object self thing)
	  (make-halo thing))
	(setf %future future)))))

(define-method clear-future buffer ()
  (setf %future nil))

(define-method update-future buffer ()
  (when %future (show-future self)))

;;; The object layer holds the contents of the buffer.

(defvar *object-placement-capture-hook*)

(define-method add-object buffer (object0 &optional x y (z 0))
  (with-buffer self
    (let ((object (find-object object0)))
      (with-quadtree %quadtree
	;; (remove-thing-maybe self object)
	;; (assert (not (contains-object self object)))
	(let ((uuid (find-uuid object)))
	  (declare (simple-string uuid))
	(setf (gethash uuid %objects) uuid))
	(when (and (numberp x) (numberp y))
	  (setf (%x object) (cfloat x)
		(%y object) (cfloat y)))
	(when (numberp z)
	  (setf (%z object) (cfloat z)))
	(clear-saved-location object)
	(quadtree-insert-maybe object)
	(after-add-hook object)))))
      
(define-method remove-object buffer (object)
  (destroy-halo object)
  (with-buffer self (quadtree-delete-maybe object))
  (remhash (the simple-string (find-uuid object)) %objects))

(define-method remove-thing-maybe buffer (object)
  (with-buffer self
    (when (gethash (the simple-string (find-uuid object)) %objects)
      (remove-object self object))
    (when (%parent object)
      (unplug-from-parent object))))

(define-method add-block buffer (object &optional x y prepend)
  (remove-thing-maybe self object))

(define-method drop-block buffer (object x y)
  (add-object self object)
  (move-to object x y))

(define-method drop-object buffer (object &optional x y z)
  (with-quadtree (field-value :quadtree self)
    (add-object self (find-object object))
    (when (and (numberp x) (numberp y))
      (move-to object x y (or z 1)))
    (after-drop-hook (find-object object))))

(define-method finish-drag nil ())

(define-method drop-selection buffer ()
  (dolist (each (get-selection self))
    (drop-object self each)))

(define-method add-at-pointer buffer (object)
  (layout object)
  (add-block self object 
	      (window-pointer-x) 
	      (- (window-pointer-y) (%height object))
	      :prepend)
  (focus-on self object))

(define-method contains-object buffer (object)
  (gethash (the simple-string (find-uuid object))
	   %objects))

(define-method destroy-block buffer (object)
  (remhash (the simple-string (find-uuid object)) %objects))

;;; Buffer-local variables

(define-method initialize-variables-maybe buffer () 
  (when (null %variables) 
    (setf %variables (make-hash-table :test 'equal))
    (setf (gethash "BUFFER" %variables) self)))

(define-method set-variable buffer (var value)
  (initialize-variables-maybe self)
  (setf (gethash var %variables) value))

(define-method get-variable buffer (var)
  (initialize-variables-maybe self)
  (gethash var %variables))

(defun buffer-variable (var-name)
  (get-variable (current-buffer) var-name))

(defun set-buffer-variable (var-name value)
  (set-variable (current-buffer) var-name value))

(defsetf buffer-variable set-buffer-variable)

(defmacro with-buffer-variables (vars &rest body)
  (labels ((make-clause (sym)
	     `(,sym (buffer-variable ,(make-keyword sym)))))
    (let* ((symbols (mapcar #'make-non-keyword vars))
	   (clauses (mapcar #'make-clause symbols)))
      `(symbol-macrolet ,clauses ,@body))))

;;; About the cursor. deprecated.
			        
(define-method get-cursor buffer ()
  (find-object %cursor))

(defun cursor ()
  (find-object (get-cursor (current-buffer))))

(defun cursorp (thing)
  (object-eq thing (cursor)))

(define-method set-cursor buffer (cursor)
  (setf %cursor (find-uuid cursor)))
  ;; (unless (contains-object self cursor)
  ;;   (add-object self cursor)))

;;; Configuring the buffer's space and its quadtree indexing

(defparameter *buffer-bounding-box-scale* 1.01
  "Actual size of bounding box used for quadtree. The buffer is bordered
around on all sides by a thin margin designed to prevent objects near
the edge of the universe piling up into the top quadrant and causing
slowdown. See also quadtree.lisp")

(define-method install-quadtree buffer ()
  ;; make a box with a one-percent margin on all sides.
  ;; this margin helps edge objects not pile up in quadrants
  (let ((box (multiple-value-list
	      (scale-bounding-box 
	       (multiple-value-list (bounding-box self))
	       *buffer-bounding-box-scale*))))
    (with-fields (quadtree) self
      (setf quadtree (build-quadtree 
		      box 
		      (or %quadtree-depth 
			  *default-quadtree-depth*)))
      (assert quadtree)
      (let ((objects (get-objects self)))
	(when objects
	  (quadtree-fill objects quadtree))))))

(define-method resize buffer (new-width new-height)
  (assert (and (plusp new-height)
	       (plusp new-width)))
  (with-fields (height width quadtree objects) self
    (setf height new-height)
    (setf width new-width)
    (when quadtree
      (install-quadtree self))))

(define-method resize-to-background-image buffer ()
  (when %background-image
    (resize self (image-width %background-image) (image-height %background-image))))

(define-method reset buffer ())

(define-method trim buffer ()
  (prog1 self
    (let ((objects (get-objects self)))
      (when objects
	(with-fields (quadtree height width) self
	  ;; adjust bounding box so that all objects have positive coordinates
	  (multiple-value-bind (top left right bottom)
	      (find-bounding-box objects)
	    ;; resize the buffer so that everything just fits
	    (setf %x 0 %y 0)
	    (resize self (- right left) (- bottom top))
	    ;; move all the objects
	    (dolist (object (mapcar #'find-object objects))
	      (with-fields (x y) object
		(with-quadtree quadtree
		  (move-to object (- x left) (- y top)))))))))))

;;; Cut and paste

(define-method get-selection buffer ()
  (let ((all (append (get-objects self) %inputs)))
   (remove-if-not #'%halo all)))

(defun copy (&optional (self (current-buffer)) objects0)
  (let ((objects (or objects0 (get-selection self))))
    (clear-halos self)
    (when objects
      (destroy-maybe *clipboard*)
      (setf *clipboard* (new 'buffer))
      (dolist (object objects)
	(let ((duplicate (duplicate-safely object)))
	  ;; don't keep references to anything in the (current-buffer)
	  (clear-buffer-data duplicate)
	  (add-object *clipboard* duplicate))))))

(defun cut (&optional (self (current-buffer)) objects0)
  (with-buffer self
    (let ((objects (or objects0 (get-selection self))))
      (when objects
	(clear-halos self)
	(destroy-maybe *clipboard*)
	(setf *clipboard* (new 'buffer))
	(dolist (object objects)
	  (with-quadtree (%quadtree self)
	    (remove-thing-maybe self object))
	  (add-object *clipboard* object))))))

(defun paste-from (self source &optional (dx 0) (dy 0))
  (dolist (object (mapcar #'duplicate-safely (get-objects (find-object source))))
    (with-fields (x y) object
      (clear-buffer-data object)
      (with-buffer self
	(with-quadtree (%quadtree self)
	  (add-object self object)
	  (move-to object (+ x dx) (+ y dy)))))))
  
(defun paste-into (self source &optional (dx 0) (dy 0))
  (paste-from self source dx dy)
  (destroy (find-object source)))

(defun paste (&optional (self (current-buffer)) (dx 0) (dy 0))
  (paste-from self *clipboard* dx dy))
  
(defun paste-at-pointer (&optional (self (current-buffer)))
  (let ((temp (new 'buffer)))
    (paste-from temp *clipboard*)
    (send :trim temp)
    (paste-from self temp
		(window-pointer-x)
		(window-pointer-y))))

(define-method paste-here buffer ()
  (paste-at-pointer self))

(define-method edit-cut buffer ()
  (cut))

(define-method edit-paste buffer ()
  (paste))

(define-method edit-copy buffer ()
  (copy))

;; (defun paste-as-new-buffer ()
;;   (let ((temp (new 'buffer "*new-buffer*")))
;;     (paste-from temp *clipboard*)
;;     (trim temp)
;;     (switch-to-buffer temp)))

;; (define-method paste-cut 

;;; Algebraic operations on buffers and their contents

(defvar *buffer-prototype* 'xelf:buffer)

(defmacro with-buffer-prototype (buffer &rest body)
  `(let ((*buffer-prototype* (find-super ,buffer)))
     ,@body))

(define-method adjust-bounding-box-maybe buffer ()
  (if (emptyp self)
      self
      (let ((objects-bounding-box 
	      (multiple-value-list 
	       (find-bounding-box (get-objects self)))))
	(destructuring-bind (top left right bottom)
	    objects-bounding-box
	  ;; are all the objects inside the existing box?
	  (prog1 self
	    (unless (bounding-box-contains 
		     (multiple-value-list (bounding-box self))
		     objects-bounding-box)
	      (resize self right bottom)))))))

      ;; (let ((objects (get-objects self)))
      ;; 	(when objects
      ;; 	  (let ((objects-bounding-box 
      ;; 		  (multiple-value-list 
      ;; 		   (find-bounding-box objects))))
      ;; 	    (destructuring-bind (top left right bottom)
      ;; 		objects-bounding-box
      ;; 	      ;; are all the objects inside the existing box?
      ;; 	      (prog1 self
      ;; 		(unless (bounding-box-contains 
      ;; 			 (multiple-value-list (bounding-box self))
      ;; 			 objects-bounding-box)
      ;; 		  (resize self right bottom)))))))))

(defmacro with-new-buffer (&body body)
  `(with-buffer (clone *buffer-prototype*) 
     ,@body
     (adjust-bounding-box-maybe (current-buffer))))

(defun translate (buffer dx dy)
  (when buffer
    (assert (and (numberp dx) (numberp dy)))
    (with-new-buffer 
      (paste-from (current-buffer) buffer dx dy)
      (destroy buffer))))

(define-method destroy buffer ()
  (with-fields (objects inputs) self
    (loop for thing being the hash-keys of objects do
      (destroy (find-object thing))
      (remhash (the simple-string thing) objects))
    (mapc #'destroy-maybe inputs)
    (mapc #'destroy-maybe %tasks)
    (setf %inputs nil)
    (setf %quadtree nil)
    (call-next-method self)))

(defun combine (buffer1 buffer2)
  (with-new-buffer 
    (when (and buffer1 buffer2)
      (let ((all-objects (nconc (get-objects buffer1)
				(get-objects buffer2))))
	(dolist (object all-objects)
	  (add-object (current-buffer) 
		      (duplicate-safely object)))
	(destroy buffer1)
	(destroy buffer2)
	(current-buffer)))))

(define-method scale buffer (sx &optional sy)
  (let ((objects (get-objects self)))
    (dolist (object objects)
      (with-fields (x y width height) object
	(move-to object (* x sx) (* y (or sy sx)))
	(resize object (* width sx) (* height (or sy sx))))))
  (trim self))

(defun vertical-extent (buffer)
  (if (or (null buffer)
	  (emptyp buffer))
      0
      (multiple-value-bind (top left right bottom)
	  (bounding-box buffer)
	(declare (ignore left right))
	(- bottom top))))

(defun horizontal-extent (buffer)
  (if (or (null buffer)
	  (emptyp buffer))
      0
      (multiple-value-bind (top left right bottom)
	  (bounding-box buffer)
	(declare (ignore top bottom))
	(- right left))))
  
(defun arrange-below (&optional buffer1 buffer2)
  (when (and buffer1 buffer2)
    (combine buffer1
	     (translate buffer2
			0 
			(field-value :height buffer1)))))

(defun arrange-beside (&optional buffer1 buffer2)
  (when (and buffer1 buffer2)
    (combine buffer1 
	     (translate buffer2
			(field-value :width buffer1)
			0))))

(defun stack-vertically (&rest buffers)
  (reduce #'arrange-below buffers :initial-value (with-new-buffer)))

(defun stack-horizontally (&rest buffers)
  (reduce #'arrange-beside buffers :initial-value (with-new-buffer)))

(define-method flip-horizontally buffer ()
  (let ((objects (get-objects self)))
    (dolist (object objects)
      (with-fields (x y) object
	(move-to object (- x) y))))
  ;; get rid of negative coordinates
  (trim self))

(define-method flip-vertically buffer ()
  (let ((objects (get-objects self)))
    (dolist (object objects)
      (with-fields (x y) object
	(move-to object x (- y)))))
  (trim self))

(define-method mirror-horizontally buffer ()
  (stack-horizontally 
   self 
   (flip-horizontally (duplicate self))))

(define-method mirror-vertically buffer ()
  (stack-vertically 
   self 
   (flip-vertically (duplicate self))))

(defun with-border (border buffer)
  (with-fields (height width) buffer
    (with-new-buffer 
      (paste-from (current-buffer) (find-object buffer) border border)
      (destroy (find-object buffer))
      (resize (current-buffer)
	      (+ width (* border 2))
	      (+ height (* border 2))))))

;;; The Program is an optional layer of objects on top of the buffer

(define-method add-shell-maybe buffer (&optional force)
  (when (or force (null *shell*))
    (setf *shell* 
	  (new 'shell))))

(define-method enter-shell buffer ()
  (when (not *shell-open-p*)
    (add-shell-maybe self)
    (setf %last-focus %focused-block)
    ;; (focus-on self (shell-prompt) :clear-selection nil)
    (when (null *shell-open-p*) (setf %was-key-repeat-p (key-repeat-p)))
    (setf *shell-open-p* t)
    (enable-key-repeat)))
  
(defun shell-open-p () *shell-open-p*)

(define-method command-prompt buffer () 
  (enter-shell self)
  (focus-on self (shell-prompt) :clear-selection nil))

(define-method exit-shell buffer ()
  (when *shell-open-p*
    ;; (add-shell-maybe self)
    (setf *shell-open-p* nil)
    (focus-on self %last-focus :clear-selection nil)
    (setf %last-focus nil)
    (unless %was-key-repeat-p 
      (disable-key-repeat))
    (setf %was-key-repeat-p nil)))

(define-method toggle-shell buffer ()
  (if *shell-open-p* 
      (exit-shell self)
      (enter-shell self)))

(define-method grab-focus buffer ())

(define-method layout-program-objects buffer ()
  (mapc #'layout %inputs))

(define-method update-program-objects buffer ()
  (mapc #'update %inputs)
  (when (xelfp *shell*) (update *shell*)))

(define-method draw-program-objects buffer ()
  (with-buffer self
    (with-fields (drag-start drag focused-block
			 highlight inputs hover point
			 ghost prompt) self
      ;; now start drawing the program objects
      (mapc #'draw inputs)
      ;; draw any future
      (when %future
	(let ((*image-opacity* 0.2))
	  (dolist (trail %future)
	    (mapc #'draw trail))))
      ;; during dragging we draw the dragged block.
      (when drag 
	(layout drag)
	(when (field-value :parent drag)
	  (draw-ghost ghost))
	;; also draw any hover-over highlights 
	;; on objects you might drop stuff onto
	(when hover 
	  (draw-hover (find-object hover)))
	(draw drag))
      (when (xelfp *shell*)
	(draw *shell*))
      ;; (when (xelfp %cursor)
      ;; 	(draw-cursor %cursor))
      ;; draw focus
      (when focused-block
	(when (xelfp focused-block))
	(draw-focus (find-object focused-block))))))
      ;; 
      ;; ;; (when *shell*
      ;; ;; 	(draw-focus (shell-prompt)))
      ;; ;; (when highlight
      ;; ;; 	(draw-highlight highlight))
      ;; (when (and point (read-only-p point))
      ;; 	(draw-point point)))))

(define-method draw-programs buffer ())

(define-method after-draw-object buffer (object))

(define-method draw-object-layer buffer ()
  (multiple-value-bind (top left right bottom) (window-bounding-box self)
    (loop for object being the hash-keys of %objects do
      ;; only draw onscreen objects
      (when (colliding-with-bounding-box (find-object object) top left right bottom)
	(draw (find-object object))
	(after-draw-object self (find-object object))))))

(define-method draw buffer ()
  (with-buffer self
    (with-field-values (objects width focused-block height
				background-image background-color) self
      (unless %parent 
	(project-window self))
      ;; (when %parent 
      ;; 	(gl:push-matrix)
      ;; 	(gl:translate %x %y 0))
      ;; draw background 
      (if background-image
	  (draw-image background-image 0 0 :height height :width width)
	  (when background-color
	    (draw-box 0 0 width height
		      :color background-color)))
      ;; now draw the object layer
      (draw-object-layer self)
      ;; possibly redraw cursor to ensure visibility.
      ;; (when (and (xelfp %cursor) %redraw-cursor)
      ;; 	(draw (find-object %cursor)))
      ;; draw region if needed
      (when %region (draw-region self))
      ;; draw any overlays
      (if *shell-open-p* 
      	  (draw-program-objects self)
      	  (draw-programs self)))))
      ;; ;; draw focus
      ;; (when focused-block
      ;; 	(assert (xelfp focused-block))
      ;; 	(draw-focus focused-block))
      ;; )))
      ;; (if %parent
      ;; 	  (gl:pop-matrix)
      ;; possibly draw shell
      ;; (if *shell-open-p* 
      ;; 	  (draw-shell-objects self)
      ;; 	  (draw-shells self)))))
  
;;; Simulation update

(define-method clear-deleted-program-objects buffer ()
  ;; clean up any deleted objects
  (when (not (xelfp %cursor)) (setf %cursor nil))
  (when (not (xelfp %drag)) (setf %drag nil))
  (when (not (xelfp %point)) (setf %point nil))
  (when (not (xelfp %drag-origin)) (setf %drag-origin nil))
  (when (not (xelfp %hover)) (setf %hover nil))
  (when (not (xelfp %focused-block)) (setf %focused-block nil))
  (when (not (xelfp %last-focus)) (setf %last-focus nil)))

(define-method clear-deleted-objects buffer ()
  (loop for object being the hash-keys of %objects 
	do (unless (xelfp object) (remhash (the simple-string object) %objects))))

(define-method update-window-movement buffer ()
  (with-field-values (followed-object drag cursor) self
    (let ((thing (or followed-object
		     (when (holding-shift) drag)
		     cursor)))
      (when (xelfp thing)
	(glide-follow self thing)
	(update-window-glide self)))))

(define-method update buffer ()
  (with-field-values (objects drag cursor) self
    ;; clean up after destroyed shell if needed
    (when (and *shell* (not (xelfp *shell*)))
      (setf *shell-open-p* nil)
      (setf %inputs (delete *shell* %inputs :test 'equal)))
    ;; build quadtree if needed
    (when (null %quadtree)
      (install-quadtree self))
    (assert %quadtree)
    (update-window-movement self)
    (unless %paused
      (with-buffer self
	;; enable quadtree for collision detection
	(with-quadtree %quadtree
	  ;; possibly run the objects
	  (loop for object being the hash-keys in objects do
	    (if (xelfp object) 
		(progn 
		  (update (find-object object))
		  ;; might have been destroyed during update.
		  (when (xelfp object)
		    (run-tasks (find-object object))))
		(remhash (the simple-string object) %objects)))
	  ;; detect collisions
	  (loop for object being the hash-values in objects do
	    (when (xelfp object)
	      (unless (eq :passive (field-value :collision-type object))
		(quadtree-collide (find-object object))))))))
    ;; now outside the quadtree,
    ;; possibly update the program layer
    (with-buffer self
      (when *shell-open-p*
	(with-quadtree nil
	  (layout self)
	  (layout-program-objects self)
	  (update-program-objects self)
	  (when *shell* (update *shell*))
	  (clear-deleted-program-objects self))))))
    
(define-method evaluate buffer ()
  (prog1 self
    (with-buffer self
      (mapc #'evaluate %inputs))))

(define-method layout buffer ()
  ;; take over the entire GL window
  (with-buffer self
    ;; (setf %x 0 %y 0)
	  ;; %width *gl-screen-width* 
	  ;; %height *gl-screen-height*)
    (mapc #'layout %inputs)
    (when (xelfp *shell*)
      (layout *shell*))))
  
(define-method handle-event buffer (event)
  (clear-deleted-program-objects self)
  (with-field-values (cursor quadtree focused-block) self
    (with-buffer self
      (or (call-next-method self event)
	  (let ((thing 
		  focused-block))
		  ;; (if *shell-open-p* 
		  ;;     focused-block
		  ;;     cursor)))
	      (prog1 t 
		(when thing 
		  (with-quadtree quadtree
		    (handle-event (find-object thing) event)
		    (clear-deleted-program-objects self)
		    ))))))))

;;; Hit testing

(define-method hit buffer (x y)
  ;; return self no matter where mouse is, so that we get to process
  ;; all the events.
  (declare (ignore x y))
  self)

(define-method z-sorted-objects buffer ()
  (nreverse (z-sort (get-objects self))))

(define-method hit-inputs buffer (x y)
  "Recursively search the blocks in this buffer for a block
intersecting the point X,Y. We have to search the top-level blocks
starting at the end of `%INPUTS' and going backward, because the
blocks are drawn in list order (i.e. the topmost blocks for
mousing-over are at the end of the list.) The return value is the
block found, or nil if none is found."
  ;; remove any dead objects
  (setf %inputs (remove-if-not #'xelfp %inputs))
  (with-buffer self 
    (with-quadtree %quadtree
      (labels ((try (b)
		 (when b
		   (hit (find-object b) x y))))
	;; check shell and inputs first
	(let* ((object-p nil)
	       (result 
		 (or 
		  (when (and *shell-open-p* (xelfp *shell*))
		    (try *shell*))
		  (let ((parent 
			  (find-if #'try 
				   %inputs
				   :from-end t)))
		    (when parent
		      (try parent)))
		  ;; try buffer objects
		  (block trying
		    (dolist (object (z-sorted-objects self))
		      (let ((result (try object)))
			(when result 
			  (setf object-p t)
			  (return-from trying result))))))))
	  (values result object-p))))))
  
(defparameter *minimum-drag-distance* 6)
  
(define-method clear-halos buffer ()
  (mapc #'destroy-halo (get-objects self)))

(define-method focus-on buffer (block &key (clear-selection t))
  (clear-deleted-program-objects self)
  ;; possible to pass nil
  (with-fields (focused-block) self
    (with-buffer self
      (let ((last-focus focused-block))
	(if (null block)
	    (progn (when last-focus (lose-focus (find-object last-focus)))
		   (setf focused-block nil))
	    ;; don't do this for same block
	    (when (not (object-eq last-focus block))
	      ;; there's going to be a new focused block. 
	      ;; tell the current one it's no longer focused.
	      (when (and clear-selection last-focus)
		(lose-focus (find-object last-focus)))
	      ;; now set up the new focus (possibly nil)
	      (setf focused-block (when block 
				    (find-uuid 
				     (pick-focus (find-object block)))))
	      ;; clean up if object destroyed itself after losing focus
	      (when (and last-focus (not (xelfp last-focus)))
		(setf last-focus nil))
	      ;; now tell the block it has focus, but only if not the same
	      (when (if last-focus 
			(not (object-eq last-focus focused-block))
			t)
		(focus (find-object block)))))))))

(define-method begin-drag buffer (mouse-x mouse-y block)
  (with-fields (drag drag-origin inputs drag-start ghost drag-offset) self
    (when (null ghost) (setf ghost (new 'xblock)))
    (with-buffer self
      (setf drag (as-drag block mouse-x mouse-y))
      (setf drag-origin (find-parent drag))
      (when drag-origin
	  ;; parent might produce a new object
	(unplug-from-parent block))
      (let ((dx (field-value :x block))
	    (dy (field-value :y block))
	    (dw (field-value :width block))
	    (dh (field-value :height block)))
	(with-fields (x y width height) ghost
	  ;; remember the relative mouse coordinates from the time the
	  ;; user began dragging, so that the block being dragged is not
	  ;; simply anchored with its top left corner located exactly at
	  ;; the mouse pointer.
	  (let ((x-offset (- mouse-x dx))
		(y-offset (- mouse-y dy)))
	    (when (null drag-start)
	      (setf x dx y dy width dw height dh)
	      (setf drag-start (cons dx dy))
	      (setf drag-offset (cons x-offset y-offset)))))))))

(define-method drag-fail buffer (x y object))

(define-method drag-maybe buffer (x y)
  ;; require some actual mouse movement to initiate a drag
  (with-buffer self
    (with-fields (focused-block drag-button click-start click-start-block) self
      (when click-start
	(destructuring-bind (x1 . y1) click-start
	  (when (and (xelfp focused-block) (xelfp click-start-block)
		   (> (distance x y x1 y1)
		      *minimum-drag-distance*))
	      (if (can-pick (find-object click-start-block))
		  (let ((drag 
			  (if (and drag-button (= 3 drag-button))
			      ;; right-drag means "grab whole thing"
			      (topmost (find-object click-start-block) )
			      (pick (find-object click-start-block)))))
		    (when drag 
		      (begin-drag self x y (find-object drag))
		      ;; clear click data
		      (setf click-start nil)
		      (setf click-start-block nil)))
		  ;; signal any failure to pick
		  (unless %already-failed
		    (setf %already-failed t)
		    (drag-fail self (find-object click-start-block)
			       x y)))))))))

(define-method drag-candidate buffer (drag x y)
  (declare (ignore drag))
  (hit-inputs self x y))

(define-method handle-point-motion buffer (mouse-x mouse-y)
  (with-fields (inputs hover highlight click-start drag-offset quadtree
		       region-start region
		       drag-start drag) self
    (with-buffer self
      (when region-start
	(update-region self))
      (with-quadtree quadtree
	(setf hover nil)
	(drag-maybe self mouse-x mouse-y)
	(if drag
	    ;; we're in a mouse drag.
	    (destructuring-bind (ox . oy) drag-offset
	      (let ((target-x (- mouse-x ox))
		    (target-y (- mouse-y oy)))
		(let ((candidate (drag-candidate self drag target-x target-y)))
		  ;; obviously we dont want to plug a block into itself.
		  (setf hover (if (object-eq drag candidate) nil
				  (find-uuid candidate)))
		  ;; keep moving along with the mouse
		  (drag drag target-x target-y))))
	    ;; not dragging, just moving
	    (progn
	      (setf highlight (find-uuid (hit-inputs self mouse-x mouse-y)))))))))
    ;; (when (null highlight)
  ;;   (when *shell*
  ;;     (with-buffer self (close-menus *shell*))))))))

(define-method press buffer (x y &optional button)
  (with-buffer self
    (with-fields (click-start drag-button click-start-block
			      region-start region focused-block) self
      ;; region select
      (if (holding-shift)
	  (begin-region self)
	  ;; or, regular select.
	  ;; now find what we're touching
	  (progn
	    (multiple-value-bind (block object-p)
		(hit-inputs self x y)
	      (setf %object-p object-p)
	      (if (null block)
		  (focus-on self nil)
		  ;; (when *shell-open-p*
		  ;; 	(exit-shell self)))
		  (progn 
		    (setf click-start (cons x y))
		    (setf click-start-block (find-uuid block))
		    (setf drag-button button)
		    ;; now focus; this might cause another block to be
		    ;; focused, as in the case of the Shell
		    (focus-on self block)))))))))
  
  (define-method clear-drag-data buffer ()
    (setf %drag-start nil
	  %drag-offset nil
	  %object-p nil
	%drag-origin nil
	%drag-button nil
	%drag nil
	%hover nil
	%highlight nil
	%last-focus nil
	%click-start-block nil
	%click-start nil))
  
(define-method release buffer (x y &optional button)
  (with-buffer self
    (with-fields 
	(drag-offset drag-start hover drag quadtree click-start drag-button
		     region-start region click-start-block drag-origin already-failed
		     focused-block) self
      (setf already-failed nil)
      (end-region self)
      (select-region self)
      (if drag
	  ;; we're dragging
	  (destructuring-bind (x0 . y0) drag-offset
	    (setf drag-button nil)
	    (let ((drag-parent (get-parent drag))
		  (drop-x (- x x0))
		  (drop-y (- y y0)))
	      (if (not (can-escape drag))
		  ;; put back in halo or wherever
		  (when drag-origin 
		    (add-block drag-origin drag drop-x drop-y))
		  ;; ok, drop. where are we dropping?
		  (progn 
		    (if (and hover (will-accept (find-object hover) 
						(find-object drag)))
			;; drop into container
			(accept (find-object hover) (find-object drag))
			;; drop onto map
			(with-quadtree quadtree
			  (drop-object self drag drop-x drop-y)))
		    (finish-drag drag)))))
	  ;;
	  ;; we were clicking instead of dragging
	  (progn
	    ;; clicks that don't hit an object are sent to self
	    ;; (if you hold shift, they are ALWAYS sent to buffer)
	    (let ((it (if (holding-shift) self
			  (find-object (or focused-block self) :noerror))))
	      (when (xelfp it)
		(with-buffer self 
		  (cond
		    ;; right click and control click are equivalent
		    ((or (= button 3)
			 (and (holding-control) (= button 1)))
		     (alternate-tap it x y))
		    ;; scroll wheel (middle) click and shift click are equivalent
		    ((or (= button 2)
			 (and (holding-shift) (= button 1)))
		     (scroll-tap it x y))
		    ;; vertical scrolling with mousewheel
		    ((= button 4)
		     (scroll-up it))
		    ((= button 5)
		     (scroll-down it))
		    ;; horizontal scrolling with shift-mousewheel
		    ((and (= button 4)
			  (holding-shift))
		     (scroll-left it))
		    ((and (= button 5)
			  (holding-shift))
		     (scroll-right it))
		    ;; plain old click
		    (t 
		     (tap it x y)))))
	      ;;(select self focused-block))
	      (setf click-start nil))))
      ;; clean up bookeeping
      (clear-drag-data self))))

;; SHIFT-click actions for buffers
  
(define-method tap buffer (x y) ()
  (clear-region self))

(define-method alternate-tap buffer (x y)
  (let ((entry (new 'expression)))
    (add-at-pointer self entry)))
;    (setf %point entry)))

(define-method scroll-tap buffer (x y))

(define-method scroll-up buffer ())
(define-method scroll-down buffer ())
(define-method scroll-left buffer ())
(define-method scroll-right buffer ())

(define-method tab buffer (&optional backward)
  (when %focused-block
    (with-buffer self
      (tab %focused-block backward))))

(define-method backtab buffer ()
  (tab self :backward))
  
(define-method exec buffer ()
  (when (and %point
	     (%value %point))
    (execute (list (%value %point)))))

(define-method delete-word buffer ())

(define-method copy-selected-word buffer ()
  (when %point 
    (add-at-pointer self (duplicate-phrase %point))))

(define-method edit-word buffer ()
  (when %point (start-editing %point)))

(define-method cancel buffer ()
  (when %point (cancel-editing %point)))

(define-method escape buffer ()
  (exit-shell self))

(define-method show-stack buffer ()
  (notify (format nil "~S" *stack*)))

(define-method show-messages buffer ()
  (notify-message (recent-messages 6)))

(define-method clear-stack buffer ()
  (setf *stack* nil)
  (notify "Stack cleared."))

;; (define-method enter buffer ()
;;   (if (xelfp %point)
;;       (evaluate-here-and-die %point)
;;       (setf %point nil)))

(define-method start buffer ()
  (with-buffer self
    (unless (emptyp self)
      (trim self))
    (start-alone (find-object self))))

(defun on-screen-p (thing)
  (contained-in-bounding-box 
   thing
   (multiple-value-list (window-bounding-box (current-buffer)))))

;;; Serialization of buffers

(define-method before-serialize buffer ()
  (clear-halos self))

(define-method after-deserialize buffer ()
  (after-deserialize%super self)
  (when %buffer-name (add-buffer %buffer-name self))
  (clear-drag-data self)
  (clear-deleted-program-objects self)
  ;; (clear-deleted-objects self)
  (add-shell-maybe self :force))

;;; Help

(defparameter *help-message*
"Welcome to Xelf. 

Left-click-and-drag to move objects. Right-click objects to select
them, which opens a \"halo menu\" with operation handles.

Right click multiple objects to select. Use the Move handle to move
multiple objects.  Destroy handle deletes objects.  Lambda handle
executes objects. 

Alt-X to type in a Lisp command in the \"shell\", or right-click
the background to create an object by typing, then press <return>.

Other keybindings:

Copy: Control-C    Cut:  Control-X    Paste: Control-V
Paste at pointer: Shift-Control-V
Toggle shell view: F9     Pause/unpause: F12

See sidebar for more commands to try. 

Try enlarging the window for better results.
")

(define-method help buffer ()
  (let ((help (new 'text *help-message*)))
    (add-object self help)
    (move-to help 20 20)))

;;; buffers.lisp ends here
