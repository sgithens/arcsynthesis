(in-package #:arc-12)

;; *lights* LightManager

;; (defclass light-manager () ()
;;   )

(defclass per-light ()
  ((camera-space-light-pos :initform (glm:vec4 0.0)) ; vec4
   (light-intensity :initform (glm:vec4 0.5))))	     ; vec4

(defconstant +number-of-lights+ 4)

(defclass light-block ()
  ((ambient-intensity :initform (glm:vec4 .5) :accessor ambient-intensity) ; vec4
   (light-attenuation :initform 1.0 :accessor light-attenuation)	   ; float
   ;; "padding 3" is taken care of in the AS-GLARR method!
   (lights :initform
	   (loop for i below +number-of-lights+
	      :collect (make-instance 'per-light))
	   :accessor lights)))

;; use gl::array-byte-size for quick tests
(defgeneric as-glarr (obj)
  (:documentation "Return a gl-array representation of the object."))

;; this will be an ugly hack setting just magic-number the padding[3]
(defmethod as-glarr ((lb light-block))
  (let (;;light-block
	(ai (ambient-intensity lb))
	(la (vector (light-attenuation lb)))
	;; padding[3]:
	(padding (make-array 3 :element-type 'single-float))
	;;per-light
	(lights
	 (apply #'concatenate 'vector
		(loop for per-light-obj in (lights lb) collect
		     (concatenate 'vector
				  (slot-value per-light-obj 'camera-space-light-pos)
				  (slot-value per-light-obj 'light-intensity)))))
	(data))
    (setf data (concatenate 'vector
			    ai la padding lights))
    ;; data stored. building the gl-array:
    (arc:create-gl-array-from-vector data)))



;;; new approach to (gl:buffer-sub-data 
;; TODO: if heavy memory allocation consumes ram too fast then put a gl-array
;; slot into the light-block class and let AS-GLARR update and return it!
(defun light-block-test-array ()
  ;; NEXT-TODO: with-foreign-object automatically frees the pointer!
  ;; look up its implementation and cffi:with-foreign-pointer also read up a bit
  ;; on what freeing pointer can mean and especially how gl:array are allocated.
  ;; The most convenient solution would be though to make defcstruct work
  (cffi:with-foreign-object (array :float 40) ; 40 = floats in light-block
    (dotimes (i 40)
      (setf (cffi:mem-aref array :float i)
	    0.5))
    array))


;; (gl:alloc-gl-array type count)
;; (...) just makes a pointer to a array of uniform <type> of <count> size
;; ahhh, at its core is just CFFI:FOREIGN-ALLOC and CFFI:FOREIN-FREE! example:
;; (cffi:foreign-free (cffi:foreign-alloc :float :initial-element 0.5 :count 40))



;;NEXT-TODO: comment by ogmo!

;;------------------------------------------------------------------------------
;;CFFI approach to light-block struct

;; first we need the glm::vec4 which shall be just an array of floats
(cffi:defcstruct per-light
  (camera-space-light-pos :float :count 4)
  (light-intensity :float :count 4))


;; from cffi doc:
(cffi:defcstruct light-block
  (ambient-intensity :float :count 4)
  (light-attenuation :float)
  ;; TODO: use :offet?
  (padding :float :count 3)
  ;; TODO: :count doesn't accept a +constant+ value, cffi bug?
  (lights (:struct per-light) :count 4))

;; TODO: pass it a object as light-block argument?
(defun make-light-block-c-struct ()
  (cffi:with-foreign-object (ptr '(:struct light-block))
    ;; 'vars' need to be the full name of the actuall slots
    (cffi:with-foreign-slots ((ambient-intensity) ptr (:struct light-block))
      (dotimes (i 4)
	;; NEXT-TODO. can't set values using with-foregin-slotS ?
	(setf (cffi:mem-aref ambient-intensity :float i) 0.5))
      (print (cffi:mem-aref ambient-intensity :float 0)))
    ptr))

;; (cffi:with-foreign-object (ptr '(:struct point))
;;   ;; Initialize the slots
;;   (setf (cffi:foreign-slot-value ptr '(:struct point) 'x) 42
;; 	(cffi:foreign-slot-value ptr '(:struct point) 'y) 42)
;;   ;; Return a list with the coordinates
;;   (cffi:with-foreign-slots ((x y) ptr (:struct point))
;;     (list x y)))

;;memory layout tests
(cffi:defcstruct test
  (x :int)
  (y :int))

(defparameter *t1*
  (cffi:with-foreign-object (ptr '(:struct test))
    (setf (cffi:foreign-slot-value ptr '(:struct test) 'x) 42
	  (cffi:foreign-slot-value ptr '(:struct test) 'y) 99)
    ptr))

;; cffi doc example
;; (cffi:with-foreign-object (ptr '(:struct test))
;;   (setf (cffi:foreign-slot-value ptr '(:struct test) 'x) 42
;; 	(cffi:foreign-slot-value ptr '(:struct test) 'y) 99)
;;   (cffi:with-foreign-slots ((x y) ptr (:struct test))
;;     (list x y)))

;;(cffi:foreign-alloc '(:struct light-block) :initial-element 0.5)
;;==> error no method for CFFI:TRANSLATE-INTO-FOREIGN-MEMORY when
;;    called with argument:#<LIGHT-BLOCK-TCLASS LIGHT-BLOCK>
;; So we just need to implement the translate-into-foreign-memory class?

;;yeah, well just remove the :initial-element and it seems to work:

(defparameter *lb*
  (cffi:foreign-alloc '(:struct light-block)))

;; since *lb* memory layout is practically a float array of 40 indices this
;; oughta work:
(dotimes (i 40)
  (setf
   (cffi:mem-aref *lb* :float i) 0.5)) ; yep, totally works!!




;; new approach, remove FOREIGN-FREE from WITH-FOREIGN-OBJECT macro expansion:
;; TODO: _remove_ these functions!
(defmacro w-f-p ((var size &optional size-var) &body body)
  "Bind VAR to SIZE bytes of foreign memory during BODY.  The
pointer in VAR is invalid beyond the dynamic extent of BODY, and
may be stack-allocated if supported by the implementation.  If
SIZE-VAR is supplied, it will be bound to SIZE during BODY."
  (unless size-var
    (setf size-var (gensym "SIZE")))

  (let ((alien-var (gensym "ALIEN")))
    `(cffi-sys::with-alien ((,alien-var (array (cffi-sys::unsigned 8) ,(eval size))))
       (let ((,size-var ,(eval size))
	     (,var (cffi-sys::alien-sap ,alien-var)))
	 (declare (ignorable ,size-var))
	 ,@body))))

(defmacro w-f-o ((var type &optional (count 1)) &body body)
  "Bind VAR to a pointer to COUNT objects of TYPE during BODY.
The buffer has dynamic extent and may be stack allocated."
  `(w-f-p
    (,var ,(* (eval count) (cffi:foreign-type-size (eval type))))
    ,@body))


