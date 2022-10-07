;;; hlsl-mode.el --- Major mode for HLSL shader files  -*- lexical-binding: t; -*-

;; Copyright (C) 1999, 2000, 2001 Free Software Foundation, Inc.
;; Copyright (C) 2011, 2014, 2019 Jim Hourihan
;; Copyright (C) 2022 Jcaw
;;
;; Authors: Xavier.Decoret@imag.fr,
;;          Jim Hourihan <jimhourihan ~at~ gmail.com>
;;          GitHub user "jcaw"
;; Keywords: languages HLSL GPU shaders
;; Version: 1.1.3
;; URL: https://github.com/jcaw/hlsl-mode
;; Package-Requires: ((emacs "24.4"))
;;
;; Original URL http://artis.inrialpes.fr/~Xavier.Decoret/resources/glsl-mode/

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
;;    builtin functions and variables for HLSL (up to the version specified
;;    by `hlsl-shader-model-version')
;;  * Indentation for the current line (TAB) and selected region (C-M-\).

;;; Code:

(require 'cc-mode)

(eval-when-compile                   ; required and optional libraries
  (require 'find-file)
  (require 'subr-x))

(require 'align)

(defgroup hlsl nil
  "Microsoft HLSL Major Mode."
  :group 'languages)

(defconst hlsl-shader-model-version "6.0"
  "Shader model version number.")

(defconst hlsl-direct3d-version "12"
  "Direct3D language version number.")

(defvar hlsl-type-face 'hlsl-type-face)
(defface hlsl-type-face
  '((t (:inherit font-lock-type-face))) "HLSL: type face."
  :group 'hlsl)

(defvar hlsl-builtin-face 'hlsl-builtin-face)
(defface hlsl-builtin-face
  '((t (:inherit font-lock-builtin-face))) "HLSL: builtin face."
  :group 'hlsl)

(defvar hlsl-deprecated-builtin-face 'hlsl-deprecated-builtin-face)
(defface hlsl-deprecated-builtin-face
  '((t (:inherit font-lock-warning-face))) "HLSL: deprecated builtin face."
  :group 'hlsl)

(defvar hlsl-qualifier-face 'hlsl-qualifier-face)
(defface hlsl-qualifier-face
  '((t (:inherit font-lock-keyword-face))) "HLSL: qualifier face."
  :group 'hlsl)

(defvar hlsl-keyword-face 'hlsl-keyword-face)
(defface hlsl-keyword-face
  '((t (:inherit font-lock-keyword-face))) "HLSL: keyword face."
  :group 'hlsl)

(defvar hlsl-deprecated-keyword-face 'hlsl-deprecated-keyword-face)
(defface hlsl-deprecated-keyword-face
  '((t (:inherit font-lock-warning-face))) "HLSL: deprecated keyword face."
  :group 'hlsl)

(defvar hlsl-variable-name-face 'hlsl-variable-name-face)
(defface hlsl-variable-name-face
  '((t (:inherit font-lock-variable-name-face))) "HLSL: variable face."
  :group 'hlsl)

(defvar hlsl-deprecated-variable-name-face 'hlsl-deprecated-variable-name-face)
(defface hlsl-deprecated-variable-name-face
  '((t (:inherit font-lock-warning-face))) "HLSL: deprecated variable face."
  :group 'hlsl)

(defvar hlsl-reserved-keyword-face 'hlsl-reserved-keyword-face)
(defface hlsl-reserved-keyword-face
  '((t (:inherit hlsl-keyword-face))) "HLSL: reserved keyword face."
  :group 'hlsl)

(defvar hlsl-preprocessor-face 'hlsl-preprocessor-face)
(defface hlsl-preprocessor-face
  '((t (:inherit font-lock-preprocessor-face))) "HLSL: preprocessor face."
  :group 'hlsl)

(defcustom hlsl-additional-types nil
  "List of additional keywords to be considered types.

These are added to the `hlsl-type-list' and are fontified using
the `hlsl-type-face'. Examples of existing types include
\"float\", \"float4\", and \"RWStructuredBuffer\"."
  :type '(repeat (string :tag "Type Name"))
  :group 'hlsl)

(defcustom hlsl-additional-qualifiers nil
  "List of additional keywords to be considered qualifiers.

These are added to the `hlsl-qualifier-list' and are fontified
using the `hlsl-qualifier-face'. Examples of existing qualifiers
include \"const\", \"in\", and \"out\"."
  :type '(repeat (string :tag "Qualifier Name"))
  :group 'hlsl)

(defcustom hlsl-additional-keywords nil
  "List of additional HLSL keywords.

These are added to the `hlsl-keyword-list' and are fontified
using the `hlsl-keyword-face'. Example existing keywords include
\"while\", \"if\", and \"return\"."
  :type '(repeat (string :tag "Keyword"))
  :group 'hlsl)

(defcustom hlsl-additional-built-ins nil
  "List of additional functions to be considered built-in.

These are added to the `hlsl-builtin-list' and are fontified
using the `hlsl-builtin-face'."
  :type '(repeat (string :tag "Keyword"))
  :group 'hlsl)

(defvar hlsl-mode-map
  (let ((hlsl-mode-map (make-sparse-keymap)))
    (define-key hlsl-mode-map [S-iso-lefttab] 'ff-find-other-file)
    hlsl-mode-map)
  "Keymap for HLSL major mode.")

;; (defcustom hlsl-browse-url-function 'browse-url
;;   "Function used to display HLSL man pages.

;; E.g. `browse-url', `eww', `w3m', etc."
;;   :type 'function
;;   :group 'hlsl)

;; (defcustom hlsl-man-pages-base-url "http://www.opengl.org/sdk/docs/man/html/"
;;   "Location of GL man pages."
;;   :type 'string
;;   :group 'hlsl)

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.fx\\'" . hlsl-mode))
  (add-to-list 'auto-mode-alist '("\\.fxc\\'" . hlsl-mode))
  (add-to-list 'auto-mode-alist '("\\.fxh\\'" . hlsl-mode))
  (add-to-list 'auto-mode-alist '("\\.hlsl\\'" . hlsl-mode))
  (add-to-list 'auto-mode-alist '("\\.cg\\'" . hlsl-mode))
  ;; Unity shader format
  (add-to-list 'auto-mode-alist '("\\.shader\\'" . hlsl-mode))
  ;; Unity shader include suffix
  (add-to-list 'auto-mode-alist '("\\.cginc\\'" . hlsl-mode))
  ;; Unity compute shaders are HLSL
  (add-to-list 'auto-mode-alist '("\\.compute\\'" . hlsl-mode))
  )

(eval-and-compile
  (defun hlsl--mixed-case (strings)
    "Get original `strings', plus lowercase and uppercase versions.

For example:

  (hlsl--mixed-case '(\"TexCoord\" \"POSITION\"))
      -> '(\"TexCoord\" \"TEXCOORD\" \"Texcoord\"
           \"POSITION\" \"Position\")

Returns a flattened list of all the resultant strings (without
duplicates)."
    (apply #'append (mapcar (lambda (s)
                              (if (= 0 (length s))
                                  s
                                (delete-dups
                                 (list s (upcase s)
                                       (concat (upcase (substring s 0 1))
                                               (downcase (substring s 1)))))))
                            strings)))

  ;; These vars are useful for completion so keep them around after compile as
  ;; well. The goal here is to have the byte compiled code have optimized
  ;; regexps so its not done at eval time.
  (defvar hlsl-type-list
    `(
      ;; TODO: Maybe make `void' a keyword?
      "matrix" "void"

      ;; Numeric scalars, plus all the vector and matrix expressions for each. E.g:
      ;; float, float1, float1x2, uint2, bool3x4, etc.
      ,@(mapcar (lambda (type)
                  (concat type "\\([1234]?\\|\\([1234]x[1234]\\)?\\)"))
                '("bool" "int" "uint" "float"
                  "min16float" "min10float" "min16int" "min12int" "min16uint"))
      ;; These numeric scalars don't expand to vectors/matrices
      "half" "dword" "double"

      ;; Texture samplers
      "sampler" "sampler1D" "sampler2D" "sampler3D" "samplerCUBE" "sampler_state"
      "SamplerState" "SampleComparisonState"

      ;; Buffer-esque types
      "AppendStructuredBuffer" "Buffer" "ByteAddressBuffer" "ConsumeStructuredBuffer"
      "InputPatch" "OutputPatch" "RWBuffer" "RWByteAddressBuffer" "RWStructuredBuffer"
      "RWTexture1D" "RWTexture1DArray" "RWTexture2D" "RWTexture2DArray" "RWTexture3D"
      "StructuredBuffer" "Texture1D" "Texture1DArray" "Texture2D" "Texture2DArray"
      "Texture2DMS" "Texture2DMSArray" "Texture3D" "TextureCube" "TextureCubeArray"
      ;; Rasterizer Order Views
      "RasterizerOrderedBuffer" "RasterizerOrderedByteAddressBuffer" "RasterizerOrderedStructuredBuffer"
      "RasterizerOrderedTexture1D" "RasterizerOrderedTexture1DArray" "RasterizerOrderedTexture2D"
      "RasterizerOrderedTexture2DArray" "RasterizerOrderedTexture3D"

      ;; Misc
      ;;
      ;; TODO: Double check Object2 usage
      "Object2"

      ;; Geometry shader stream outputs
      "PointStream" "LineStream" "TriangleStream"))

  (defvar hlsl-qualifier-list
    '(
      ;; Misc
      "snorm" "unorm" "in" "inline" "inout" "precise" "extern" "nointerpolation"
      "precise" "shared" "groupshared" "static" "uniform" "volatile" "const"
      "row_major" "column_major" "export" "linear" "centroid" "noperspective"
      "sample" "globallycoherent" "out"

      ;; Geom shader primitives
      "point" "line" "triangle" "lineadj" "triangledj"

      "pixelfragment" "vertexfragment"))

  (defvar hlsl-keyword-list
    `(
      ;; Special types
      "true" "false" "NULL" "null"

      ;; Misc
      "compile_fragment" "class" "interface" "break" "continue" "do" "default"
      "discard" "for" "while" "if" "else" "return" "struct" "switch" "case"
      "register" "packoffset" "cbuffer" "tbuffer" "fxgroup" "pass"
      "technique[1-9]?[1-9]?"
      "SetVertexShader" "SetGeometryShader" "SetPixelSader"

      ;; Attributes
      "maxvertexcount" "domain" "earlydepthstencil" "instance" "maxtessfactor"
      "numthreads" "outputcontrolpoints" "outputtopology" "partitioning"
      "patchconstantfunc"
      ;; domain types
      ;; TODO: move these into a dedicated domain matcher?
      ;; TODO: `point' and `line' at least are duplicated here and in qualifiers
      ;; TODO: Take another look at these, they should probably be handled differently
      "tri" "quad" "isoline" "point" "line" "triangle_cw" "triangle_ccw"
      "integer" "fractional_even" "fractional_odd" "pow2"
      ;; Branching attributes
      "unroll" "loop" "fastopt" "allow_uav_condition" "branch" "flatten"
      "forcecase" "call"

      ;; Shader profiles
      ;;
      ;; Shader Model 1
      "vs_1_1"
      ;; Shader Model 2
      "ps_2_0" "ps_2_x" "vs_2_0" "vs_2_x" "ps_4_0_level_9_0" "ps_4_0_level_9_1"
      "ps_4_0_level_9_3" "vs_4_0_level_9_0" "vs_4_0_level_9_1" "vs_4_0_level_9_3"
      "lib_4_0_level_9_1" "lib_4_0_level_9_"
      ;; Shader Model 3
      "ps_3_0" "vs_3_0"
      ;; Shader Model 4
      "cs_4_0" "gs_4_0" "ps_4_0" "vs_4_0" "cs_4_1" "gs_4_1" "ps_4_1" "vs_4_1"
      "lib_4_0" "lib_4_"
      ;; Shader Model 5
      "cs_5_0" "ds_5_0" "gs_5_0" "hs_5_0" "ps_5_0" "vs_5_0" "lib_5_"
      ;; Shader Model 6
      "cs_6_0" "ds_6_0" "gs_6_0" "hs_6_0" "ps_6_0" "vs_6_0" "lib_6_"
      ;; FX Profiles
      "fx_1_0" "fx_2_0" "fx_4_0" "fx_4_1" "fx_5_0"

      ;; Semantics
      ;;
      ;; All semantics are case-insensitive, so allow uppercase, lowercase and
      ;; capitalised versions. Other/weird mixtures of case will not be
      ;; highlighted for now, even though the HLSL spec allows them.
      ,@(hlsl--mixed-case
         '("Binormal[0-9]?" "BlendIndices[0-9]?" "BlendWeight[0-9]?" "Color[0-9]?"
           "Normal[0-9]?" "Position[0-9]?" "PositionT" "PSize[0-9]?" "Tangent[0-9]?"
           "TexCoord[0-9]" "Fog" "TessFactor[0-9]?" "VFace" "VPos" "Depth[0-9]?"
           "SV_ClipDistance[0-9]?" "SV_CullDistance[0-9]?" "SV_Coverage" "SV_Depth"
           "SV_DepthGreaterEqual" "SV_DepthLessEqual" "SV_DispatchThreadID"
           "SV_DomainLocation" "SV_GroupID" "SV_GroupIndex" "SV_GroupThreadID"
           "SV_GSInstanceID" "SV_InnerCoverage" "SV_InsideTessFactor" "SV_InstanceID"
           "SV_IsFrontFace" "SV_OutputControlPointID" "SV_Position" "SV_PrimitiveID"
           "SV_RenderTargetArrayIndex" "SV_SampleIndex" "SV_StencilRef" "SV_Target[0-7]"
           "SV_TessFactor" "SV_VertexID" "SV_ViewportArrayIndex" "SV_ShadingRate"
           "SV_Target"
           ;; Misc Semantics
           "BezierPos" "WorldPos" "TanUCorner" "TanVCorner" "TanWeights" "Bitangent[0-9]?"))

      ;; Unity keywords
      ;;
      ;; TODO: Separate derived mode for Unity ".shader" files? They're not strictly HLSL.
      "Shader" "Properties" "SubShader" "Tags" "Pass" "CGPROGRAM" "ENDCG"))

  (defvar hlsl-reserved-list
    '(
      ;; [2022/01/31] Just the reserved words found on:
      ;; https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-appendix-reserved-words
      "auto" "case" "catch" "char" "class" "const_cast" "default" "delete" "dynamic_cast"
      "enum" "explicit" "friend" "goto" "long" "mutable" "new" "operator" "private"
      "protected" "public" "reinterpret_cast" "short" "signed" "sizeof" "static_cast"
      "template" "this" "throw" "try" "typename" "union" "unsigned" "using" "virtual"))

  (defvar hlsl-deprecated-qualifier-list
    '())

  (defvar hlsl-builtin-list

    '(
      ;; This is the list of the builtins taken directly from the Direct3D 12 docs (Shader Model 6.0)
      "abort" "abs" "acos" "all" "AllMemoryBarrier" "AllMemoryBarrierWithGroupSync"
      "any" "asdouble" "asfloat" "asin" "asint" "asint" "asuint" "asuint" "atan" "atan2"
      "ceil" "CheckAccessFullyMapped" "clamp" "clip" "cos" "cosh" "countbits" "cross"
      "D3DCOLORtoUBYTE4" "ddx" "ddx_coarse" "ddx_fine" "ddy" "ddy_coarse" "ddy_fine"
      "degrees" "determinant" "DeviceMemoryBarrier" "DeviceMemoryBarrierWithGroupSync"
      "distance" "dot" "dst" "errorf" "EvaluateAttributeAtCentroid" "EvaluateAttributeAtSample"
      "EvaluateAttributeSnapped" "exp" "exp2" "f16tof32" "f32tof16" "faceforward"
      "firstbithigh" "firstbitlow" "floor" "fma" "fmod" "frac" "frexp" "fwidth"
      "GetRenderTargetSampleCount" "GetRenderTargetSamplePosition" "GroupMemoryBarrier"
      "GroupMemoryBarrierWithGroupSync" "InterlockedAdd" "InterlockedAnd"
      "InterlockedCompareExchange" "InterlockedCompareStore" "InterlockedExchange"
      "InterlockedMax" "InterlockedMin" "InterlockedOr" "InterlockedXor" "isfinite"
      "isinf" "isnan" "ldexp" "length" "lerp" "lit" "log" "log10" "log2" "mad" "max"
      "min" "modf" "msad4" "mul" "noise" "normalize" "pow" "printf"
      "Process2DQuadTessFactorsAvg" "Process2DQuadTessFactorsMax" "Process2DQuadTessFactorsMin"
      "ProcessIsolineTessFactors" "ProcessQuadTessFactorsAvg" "ProcessQuadTessFactorsMax"
      "ProcessQuadTessFactorsMin" "ProcessTriTessFactorsAvg" "ProcessTriTessFactorsMax"
      "ProcessTriTessFactorsMin" "radians" "rcp" "reflect" "refract" "reversebits"
      "round" "rsqrt" "saturate" "sign" "sin" "sincos" "sinh" "smoothstep" "sqrt"
      "step" "tan" "tanh" "tex1D" "tex1Dbias" "tex1Dgrad" "tex1Dlod" "tex1Dproj"
      "tex2D" "tex2Dbias" "tex2Dgrad" "tex2Dlod" "tex2Dproj" "tex3D" "tex3Dbias"
      "tex3Dgrad" "tex3Dlod" "tex3Dproj" "texCUBE" "texCUBEbias" "texCUBEgrad" "texCUBElod"
      "texCUBEproj" "transpose" "trunc"

      ;; Geometry shader streams
      "Append" "RestartStrip"

      ;; Textures/Buffers
      "CalculateLevelOfDetail" "CalculateLevelOfDetailUnclamped" "Gather" "GetDimensions"
      "GetSamplePosition" "Sample" "SampleBias" "SampleCmp" "SampleGrad" "SampleLevel"
      "Operator\\[\\]" "Load[234]?" "Store[234]?"
      "GatherRed" "GatherGreen" "GatherBlue" "GatherAlpha" "GatherCmp" "GatherCmpRed"
      "GatherCmpGreen" "GatherCmpBlue" "GatherCmpAlpha"
      "Sample" "SampleBias" "SampleCmp" "SampleCmpLevelZero" "SampleGrad" "SampleLevel"

      ;; Wave Intrinsics
      "QuadReadAcrossDiagonal" "QuadReadLaneAt" "QuadReadAcrossX" "QuadReadAcrossY"
      "WaveActiveAllEqual" "WaveActiveBitAnd" "WaveActiveBitOr" "WaveActiveBitXor"
      "WaveActiveCountBits" "WaveActiveMax" "WaveActiveMin" "WaveActiveProduct"
      "WaveActiveSum" "WaveActiveAllTrue" "WaveActiveAnyTrue" "WaveActiveBallot"
      "WaveGetLaneCount" "WaveGetLaneIndex" "WaveIsFirstLane" "WavePrefixCountBits"
      "WavePrefixProduct" "WavePrefixSum" "WaveReadLaneFirst" "WaveReadLaneAt"

      ;; Unsorted
      "Consume" "DecrementCounter" "IncrementCounter"))

  (defvar hlsl-deprecated-builtin-list
    '())

  (defvar hlsl-deprecated-variables-list
    '())

  (defvar hlsl-preprocessor-directive-list
    '(
      "define" "elif" "else" "endif" "error" "if" "ifdef" "ifndef" "include"
      "line" "pragma" "undef"))

  (defvar hlsl-preprocessor-expr-list
    '(
      ;; Taken directly from glsl-mode - not audited yet
      "defined" "##"))

  (defvar hlsl-preprocessor-builtin-list
    '(
      ;; Taken directly from glsl-mode - not audited yet
      "__LINE__" "__FILE__" "__VERSION__"))

  ;; TODO: Highlighting for annotations   <int something=27;>

  ) ; eval-and-compile

