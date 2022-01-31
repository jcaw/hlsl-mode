;;; hlsl-mode.el --- major mode for Open HLSL shader files

;; Copyright (C) 1999, 2000, 2001 Free Software Foundation, Inc.
;; Copyright (C) 2011, 2014, 2019 Jim Hourihan
;;
;; Authors: Xavier.Decoret@imag.fr,
;;          Jim Hourihan <jimhourihan ~at~ gmail.com>
;;          GitHub user "jcaw"
;; Keywords: languages HLSL GPU shaders
;; Version: 2.4
;; X-URL: https://github.com/jcaw/hlsl-mode
;;
;; Original X-URL http://artis.inrialpes.fr/~Xavier.Decoret/resources/glsl-mode/

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Major mode for editing OpenHLSL grammar files, usually files ending with
;; `.fx[hc]', `.hlsl', `.shader', `.compute'. It is based on c-mode plus some
;; features and pre-specified fontifications.
;;
;; It is modified from `glsl-mode', maintained at the time of writing by Jim
;; Hourihan: https://github.com/jimhourihan/glsl-mode

;; This package provides the following features:
;;  * Syntax coloring (via font-lock) for grammar symbols and
;;    builtin functions and variables for up to HLSL version 4.6
;;  * Indentation for the current line (TAB) and selected region (C-M-\).
;;  * Switching between file.vert and file.frag
;;    with S-lefttab (via ff-find-other-file)
;;  * interactive function hlsl-find-man-page prompts for hlsl built
;;    in function, formats opengl.org url and passes to browse-url

;;; Installation:

;; This file requires Emacs-20.3 or higher and package cc-mode.

