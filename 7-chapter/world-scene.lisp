;; TODO: about

(in-package #:arc-7)

;; TODO: this might solve the problem:
;; (print (uiop/lisp-build:current-lisp-file-pathname)) ?
(defvar *glsl-directory*
  (merge-pathnames #p "7-chapter/" (asdf/system:system-source-directory :arcsynthesis)))
;;todo: fix this output to slime-repl solution
(defvar out *standard-output*)  (defvar dbg *debug-io*) (defvar err *error-output*)


;;TODO: note from pjb stating to try ":conc-name" regarding a former rejection
;;       to implement program-data using defstruct, as it creates verbose symbols
(defclass program-data ()
  ((the-program :accessor the-program)
   (model-to-world-matrix-unif :accessor model-to-world-matrix-unif)
   (world-to-camera-matrix-unif :accessor world-to-camera-matrix-unif)
   (camera-to-clip-matrix-unif :accessor camera-to-clip-matrix-unif)
   (base-color-unif :accessor base-color-unif)))


;;program-data
(defvar *uniform-color*)
(defvar *object-color*)
(defvar *uniform-color-tint*)

(defun load-program (str-vertex-shader str-fragment-shader)
  "Create program-data object from shader strings. Hardcoded uniform reference."
  (let ((shader-list (list))
	(data (make-instance 'program-data)))
    (push (arc:create-shader :vertex-shader
	   (arc:file-to-string (merge-pathnames str-vertex-shader *glsl-directory*)))
	  shader-list)
    (push (arc:create-shader :fragment-shader
    	   (arc:file-to-string (merge-pathnames str-fragment-shader *glsl-directory*)))
    	  shader-list)
    (setf (the-program data) (arc:create-program shader-list))
    ;; hard-coding time: also this should undergo test if assignment was successful
    (setf (model-to-world-matrix-unif data)
	  (gl:get-uniform-location (the-program data) "model_to_world_matrix"))
    (setf (world-to-camera-matrix-unif data)
	  (gl:get-uniform-location (the-program data) "world_to_camera_matrix"))
    (setf (camera-to-clip-matrix-unif data)
	  (gl:get-uniform-location (the-program data) "camera_to_clip_matrix"))
    ;; TODO: if uniform doesn't really exist in shader, wasn't opengl lenient about it?
    (setf (base-color-unif data)
	  (gl:get-uniform-location (the-program data) "base_color"))
    data))


(defun initialize-program ()
  (setf *uniform-color*
	(load-program "pos-color-local-transformation.vert" "color-passthrough.frag"))
)


(defparameter *number-of-vertices* 4)

(defparameter +red-color+   '(1.0 0.0 0.0 1.0))
(defparameter +green-color+ '(0.0 1.0 0.0 1.0))
(defparameter +blue-color+  '(0.0 0.0 1.0 1.0))

(defparameter +yellow-color+ '(1.0 1.0 0.0 1.0))
(defparameter +cyan-color+ '(0.0 1.0 1.0 1.0))
(defparameter +magenta-color+ '(1.0 0.0 1.0 1.0))


(defparameter *vertex-data*
  (arc:create-gl-array-from-vector 
`#(
   ;; from arc's unit-plane.xml
     0.5  0.0 -0.5
     0.5  0.0  0.5
    -0.5  0.0  0.5
    -0.5  0.0 -0.5
        ;; vertex colors
    ,@+green-color+
    ,@+green-color+
    ,@+green-color+
    ,@+green-color+
  )))


;; IMPORTANT: in arc's code, index alternate every three indices between points and
;;            colors!!!!!!
(defparameter *index-data*
  (arc::create-gl-array-of-unsigned-short-from-vector
   #(
     0 1 2
     2 3 0
     0 2 1
     2 0 3
     )))

(defvar *vertex-buffer-object*)
(defvar *index-buffer-object*)

(defun initialize-vertex-buffer ()
  (setf *vertex-buffer-object* (first (gl:gen-buffers 1)))

  (gl:bind-buffer :array-buffer *vertex-buffer-object*)
  (gl:buffer-data :array-buffer :static-draw *vertex-data*)
  (gl:bind-buffer :array-buffer 0)

  ;; index-array time:
  (setf *index-buffer-object* (first (gl:gen-buffers 1)))

  (gl:bind-buffer :element-array-buffer *index-buffer-object*)
  (gl:buffer-data :element-array-buffer :static-draw *index-data*)
  (gl:bind-buffer :element-array-buffer  0)  
  )

(defvar *vao*)

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
    ;; unbind element-array-buffer? since it already, received data, and
    ;; the *vao* implicit setting is done?
    
    )
  )



(defun init ()
	(initialize-program)
	(initialize-vertex-buffer)
	(initialize-vertex-array-objects)

	;; TODO: why doesn't this seem to affect the unit-plane when it is rotated 360?
	(gl:enable :cull-face)
	(%gl:cull-face :back)
	(%gl:front-face :cw) ;; TODO maybe bad order vertices, need to change; test here

	(gl:viewport 0 0 500 500)

	(gl:enable :depth-test)
	(gl:depth-mask :true)
	(%gl:depth-func :lequal)
	(gl:depth-range 0.0 1.0)
)


;; makeshift solution
(defparameter t-mat (let ((translate-mat4 (glm:make-mat4 1.0))
			 (vec4 (glm:vec4-from-vec3 (glm:vec3 3.0 -5.0 -40.0))))
		     (glm:set-mat4-col translate-mat4 3 vec4)
		     translate-mat4))

;;g_ in arcsynthesis code variable names, is a convention for global-variable naming
;;hence replaced by ear-muffs
(defparameter *sphere-cam-rel-pos* (glm:vec3 67.5 -46.0 150.0))
(defparameter *cam-target* (glm:vec3 0.0 0.4 0.0))


(defun resolve-cam-position ()
  (let* (;(temp-mat (make-instance 'glutil:matrix-stack)) ;; well it isn't used
	 (phi (framework:deg-to-rad (glm:vec. *sphere-cam-rel-pos* :x)))
	 (theta (framework:deg-to-rad (+ (glm:vec. *sphere-cam-rel-pos* :y)
					 90.0)))
	 ;; theta is single-float so SIN will return single-float
	 (sin-theta (sin theta))
	 (cos-theta (cos theta))
	 (cos-phi (cos phi))
	 (sin-phi (sin phi))

	 (dir-to-camera (glm:vec3 (* sin-theta cos-phi)
	 			  cos-theta
	 			  (* sin-theta sin-phi)))
	 )
    (sb-cga:vec+ (sb-cga:vec* dir-to-camera (glm:vec. *sphere-cam-rel-pos* :z))
       *cam-target*)
))

;; Note: c++ function signature: foo(const &var) means:
;; &var we don't need a copy (reuse of resource;pass by reference)
;; and 'const' ensures we will not mutate it (save pass by reference for user
;; of this function). Also this probably helps the compiler.
(defparameter tc (lambda () (calc-look-at-matrix
			     (glm:vec3 0.0 0.0 1.0) ;be
			     (glm:vec3 0.0)         ;look at
			     (glm:vec3 0.0 1.0 0.0)))) ;up
;; TODO: hm the resultin matrix from tc has many rounding problems
(defun calc-look-at-matrix (camera-pt look-pt up-pt)
  ;; no type problems: sb-cga vectors are the same as glm:vec3
  (let* ((look-dir (sb-cga:normalize (sb-cga:vec- look-pt camera-pt)))
	 ;; since we only want a direction, we naturally normalize the vector
	 (up-dir (sb-cga:normalize up-pt))
	 
	 ;; cross-product returns the vector perpendicular to the plane formed
	 ;; by two vectors:
	 ;; (sb-cga:cross-product (glm:vec3 1.0 0.0 0.0) (glm:vec3 0.0 1.0 0.0))
	 ;; ==> #(0.0 0.0 1.0)	 
	 (right-dir (sb-cga:normalize (sb-cga:cross-product look-dir up-dir)))
	 (perp-up-dir (sb-cga:cross-product right-dir look-dir))

	 (rot-mat (glm:make-mat4 1.0))
	 (trans-mat (glm:make-mat4 1.0)))

;    (format t "ppud:~a up-dir:~a rd:~a" perp-up-dir up-dir right-dir)
    ;;TODO: this is the pinnacle of confusion, sb-cga:matrix is column major,
    ;;hence my glm functions (set-mat4-col ..) are "wrong" yet they work the way
    ;;opengl wants them... :I don't even know if i want to figure this out,
    ;;already changed this 180-degree style once.
    ;;Maybe experiment where uniform-matrix is used to pass matrix. (<- !)
    ;; YEP: UNIFORM-MATRIX _TRANSPOSES_ THE INPUT MATRIX BY DEFAULT .... OMG
    ;;Anywhooo those are right:
    ;;rotMat[0] = glm::vec4 (rightDir, 0.0f);
    ;;; TODO-NEXT: REWRITE GLM matrix permuting functions, and test if other tutorials
    ;;; work
    (glm:set-mat4-col rot-mat 0 (glm:vec4-from-vec3 right-dir 0.0))
    (glm:set-mat4-col rot-mat 1 (glm:vec4-from-vec3 perp-up-dir 0.0))
    (glm:set-mat4-col rot-mat 2 (glm:vec4-from-vec3 (glm:vec- look-dir) 0.0))

    ;; TODO: intuitive understanding of usage
    ;; NEXT-TODO: this should mean that the above col settings are to be row
    ;; settings!? what is going on here? first get it to run simple test
    (setf rot-mat (sb-cga:transpose-matrix rot-mat))

    ;; oh, its just a translation matrix putting the camera-pt into origin!
    (glm:set-mat4-col trans-mat 3 (glm:vec4-from-vec3 (glm:vec- camera-pt) 1.0))

    ;;return rotmat * transmat;
    (sb-cga:matrix* rot-mat trans-mat)))

(defparameter *look-pt* (glm:vec3 0.0 0.0 0.0)) ; look at actual vertex of drawn object
(defparameter *cam-pt* (glm:vec3 0.0 0.0 1.0))

(defun draw ()
  (let ((cam-pos (resolve-cam-position))
	(cam-matrix (make-instance 'glutil:matrix-stack))
	(model-matrix (make-instance 'glutil:matrix-stack)))

    (glutil:set-matrix cam-matrix
		       (calc-look-at-matrix cam-pos *cam-target* (glm:vec3 0.0 1.0 0.0)))
    ;; set world-to-camera matrix
    (gl:use-program (the-program *uniform-color*))
    (gl:uniform-matrix (world-to-camera-matrix-unif *uniform-color*) 4
		       (vector (glutil:top-ms cam-matrix)) NIL)

    ;; render the ground plane:
    (glutil:with-transform (model-matrix)
	:scale 100.0 1.0 100.0
	;; TODO fold into WITH-TRANSFORM macro: optional slots (make matrix-stack
	;; have slots for shader uniforms? Create shader-program class to work with?
	(gl:uniform-matrix (model-to-world-matrix-unif *uniform-color*) 4
			   (vector (glutil:top-ms model-matrix)) NIL)

	(%gl:draw-elements :triangles (gl::gl-array-size *index-data*)
			   :unsigned-short 0)


	(gl:use-program (the-program *uniform-color*)))
    
    ))

(defun display ()
  (gl:clear-color 0 0 0.2 1)
  (gl:clear-depth 1.0)
  (gl:clear :color-buffer-bit :depth-buffer-bit)


  (gl:bind-vertex-array *vao*)

  (draw)
  
  (gl:bind-vertex-array 0)
  ;;swap buffers: in main loop 
       )

(defparameter *fz-near* 1.0)
(defparameter *fz-far* 1000.0)

(defun reshape (w h)
  ;; for now where we set the camera-to-clip perspective-matrix for the shaders
  (let ((pers-matrix (make-instance 'glutil:matrix-stack)))
    (glutil:perspective pers-matrix 45.0 (/ w h) *fz-near* *fz-far*)
    (%gl:use-program (the-program *uniform-color*))
    (gl:uniform-matrix (camera-to-clip-matrix-unif *uniform-color*) 4
		       (vector (glutil:top-ms pers-matrix)) NIL)
    (%gl:use-program 0))
  (%gl:viewport 0 0 w h))

(defun main ()
  (sdl2:with-init (:everything)
    (progn (setf *standard-output* out) (setf *debug-io* dbg) (setf *error-output* err))
    (sdl2:with-window (win :w 500 :h 500 :flags '(:shown :opengl :resizable))
      (sdl2:with-gl-context (gl-context win)
	;; INIT code:
	(init)
	;; TODO: callback for reshape; for now used to setup cam-to-clip-space matrix
	(reshape 500.0 500.0)
	(sdl2:with-event-loop (:method :poll)
	  (:keydown
	   (:keysym keysym)
	   ;; TODO: capture in macro
	   ;; move cam target horizontally
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-a)
	     (decf (glm:vec. *cam-target* :x) 0.4))
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-d)
	     (incf (glm:vec. *cam-target* :x) 0.4))
	   ;; move cam target vertically 
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-w)
	     (decf (glm:vec. *cam-target* :z) 0.4))
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-s)
	     (incf (glm:vec. *cam-target* :z) 0.4))
	   ;; move camera target up/down
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-e)
	     (decf (glm:vec. *cam-target* :y) 4.0))
   	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-q)
	     (incf (glm:vec. *cam-target* :y) 4.0))
	   ;; rotate camera horizontally around target
	   ;; TODO: why bounces back and forth while incresing/decreasing to certain point?
	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-j)
	     (decf (glm:vec. *sphere-cam-rel-pos* :x) 1.125))
   	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-l)
	     (incf (glm:vec. *sphere-cam-rel-pos* :x) 1.125))
	   ;; rotate cam vertically around target
   	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-i)
	     (decf (glm:vec. *sphere-cam-rel-pos* :y) 1.125))
   	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-k)
	     (incf (glm:vec. *sphere-cam-rel-pos* :y) 1.125))
	   ;; zoom camera in/out of target
      	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-u)
	     (decf (glm:vec. *sphere-cam-rel-pos* :z) 0.5))
   	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-o)
	     (incf (glm:vec. *sphere-cam-rel-pos* :z) 0.5))

	   (when (sdl2:scancode= (sdl2:scancode-value keysym) :scancode-escape)
	     (sdl2:push-event :quit)))
	  (:quit () t)
	  (:idle ()
		 ;;main-loop:
		 (display)
		 
                 (sdl2:gl-swap-window win) ; wow, this can be forgotten easily -.-
		 ))))))