(eval-and-compile
  (defun hlsl-ppre (re)
    ;; FIXME: This doesn't sanitise the inputs, so a bad member could corrupt the whole expression
    (format "\\<\\(%s\\)\\>" (string-join re "\\|"))))

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
    ;; Swizzles are a special case. We want to highlight swizzles only when
    ;; they're after a dot, but we don't want to highlight the dot itself.
    (list (eval-when-compile
            ;; TODO: Maybe these types of swizzles?
            ;; /\.\(_m[0-3]\{2}\)\{1,4\}/
            ;; /\.\(_[1-4]\{2}\)\{1,4\}/
            "\\.\\_<\\([xyzw]\\{1,4\\}\\|[rgba]\\{1,4\\}\\)\\_>")
          '(1 hlsl-builtin-face))
    ;; TODO: What to do about dedicated named variables?
    ;; (cons "unity_[A-Z0-9a-z_]+" hlsl-variable-name-face)
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
  "Syntax table for `hlsl-mode'.")

(defvar hlsl-other-file-alist
  ;; TODO: Add common pairings, e.g. vert & corresponding frag files, perhaps
  ;;   also geom
  '()
  "Alist of extensions to find given the current file's extension.")

(defun hlsl-man-completion-list ()
  "Return list of all HLSL keywords."
  (append hlsl-builtin-list hlsl-deprecated-builtin-list))