;; If hlsl-mode is not part of your distribution, put this file into your
;; load-path and the following into your ~/.emacs:
;;   (autoload 'hlsl-mode "hlsl-mode" nil t)

;; Reference:
;; https://www.khronos.org/registry/OpenGL/specs/gl/HLSLangSpec.4.60.pdf

;;; Code:

(provide 'hlsl-mode)

(eval-when-compile			; required and optional libraries
  (require 'cc-mode)
  (require 'find-file))

(require 'align)

(defgroup hlsl nil
  "OpenGL Shading Language Major Mode"
  :group 'languages)

(defconst hlsl-language-version "5.0"
  "HLSL language version number.")

(defconst hlsl-version "5.0"
  "OpenGL major mode version number.")

(defvar hlsl-mode-menu nil "Menu for HLSL mode")

(defvar hlsl-mode-hook nil "HLSL mode hook")

(defvar hlsl-type-face 'hlsl-type-face)
(defface hlsl-type-face
  '((t (:inherit font-lock-type-face))) "hlsl: type face"
  :group 'hlsl)

(defvar hlsl-builtin-face 'hlsl-builtin-face)
(defface hlsl-builtin-face
  '((t (:inherit font-lock-builtin-face))) "hlsl: builtin face"
  :group 'hlsl)

(defvar hlsl-deprecated-builtin-face 'hlsl-deprecated-builtin-face)
(defface hlsl-deprecated-builtin-face
  '((t (:inherit font-lock-warning-face))) "hlsl: deprecated builtin face"
  :group 'hlsl)

(defvar hlsl-qualifier-face 'hlsl-qualifier-face)
(defface hlsl-qualifier-face
  '((t (:inherit font-lock-keyword-face))) "hlsl: qualifier face"
  :group 'hlsl)

(defvar hlsl-keyword-face 'hlsl-keyword-face)
(defface hlsl-keyword-face
  '((t (:inherit font-lock-keyword-face))) "hlsl: keyword face"
  :group 'hlsl)

(defvar hlsl-deprecated-keyword-face 'hlsl-deprecated-keyword-face)
(defface hlsl-deprecated-keyword-face
  '((t (:inherit font-lock-warning-face))) "hlsl: deprecated keyword face"
  :group 'hlsl)

(defvar hlsl-variable-name-face 'hlsl-variable-name-face)
(defface hlsl-variable-name-face
  '((t (:inherit font-lock-variable-name-face))) "hlsl: variable face"
  :group 'hlsl)

(defvar hlsl-deprecated-variable-name-face 'hlsl-deprecated-variable-name-face)
(defface hlsl-deprecated-variable-name-face
  '((t (:inherit font-lock-warning-face))) "hlsl: deprecated variable face"
  :group 'hlsl)

(defvar hlsl-reserved-keyword-face 'hlsl-reserved-keyword-face)
(defface hlsl-reserved-keyword-face
  '((t (:inherit hlsl-keyword-face))) "hlsl: reserved keyword face"
  :group 'hlsl)

(defvar hlsl-preprocessor-face 'hlsl-preprocessor-face)
(defface hlsl-preprocessor-face
  '((t (:inherit font-lock-preprocessor-face))) "hlsl: preprocessor face"
  :group 'hlsl)

(defcustom hlsl-additional-types nil
  "List of additional keywords to be considered types. These are
added to the `hlsl-type-list' and are fontified using the
`hlsl-type-face'. Examples of existing types include \"float\", \"vec4\",
  and \"int\"."
  :type '(repeat (string :tag "Type Name"))
  :group 'hlsl)

(defcustom hlsl-additional-qualifiers nil
  "List of additional keywords to be considered qualifiers. These
are added to the `hlsl-qualifier-list' and are fontified using
the `hlsl-qualifier-face'. Examples of existing qualifiers
include \"const\", \"in\", and \"out\"."
  :type '(repeat (string :tag "Qualifier Name"))
  :group 'hlsl)

(defcustom hlsl-additional-keywords nil
  "List of additional HLSL keywords. These are added to the
`hlsl-keyword-list' and are fontified using the
`hlsl-keyword-face'. Example existing keywords include \"while\",
\"if\", and \"return\"."
  :type '(repeat (string :tag "Keyword"))
  :group 'hlsl)

(defcustom hlsl-additional-built-ins nil
  "List of additional functions to be considered built-in. These
are added to the `hlsl-builtin-list' and are fontified using the
`hlsl-builtin-face'."
  :type '(repeat (string :tag "Keyword"))
  :group 'hlsl)

(defvar hlsl-mode-hook nil)

(defvar hlsl-mode-map
  (let ((hlsl-mode-map (make-sparse-keymap)))
    (define-key hlsl-mode-map [S-iso-lefttab] 'ff-find-other-file)
    hlsl-mode-map)
  "Keymap for HLSL major mode.")

(defcustom hlsl-browse-url-function 'browse-url
  "Function used to display HLSL man pages. E.g. browse-url, eww, w3m, etc"
  :type 'function
  :group 'hlsl)

(defcustom hlsl-man-pages-base-url "http://www.opengl.org/sdk/docs/man/html/"
  "Location of GL man pages."
  :type 'string
  :group 'hlsl)

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.vert\\'" . hlsl-mode))
  (add-to-list 'auto-mode-alist '("\\.frag\\'" . hlsl-mode))
  (add-to-list 'auto-mode-alist '("\\.geom\\'" . hlsl-mode))
  (add-to-list 'auto-mode-alist '("\\.hlsl\\'" . hlsl-mode)))

(eval-and-compile
  ;; These vars are useful for completion so keep them around after
  ;; compile as well. The goal here is to have the byte compiled code
  ;; have optimized regexps so its not done at eval time.
  (defvar hlsl-type-list
    '("float" "double" "int" "void" "bool" "true" "false" "mat2" "mat3"
      "mat4" "dmat2" "dmat3" "dmat4" "mat2x2" "mat2x3" "mat2x4" "dmat2x2"
      "dmat2x3" "dmat2x4" "mat3x2" "mat3x3" "mat3x4" "dmat3x2" "dmat3x3"
      "dmat3x4" "mat4x2" "mat4x3" "mat4x4" "dmat4x2" "dmat4x3" "dmat4x4" "vec2"
      "vec3" "vec4" "ivec2" "ivec3" "ivec4" "bvec2" "bvec3" "bvec4" "dvec2"
      "dvec3" "dvec4" "uint" "uvec2" "uvec3" "uvec4" "atomic_uint"
      "sampler1D" "sampler2D" "sampler3D" "samplerCube" "sampler1DShadow"
      "sampler2DShadow" "samplerCubeShadow" "sampler1DArray" "sampler2DArray"
      "sampler1DArrayShadow" "sampler2DArrayShadow" "isampler1D" "isampler2D"
      "isampler3D" "isamplerCube" "isampler1DArray" "isampler2DArray"
      "usampler1D" "usampler2D" "usampler3D" "usamplerCube" "usampler1DArray"
      "usampler2DArray" "sampler2DRect" "sampler2DRectShadow" "isampler2DRect"
      "usampler2DRect" "samplerBuffer" "isamplerBuffer" "usamplerBuffer"
      "sampler2DMS" "isampler2DMS" "usampler2DMS" "sampler2DMSArray"
      "isampler2DMSArray" "usampler2DMSArray" "samplerCubeArray"
      "samplerCubeArrayShadow" "isamplerCubeArray" "usamplerCubeArray"
      "image1D" "iimage1D" "uimage1D" "image2D" "iimage2D" "uimage2D" "image3D"
      "iimage3D" "uimage3D" "image2DRect" "iimage2DRect" "uimage2DRect"
      "imageCube" "iimageCube" "uimageCube" "imageBuffer" "iimageBuffer"
      "uimageBuffer" "image1DArray" "iimage1DArray" "uimage1DArray"
      "image2DArray" "iimage2DArray" "uimage2DArray" "imageCubeArray"
      "iimageCubeArray" "uimageCubeArray" "image2DMS" "iimage2DMS" "uimage2DMS"
      "image2DMSArray" "iimage2DMSArray" "uimage2DMSArray"))

  (defvar hlsl-qualifier-list
    '("attribute" "const" "uniform" "varying" "buffer" "shared" "coherent"
    "volatile" "restrict" "readonly" "writeonly" "layout" "centroid" "flat"
    "smooth" "noperspective" "patch" "sample" "in" "out" "inout"
    "invariant" "lowp" "mediump" "highp"))

  (defvar hlsl-keyword-list
    '("break" "continue" "do" "for" "while" "if" "else" "subroutine"
      "discard" "return" "precision" "struct" "switch" "default" "case"))

  (defvar hlsl-reserved-list
    '("input" "output" "asm" "class" "union" "enum" "typedef" "template" "this"
      "packed" "resource" "goto" "inline" "noinline"
      "common" "partition" "active" "long" "short" "half" "fixed" "unsigned" "superp"
      "public" "static" "extern" "external" "interface"
      "hvec2" "hvec3" "hvec4" "fvec2" "fvec3" "fvec4"
      "filter" "sizeof" "cast" "namespace" "using"
      "sampler3DRect"))

  (defvar hlsl-deprecated-qualifier-list
    '("varying" "attribute")) ; centroid is deprecated when used with varying

  (defvar hlsl-builtin-list
    '("abs" "acos" "acosh" "all" "any" "anyInvocation" "allInvocations"
      "allInvocationsEqual" "asin" "asinh" "atan" "atanh"
      "atomicAdd" "atomicMin" "atomicMax" "atomicAnd" "atomicOr"
      "atomicXor" "atomicExchange" "atomicCompSwap"
      "atomicCounter" "atomicCounterDecrement" "atomicCounterIncrement"
      "atomicCounterAdd" "atomicCounterSubtract" "atomicCounterMin"
      "atomicCounterMax" "atomicCounterAnd" "atomicCounterOr"
      "atomicCounterXor" "atomicCounterExchange" "atomicCounterCompSwap"
      "barrier" "bitCount" "bitfieldExtract" "bitfieldInsert" "bitfieldReverse"
      "ceil" "clamp" "cos" "cosh" "cross" "degrees" "determinant" "dFdx" "dFdy"
      "dFdyFine" "dFdxFine" "dFdyCoarse" "dFdxCoarse" "distance" "dot"
      "fwidthFine" "fwidthCoarse"
      "EmitStreamVertex" "EmitStreamPrimitive" "EmitVertex" "EndPrimitive"
      "EndStreamPrimitive" "equal" "exp" "exp2" "faceforward" "findLSB"
      "findMSB" "floatBitsToInt" "floatBitsToUint" "floor" "fma" "fract"
      "frexp" "fwidth" "greaterThan" "greaterThanEqual" "groupMemoryBarrier"
      "imageAtomicAdd" "imageAtomicAnd" "imageAtomicCompSwap" "imageAtomicExchange"
      "imageAtomicMax" "imageAtomicMin" "imageAtomicOr" "imageAtomicXor"
      "imageLoad" "imageSize" "imageStore" "imulExtended" "intBitsToFloat"
      "imageSamples" "interpolateAtCentroid" "interpolateAtOffset" "interpolateAtSample"
      "inverse" "inversesqrt" "isinf" "isnan" "ldexp" "length" "lessThan"
      "lessThanEqual" "log" "log2" "matrixCompMult" "max" "memoryBarrier"
      "memoryBarrierAtomicCounter" "memoryBarrierBuffer"
      "memoryBarrierShared" "memoryBarrierImage" "memoryBarrier"
      "min" "mix" "mod" "modf" "normalize" "not" "notEqual" "outerProduct"
      "packDouble2x32" "packHalf2x16" "packSnorm2x16" "packSnorm4x8"
      "packUnorm2x16" "packUnorm4x8" "pow" "radians" "reflect" "refract"
      "round" "roundEven" "sign" "sin" "sinh" "smoothstep" "sqrt" "step" "tan"
      "tanh" "texelFetch" "texelFetchOffset" "texture" "textureGather"
      "textureGatherOffset" "textureGatherOffsets" "textureGrad" "textureSamples"
      "textureGradOffset" "textureLod" "textureLodOffset" "textureOffset"
      "textureProj" "textureProjGrad" "textureProjGradOffset" "textureProjLod"
      "textureProjLodOffset" "textureProjOffset" "textureQueryLevels" "textureQueryLod"
      "textureSize" "transpose" "trunc" "uaddCarry" "uintBitsToFloat"
      "umulExtended" "unpackDouble2x32" "unpackHalf2x16" "unpackSnorm2x16"
      "unpackSnorm4x8" "unpackUnorm2x16" "unpackUnorm4x8" "usubBorrow"))

  (defvar hlsl-deprecated-builtin-list
    '("noise1" "noise2" "noise3" "noise4"
      "texture1D" "texture1DProj" "texture1DLod" "texture1DProjLod"
      "texture2D" "texture2DProj" "texture2DLod" "texture2DProjLod"
      "texture2DRect" "texture2DRectProj"
      "texture3D" "texture3DProj" "texture3DLod" "texture3DProjLod"
      "shadow1D" "shadow1DProj" "shadow1DLod" "shadow1DProjLod"
      "shadow2D" "shadow2DProj" "shadow2DLod" "shadow2DProjLod"
      "textureCube" "textureCubeLod"))

  (defvar hlsl-deprecated-variables-list
    '("gl_FragColor" "gl_FragData" "gl_MaxVarying" "gl_MaxVaryingFloats"
      "gl_MaxVaryingComponents"))

  (defvar hlsl-preprocessor-directive-list
    '("define" "undef" "if" "ifdef" "ifndef" "else" "elif" "endif"
      "error" "pragma" "extension" "version" "line"))

  (defvar hlsl-preprocessor-expr-list
    '("defined" "##"))

  (defvar hlsl-preprocessor-builtin-list
    '("__LINE__" "__FILE__" "__VERSION__"))

  ) ; eval-and-compile

(eval-and-compile
  (defun hlsl-ppre (re)
    (format "\\<\\(%s\\)\\>" (regexp-opt re))))

(defvar hlsl-font-lock-keywords-1
  (append
   (list
    (cons (eval-when-compile
            (format "^[ \t]*#[ \t]*\\<\\(%s\\)\\>"
                    (regexp-opt hlsl-preprocessor-directive-list)))
          hlsl-preprocessor-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-type-list))
          hlsl-type-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-deprecated-qualifier-list))
          hlsl-deprecated-keyword-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-reserved-list))
          hlsl-reserved-keyword-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-qualifier-list))
          hlsl-qualifier-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-keyword-list))
          hlsl-keyword-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-preprocessor-builtin-list))
          hlsl-keyword-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-deprecated-builtin-list))
          hlsl-deprecated-builtin-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-builtin-list))
          hlsl-builtin-face)
    (cons (eval-when-compile
            (hlsl-ppre hlsl-deprecated-variables-list))
          hlsl-deprecated-variable-name-face)
    (cons "gl_[A-Z][A-Za-z_]+" hlsl-variable-name-face)
    )

   (when hlsl-additional-types
     (list
      (cons (hlsl-ppre hlsl-additional-types) hlsl-type-face)))
   (when hlsl-additional-keywords
     (list
      (cons (hlsl-ppre hlsl-additional-keywords) hlsl-keyword-face)))
   (when hlsl-additional-qualifiers
     (list
      (cons (hlsl-ppre hlsl-additional-qualifiers) hlsl-qualifier-face)))
   (when hlsl-additional-built-ins
     (list
      (cons (hlsl-ppre hlsl-additional-built-ins) hlsl-builtin-face)))
   )
  "Highlighting expressions for HLSL mode.")


(defvar hlsl-font-lock-keywords hlsl-font-lock-keywords-1
  "Default highlighting expressions for HLSL mode.")

(defvar hlsl-mode-syntax-table
  (let ((hlsl-mode-syntax-table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" hlsl-mode-syntax-table)
    (modify-syntax-entry ?* ". 23" hlsl-mode-syntax-table)
    (modify-syntax-entry ?\n "> b" hlsl-mode-syntax-table)
    (modify-syntax-entry ?_ "w" hlsl-mode-syntax-table)
    hlsl-mode-syntax-table)
  "Syntax table for hlsl-mode.")

(defvar hlsl-other-file-alist
  '(("\\.frag$" (".vert"))
    ("\\.vert$" (".frag"))
    )
  "Alist of extensions to find given the current file's extension.")

(defun hlsl-man-completion-list ()
  "Return list of all HLSL keywords."
  (append hlsl-builtin-list hlsl-deprecated-builtin-list))

(defun hlsl-find-man-page (thing)
  "Collects and displays manual entry for HLSL built-in function THING."
  (interactive
   (let ((word (current-word nil t)))
     (list
      (completing-read
       (concat "OpenGL.org HLSL man page: (" word "): ")
       (hlsl-man-completion-list)
       nil nil nil nil word))))
  (save-excursion
    (apply hlsl-browse-url-function
           (list (concat hlsl-man-pages-base-url thing ".xhtml")))))

(easy-menu-define hlsl-menu hlsl-mode-map
  "HLSL Menu"
    `("HLSL"
      ["Comment Out Region"     comment-region
       (c-fn-region-is-active-p)]
      ["Uncomment Region"       (comment-region (region-beginning)
						(region-end) '(4))
       (c-fn-region-is-active-p)]
      ["Indent Expression"      c-indent-exp
       (memq (char-after) '(?\( ?\[ ?\{))]
      ["Indent Line or Region"  c-indent-line-or-region t]
      ["Fill Comment Paragraph" c-fill-paragraph t]
      "----"
      ["Backward Statement"     c-beginning-of-statement t]
      ["Forward Statement"      c-end-of-statement t]
      "----"
      ["Up Conditional"         c-up-conditional t]
      ["Backward Conditional"   c-backward-conditional t]
      ["Forward Conditional"    c-forward-conditional t]
      "----"
      ["Backslashify"           c-backslash-region (c-fn-region-is-active-p)]
      "----"
      ["Find HLSL Man Page"  hlsl-find-man-page t]
      ))

;;;###autoload
(define-derived-mode hlsl-mode prog-mode "HLSL"
  "Major mode for editing HLSL shader files."
  (c-initialize-cc-mode t)
  (setq abbrev-mode t)
  (c-init-language-vars-for 'c-mode)
  (c-common-init 'c-mode)
  (cc-imenu-init cc-imenu-c++-generic-expression)
  (set (make-local-variable 'font-lock-defaults) '(hlsl-font-lock-keywords))
  (set (make-local-variable 'ff-other-file-alist) 'hlsl-other-file-alist)
  (set (make-local-variable 'comment-start) "// ")
  (set (make-local-variable 'comment-end) "")
  (set (make-local-variable 'comment-padding) "")
  (easy-menu-add hlsl-menu)
  (add-to-list 'align-c++-modes 'hlsl-mode)
  (c-run-mode-hooks 'c-mode-common-hook)
  (run-mode-hooks 'hlsl-mode-hook)
  :after-hook (progn (c-make-noise-macro-regexps)
		     (c-make-macro-with-semi-re)
		     (c-update-modeline))
  )

;;; hlsl-mode.el ends here
