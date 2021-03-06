;; very trivial change: we just changed the z-offset to make the
;; object overlap with the outside of the viewable region

(in-package #:arc-5.3)

(defvar *data-directory*
  (merge-pathnames #p "5-chapter/data/" (asdf/system:system-source-directory :arcsynthesis)))

(defvar out *standard-output*)  (defvar dbg *debug-io*) (defvar err *error-output*)

(defparameter *program* nil "program-object")
(defparameter *offset-uniform* 0)

(defun initialize-program ()
  (let ((shader-list (list)))
    ;;oh c'mon how to make it local
    (push (arc:create-shader
	   :vertex-shader
	   (arc:file-to-string
	    (merge-pathnames "standard.vert" *data-directory*)))
	  shader-list)
    (push (arc:create-shader
    	   :fragment-shader
    	   (arc:file-to-string (merge-pathnames "standard.frag" *data-directory* )))
    	  shader-list)
    (setf *program* (arc:create-program shader-list))
    (let ((s 1.0) (n 1.0) (f 3.0)	;frustum-scale, zNear, zFar
	  (matrix-uniform)
	  (perspective-matrix))
      (setf matrix-uniform (gl:get-uniform-location *program* "perspective_matrix"))
      (setf perspective-matrix
	    (make-array 16 :element-type 'single-float
			:initial-contents
			;; the matrix with its coefficients 'switches' and the perma 
			;; "on-switch" the 'w' component
			(list s 0.0 0.0 0.0                                     ;= x
			      0.0 s 0.0 0.0                                     ;= y
			      0.0 0.0 (/ (+ f n) (- n f)) (/ (* 2 f n) (- n f)) ;= z
			      0.0 0.0 -1.0 0.0)))                               ;= w

      (setf *offset-uniform* (gl:get-uniform-location *program* "offset"))
      (%gl:use-program *program*)
      (format t "off-u:~a mat-u:~a" *offset-uniform* matrix-uniform)

      (gl:uniform-matrix matrix-uniform 4 (vector perspective-matrix)))))


(defparameter *vao* nil)

(defparameter *number-of-vertices* 36)
(defparameter *vertex-buffer-object* nil)

(defparameter *vertex-data*
  (arc:create-gl-array-from-vector 
#(
  ;; note, as arcsynthesis states itself, our position are 3-dimensional, but
  ;; the shaders takes a vec4. if a value is not provided it is defaulted to 0.0
  ;; except for the 'w' value, which defaults to 1.0! So nice way to save space!
 -0.8  0.2  -1.75
 -0.8  0.0  -1.25
  0.8  0.0  -1.25
  0.8  0.2  -1.75

 -0.8 -0.2 -1.75
 -0.8 0.0 -1.25
 0.8 0.0 -1.25
 0.8 -0.2 -1.75

 -0.8 0.2 -1.75
 -0.8 0.0 -1.25
 -0.8 -0.2 -1.75

 0.8 0.2 -1.75
 0.8 0.0 -1.25
 0.8 -0.2 -1.75

 -0.8 -0.2 -1.75
 -0.8 0.2 -1.75
 0.8 0.2 -1.75
 0.8 -0.2 -1.75

 ;;Object 2 positions
 0.2 0.8 -1.75
 0.0 0.8 -1.25
 0.0 -0.8 -1.25
 0.2 -0.8 -1.75

 -0.2 0.8 -1.75
 0.0 0.8 -1.25
 0.0 -0.8 -1.25
 -0.2 -0.8 -1.75

 0.2 0.8 -1.75
 0.0 0.8 -1.25
 -0.2 0.8 -1.75

 0.2 -0.8 -1.75
 0.0 -0.8 -1.25
 -0.2 -0.8 -1.75

 -0.2 0.8 -1.75
 0.2 0.8 -1.75
 0.2 -0.8 -1.75
 -0.2 -0.8 -1.75

 ;;Object 1 colors
 0.75 0.75 1.0 1.0 
 0.75 0.75 1.0 1.0 
 0.75 0.75 1.0 1.0 
 0.75 0.75 1.0 1.0 

 0.0 0.5 0.0 1.0 
 0.0 0.5 0.0 1.0 
 0.0 0.5 0.0 1.0 
 0.0 0.5 0.0 1.0 

 1.0 0.0 0.0 1.0 
 1.0 0.0 0.0 1.0 
 1.0 0.0 0.0 1.0 

 0.8 0.8 0.8 1.0 
 0.8 0.8 0.8 1.0 
 0.8 0.8 0.8 1.0 
  
 0.5 0.5 0.0 1.0 
 0.5 0.5 0.0 1.0 
 0.5 0.5 0.0 1.0 
 0.5 0.5 0.0 1.0 

 ;;Object 2 colors
 1.0 0.0 0.0 1.0 
 1.0 0.0 0.0 1.0 
 1.0 0.0 0.0 1.0 
 1.0 0.0 0.0 1.0 

 0.5 0.5 0.0 1.0 
 0.5 0.5 0.0 1.0 
 0.5 0.5 0.0 1.0 
 0.5 0.5 0.0 1.0 

 0.0 0.5 0.0 1.0 
 0.0 0.5 0.0 1.0 
 0.0 0.5 0.0 1.0 

 0.75 0.75 1.0 1.0 
 0.75 0.75 1.0 1.0 
 0.75 0.75 1.0 1.0 

 0.8 0.8 0.8 1.0 
 0.8 0.8 0.8 1.0 
 0.8 0.8 0.8 1.0 
 0.8 0.8 0.8 1.0 

  )))

(defparameter *index-buffer-object* nil)
(defparameter *index-data*
  ;; this makes sure that *index-data* is of type unsigned-short
  ;; which is important to have (gl:draw-elements ...) working!
  ;; no it isn't anymore, because the cl-opengl example doesn't seem to
  ;; aim at such convenience (extract type and fill in <type> in %gl:draw-elements)
  (arc::create-gl-array-of-unsigned-short-from-vector #(
;;two faces in the front
 0  2  1
 3  2  0

 4  5  6 
 6  7  4 
;;two faces from behind?
 8  9 10 
11 13 12 

14 16 15 
17 16 14
							
)))

(defun initialize-vertex-buffer ()
  ;; create and allocate buffers to OpenGL context -object* expose the handle
  ;; to those allocated data!
  ;; VAO-buffer time
  (setf *vertex-buffer-object* (first (gl:gen-buffers 1)))

  (gl:bind-buffer :array-buffer *vertex-buffer-object*)
  (gl:buffer-data :array-buffer :static-draw *vertex-data*)
  (gl:bind-buffer :array-buffer 0)

  ;; index-array time:
  (setf *index-buffer-object* (first (gl:gen-buffers 1)))

  (gl:bind-buffer :element-array-buffer  *index-buffer-object*)
  (gl:buffer-data :element-array-buffer  :static-draw *index-data*)
  (gl:bind-buffer :element-array-buffer  0)  
  )

(defun initialize-vertex-array-objects ()
  (setf *vao* (first (gl:gen-vertex-arrays 1)))
  (gl:bind-vertex-array *vao*)

  (let ((color-data-offset (* #|size-of(float):|# 4 3 *number-of-vertices*)))
    (gl:bind-buffer :array-buffer *vertex-buffer-object*)
    (%gl:enable-vertex-attrib-array 0)
    (%gl:enable-vertex-attrib-array 1)
    (%gl:vertex-attrib-pointer 0 3 :float :false 0 0)
    (%gl:vertex-attrib-pointer 1 4 :float :false 0 color-data-offset)
    (%gl:bind-buffer :element-array-buffer *index-buffer-object*)

    (%gl:bind-vertex-array 0)
    )
  )


(defun rendering-code ()
  (gl:clear-color 0 0 0.2 1)
  (gl:clear-depth 1.0)
  (gl:clear :color-buffer-bit :depth-buffer-bit)

  (%gl:use-program *program*)

  (gl:bind-vertex-array *vao*)
  (%gl:uniform-3f *offset-uniform* 0.0 0.0 0.5)
  (%gl:draw-elements :triangles (gl::gl-array-size *index-data*) :unsigned-short 0)
  
  (%gl:uniform-3f *offset-uniform* 0.0 0.0 -1.0)

  (%gl:draw-elements-base-vertex :triangles (gl::gl-array-size *index-data*)
				 :unsigned-short 0 (/ *number-of-vertices* 2))
  (gl:bind-vertex-array 0)
  (gl:use-program *program*)
  
  ;;swap buffers: in main loop 
  )

(defun main ()
  (sdl2:with-init (:everything)
    (progn (setf *standard-output* out) (setf *debug-io* dbg) (setf *error-output* err))
    (sdl2:with-window (win :w 500 :h 500 :flags '(:shown :opengl :resizable))
      (sdl2:with-gl-context (gl-context win)
	;; INIT code:
	(initialize-program)
	(initialize-vertex-buffer)
	(initialize-vertex-array-objects)
  
	(gl:enable :cull-face)
	(%gl:cull-face :back)
	(%gl:front-face :cw)
	(gl:viewport 0 0 500 500)

	;;depth buffer please indulge us with your presence!
	;;TODO: (gl:enable :depth-test) already suffices for the visual effect, why
	(gl:enable :depth-test)
	;; write depth value from fragment to depth-buffer
	(gl:depth-mask :true)
	(%gl:depth-func :lequal)
	;; ndc -> window-space mapping of Z-values (!) ndc [-1,1] values outside
	;; 0.0 1.0 will be mapped directly to the border values themselves, they
	;; shot over. if zNear > zFar mapping will be reversed => furthest fragment
	;; from eye will be drawn
	(gl:depth-range 0.0 1.0)

	(sdl2:with-event-loop (:method :poll)
	  (:keyup
	   (:keysym keysym)
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-e)
	     ;; experimental code
	     )
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-escape)
	     (sdl2:push-event :quit)))
	  (:quit () t)
	  (:idle ()
		 ;;main-loop:
		 (rendering-code)
		 
                 (sdl2:gl-swap-window win) ; wow, this can be forgotten easily -.-
		 ))))))
