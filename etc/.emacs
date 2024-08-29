(add-hook 'find-file-hook (lambda () (setq buffer-read-only t)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; (setq buffer-read-only t)

(show-paren-mode 1)
(setq column-number-mode t)

;; set windows move keybindings
(windmove-default-keybindings)
;; fix shift key conflicts for moving windows in org mode
(setq org-support-shift-select 'always)
(add-hook 'org-shiftup-final-hook 'windmove-up)
(add-hook 'org-shiftleft-final-hook 'windmove-left)
(add-hook 'org-shiftdown-final-hook 'windmove-down)
(add-hook 'org-shiftright-final-hook 'windmove-right)

(require 'package)
;; (dotspacemacs-elpa-timeout 0 )
(add-to-list 'package-archives
;;           '("melpa" . "http://elpa.org/packages/") t)
;;           '("melpa" . "http://melpa.milkbox.net/packages/") t)
             '("melpa" . "https://melpa.org/packages/") t)



(package-initialize)
(setq url-http-attempt-keepalives nil)

;; set tab-with 4
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq indent-line-function 'insert-tab)

;; auto-complete:
;;
;; (add-to-list 'load-path "/usr/share/auto-complete.opt/")
(require 'auto-complete)
(require 'auto-complete-config)
;; (add-to-list 'ac-dictionary-directories "/usr/share/auto-complete.opt/dict/")
(ac-config-default)
(ac-flyspell-workaround)
(ac-linum-workaround)

;; auto-complete for latex & math in latex
(require 'ac-math)
(add-to-list 'ac-modes 'latex-mode)   ; make auto-complete aware of `latex-mode`

(defun ac-LaTeX-mode-setup () ; add ac-sources to default ac-sources
  (setq ac-sources
	(append '(ac-source-math-unicode ac-source-math-latex ac-source-latex-commands)
		ac-sources))
  )
(add-hook 'LaTeX-mode-hook 'ac-LaTeX-mode-setup)
(global-auto-complete-mode t)

(setq ac-math-unicode-in-math-p t)

;; auto-complete ispell-dictionary
;; `ac-ispell.el' provides ispell/aspell completion source for auto-complete.
;; You can use English word completion with it.

;; Completion words longer than 4 characters
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ac-ispell-fuzzy-limit 4)
 '(ac-ispell-requires 4)
 '(package-selected-packages
   '(pylint markdown-preview-mode flymake-markdownlint vmd-mode ac-etags cl-lib flymake-golangci flymake-go-staticcheck flymake-go flycheck-golangci-lint company-go markdown-mode flyspell-popup flyspell-correct-popup flyspell-correct company-math auto-correct auto-complete helm-ispell ace-flyspell ducpel charmap blacken flycheck-pyflakes py-autopep8 company-jedi jedi find-file-in-project slime epl esup ac-clang ac-c-headers auto-dictionary python-mode fill-column-indicator elpy ac-math ac-ispell)))

(eval-after-load "auto-complete"
  '(progn
              (ac-ispell-setup)))

(add-hook 'git-commit-mode-hook 'ac-ispell-ac-setup)
(add-hook 'mail-mode-hook 'ac-ispell-ac-setup)
(add-hook 'LaTeX-mode-hook 'ac-ispell-ac-setup)

;;
;; end auto-complete



(global-linum-mode)
(setq linum-format "%4d \u2502")
;; (setq toggle-truncate-lines t)
(setq-default truncate-lines t)

;; (flyspell-mode 1)
(add-hook 'text-mode-hook 'flyspell-mode)
(add-hook 'prog-mode-hook 'flyspell-prog-mode)
;; (setq ispell-dictionary "en_US")
;; (setq ispell-dictionary "en")



;; (setq desktop-auto-save-timeout nil
;;       desktop-save 'ask-if-new
;;       desktop-dirname "./"
;;       desktop-path (list desktop-dirname)
;;       desktop-load-locked-desktop nil)

;; (desktop-save-mode 1)




;; ;; Setup load-path and autoloads
;; (add-to-list 'load-path "~/dir/to/cloned/slime")
;; (require 'slime-autoloads)

;; ;; Set your lisp system and some contribs
;; (setq inferior-lisp-program "/opt/sbcl/bin/sbcl")
;; (setq slime-contribs '(slime-scratch slime-editing-commands))


;; https://www.common-lisp.net/project/slime/doc/html/Loading-Contribs.html
;; (setq slime-contribs '(slime-repl)) ; repl only
(setq slime-contribs '(slime-fancy)) ; almost everything

;; Color theme
;; (load-theme 'manoj-dark)
(load-theme 'tsdh-dark)

;; 80 char column highlight - whitespace package:
;; (setq whitespace-style '(face empty lines-tail trailing))
(require 'whitespace)
(setq whitespace-style '(face empty trailing))
(global-whitespace-mode t)

;; 80 char column highlight - fill-column-indicator package
(add-to-list 'load-path "~/.emacs.d/fill-column-indicator-1.83")
(require 'fill-column-indicator)
(define-globalized-minor-mode
 global-fci-mode fci-mode (lambda () (fci-mode 1)))
(global-fci-mode t)
(setq fci-rule-column 80)
(setq-default fill-column 80)

;; Python environment:
; use IPython
;; (when (executable-find "ipython")
;;   (setq python-shell-interpreter "ipython"))


;; (require 'python)
;; (setq python-shell-interpreter "ipython")
;; (setq python-shell-interpreter-args "-i --pylab")
(require 'python)

;; package needed for elpy env.
;; pip install --user jedi rope autopep8 Yapf flake8 black
;; add local installation path to execution path and
;; Use elpy-config to confirm proper installation
(add-to-list 'exec-path "~/.local/bin")


;; elpy from gitrepo - branch backport-emacs23.4
(add-to-list 'load-path "~/.emacs.d/elpy/elpy")
(add-to-list 'load-path "~/.emacs.d/find-file-in-project")

;; (load "elpy")
;;;; (load "elpy-rpc")
;; (load "elpy-shell")
;; (load "elpy-profile")
;; (load "elpy-refactor")
;; (load "elpy-django")


;; (elpy-enable)
(setq python-shell-interpreter "ipython"
      python-shell-interpreter-args " -i --colors=Linux --profile=default"
      ;; python-shell-interpreter-args "--simple-prompt -i --colors=Linux --profile=default"
      ;; ;; from https://stackoverflow.com/questions/25669809/how-do-you-run-python-code-using-emacs
      python-shell-prompt-regexp "In \\[[0-9]+\\]: "
      python-shell-prompt-output-regexp "Out\\[[0-9]+\\]: "
      python-shell-completion-setup-code
      "from IPython.core.completerlib import module_completion"
      python-shell-completion-module-string-code
      "';'.join(module_completion('''%s'''))\n"
      python-shell-completion-string-code
       "';'.join(get_ipython().Completer.all_completions('''%s'''))\n"
      )
(add-hook 'python-mode 'run-python)
;; Temporarily enable flake from emacs.d until I understand how to setup pyvirtenv
;; needs an alias in bash for flake8 executable
(add-to-list 'exec-path "~/.emacs.d/elpy/rpc-venv/bin/")
(setq python-check-command (expand-file-name "~/.emacs.d/elpy/rpc-venv/bin/flake8"))

;; source: http://www.jesshamrick.com/2012/09/18/emacs-as-a-python-ide/
;;
;; (setq-default py-shell-name "ipython")
;; (setq-default py-which-bufname "IPython")
;; ; use the wx backend, for both mayavi and matplotlib
;; (setq py-python-command-args
;;   '("--gui=wx" "--pylab=wx" "-colors" "Linux"))
;; (setq py-force-py-shell-name-p t)

;; ; switch to the interpreter after executing code
;; (setq py-shell-switch-buffers-on-execute-p t)
;; (setq py-switch-buffers-on-execute-p t)
;; ; don't split windows
;; (setq py-split-windows-on-execute-p nil)
;; ; try to automagically figure out indentation
;; (setq py-smart-indentation t)


;; PlSql extension to sql-mode
;; source https://www.emacswiki.org/emacs/PlsqlMode
; (add-to-list 'load-path  "~/.emacs.d/plsql-mode")
; (require 'plsql)

;; ;; Twiki-mode
;; ;; source: http://www.twiki.org/cgi-bin/view/Plugins/EmacsModeAddOn

;; (add-to-list 'load-path  "~/.emacs.d/twiki-mode")
;; (require 'twiki)
;; (add-to-list 'auto-mode-alist'("\\.twiki$" . twiki-mode))
;; (setq twiki-shell-cmd "~/.emacs.d/twiki-mode/twikish")


(setq comint-password-prompt-regexp
      (concat comint-password-prompt-regexp
	            "\\|^Enter passphrase for .*:\\s *\\'"))

(setq comint-password-prompt-regexp
      (concat comint-password-prompt-regexp
	            "\\|^Passphrase for .*:\\s *\\'"))

(setq comint-password-prompt-regexp
      (concat comint-password-prompt-regexp
	            "\\|^Password for .*:\\s *\\'"))

(setq comint-password-prompt-regexp
      (concat comint-password-prompt-regexp
	            "\\|^enter.*decryption password.*:\\s *\\'"))

(setq comint-password-prompt-regexp
      (concat comint-password-prompt-regexp
	            "\\|^[eE]nter.*GRID.*pass.*:\\s *\\'"))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; ;; Tetris related configs:
;; (load "~/.emacs.d/gamegrid.el")
;; (setq gamegrid-glyph-height-mm 16.0)

;; Window Resize key bindings
;; Original keys:
;;    `C-x ^’ makes the current window taller (‘enlarge-window’)
;;    `C-x }’ makes it wider (‘enlarge-window-horizontally’)
;;    `C-x {’ makes it narrower (‘shrink-window-horizontally’)
(global-set-key (kbd "S-M-<left>") 'shrink-window-horizontally)
(global-set-key (kbd "S-M-<right>") 'enlarge-window-horizontally)
(global-set-key (kbd "S-M-<down>") 'shrink-window)
(global-set-key (kbd "S-M-<up>") 'enlarge-window)



;; conf-mode for .ini and DockerFiles
(add-to-list 'auto-mode-alist '("\\.ini\\'" . conf-mode))
(add-to-list 'auto-mode-alist '("\\DockerFile*\\'" . conf-mode))

;; go-mode:
(add-to-list 'load-path "~/.emacs.d/elpa/go-mode-20230823.2304/")
(require 'go-mode)
;; (require 'go-mode-autoloads)

;; flymake-golanci
;; (require 'flymake-golanci)
;; (add-hook 'go-mode-hook 'flymake-golangci-load)