;; TODO: Switch over to HLSL docs?
;; (defun hlsl-find-man-page (thing)
;;   "Collects and displays manual entry for HLSL built-in function THING."
;;   (interactive
;;    (let ((word (current-word nil t)))
;;      (list
;;       (completing-read
;;        (concat "OpenGL.org HLSL man page: (" word "): ")
;;        (hlsl-man-completion-list)
;;        nil nil nil nil word))))
;;   (save-excursion
;;     (apply hlsl-browse-url-function
;;            (list (concat hlsl-man-pages-base-url thing ".xhtml")))))

;; TODO: Maybe remove easy menu?
(easy-menu-define hlsl-menu hlsl-mode-map
  "HLSL Menu."
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
  ;; TODO: Indentation rules for annotated for loops, e.g:
  ;;     [unroll] for (...) {
  ;;     --->|
  ;;     }
  ;;   Currently it just indents flat as though no scope was declared
  (add-to-list 'align-c++-modes 'hlsl-mode)
  (c-run-mode-hooks 'c-mode-common-hook)
  (run-mode-hooks 'hlsl-mode-hook)
  ;; TODO: Guard `c-make-noise-macro-regexps' based on Emacs version, then lower
  ;;   dependency.
  :after-hook (progn (when (fboundp 'c-make-noise-macro-regexps)
                       ;; Depends on Emacs 26.1, guarding this allows us to
                       ;; support down to Emacs 24.4
                       (c-make-noise-macro-regexps))
                     (c-make-macro-with-semi-re)
                     (c-update-modeline)))


;; TODO: Float number highlighting (i.e. 1.0f)
;; TODO: Negative number highlighting
;; TODO: Highlight numbers adjacent to operators e.g. 1-variable


(provide 'hlsl-mode)
;;; hlsl-mode.el ends here
