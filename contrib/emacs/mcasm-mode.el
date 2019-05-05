 ;;; mcasm.el --- Mcasm major mode

 ;; Copyright (C) 2001  Free Software Foundation, Inc.

 ;; Author: StefanMonnier
 ;; Keywords: extensions

 ;; This file is free software; you can redistribute it and/or modify
 ;; it under the terms of the GNU General Public License as published by
 ;; the Free Software Foundation; either version 2, or (at your option)
 ;; any later version.

 ;; This file is distributed in the hope that it will be useful,
 ;; but WITHOUT ANY WARRANTY; without even the implied warranty of
 ;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ;; GNU General Public License for more details.

 ;; You should have received a copy of the GNU General Public License
 ;; along with GNU Emacs; see the file COPYING.  If not, write to
 ;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 ;; Boston, MA 02111-1307, USA.

 ;;; Commentary:

 ;; 

 ;;; Code:

 (defvar mcasm-mode-map
   (let ((map (make-sparse-keymap)))
     (define-key map [foo] 'mcasm-do-foo)
     map)
   "Keymap for `mcasm-mode'.")


 (defvar mcasm-mode-syntax-table
   (let ((st (make-syntax-table)))
     ;(modify-syntax-entry ?# "<" st)
     ;(modify-syntax-entry ?\n ">" st)
     (modify-syntax-entry ?_ "w" st)
     (modify-syntax-entry ?/ "w" st)

     (modify-syntax-entry ?\/ ". 12b" st)
     (modify-syntax-entry ?\n "> b" st)


     st)
   "Syntax table for `mcasm-mode'.")

 (defvar mcasm-font-lock-keywords
   '(("\\(start .+\\)" (1 font-lock-function-name-face))
     ("\\<\\(cond\\|field\\|hold\\|s\\(?:ignal\\|tart\\)\\|uaddr\\)\\>" (1 font-lock-keyword-face))
     ("\\(#\\sw+\\)" (1 font-lock-preprocessor-face))
     ("#\\sw+  *\\(\\sw+\\)" (1 font-lock-variable-name-face))
     ("field *\\(\\sw+\\)" (1 font-lock-constant-face))
     ("cond *\\(\\sw+\\)" (1 font-lock-variable-name-face))
     ("signal *\\([^ #\\,;-]+\\)" (1 font-lock-constant-face))
     )
   "Keyword highlighting specification for `mcasm-mode'.")

 ;;;###autoload
 (define-derived-mode mcasm-mode fundamental-mode "mcasm"
   "A major mode for editing mcasm files."
   :syntax-table mcasm-mode-syntax-table
   (set (make-local-variable 'comment-start) "// ")
   (set (make-local-variable 'comment-start-skip) "//+\\s-*")
   (set (make-local-variable 'font-lock-defaults)
	'(mcasm-font-lock-keywords))
   (set (make-local-variable 'indent-line-function) 'mcasm-indent-line)
   (set (make-local-variable 'imenu-generic-expression)
	mcasm-imenu-generic-expression)
   (set (make-local-variable 'outline-regexp) mcasm-outline-regexp)
   ;...
   )

 ;;; Indentation

 (defun mcasm-indent-line ()
   "Indent current line of Mcasm code."
   (interactive)
   (let ((savep (> (current-column) (current-indentation)))
	 (indent (condition-case nil (max (mcasm-calculate-indentation) 0)
		   (error 0))))
     (if savep
	 (save-excursion (indent-line-to indent))
       (indent-line-to indent))))

; (defun mcasm-calculate-indentation ()
;   "Return the column to which the current line should be indented."
;   ...)


 (provide 'mcasm-mode)

 ;;; mcasm.el ends here


;;; End of file.
