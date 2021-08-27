;;; ironkey.el --- Summary -*- lexical-binding: t; -*-

;; Copyright 2021 Google LLC
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;      http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.
;;
;; SPDX-License-Identifier: Apache-2.0

;;; Commentary:
;;
;; This package provides functions to protect certain key-bindings in certain
;; keymaps.  It mainly does this in two ways when ironkey-mode is enabled:
;;
;; 1. For each (key . map) pair in ironkey-iron-alist, if there's an attempt to
;; bind KEY in MAP to a different value, ironkey will not perform such binding.
;; When MAP is nil, ironkey protects KEY in global-map.
;;
;; 2. To avoid clashing of minor mode maps, local map and global map, ironkey
;; will also, for each of the (key . map) pairs, force the binding of KEY in MAP
;; to have higher priority when MAP is active in the current buffer.  This is
;; done by the ironkey-update function, which can also be called to manually
;; refresh the status.
;;
;; The custom variable ironkey-iron-alist should be set as an alist of (key
;; . map) pairs.  Note KEY should be an internal representation of the key
;; combo, which can usually be obtained by the kbd function.  For example:
;;
;; (setq ironkey-iron-alist `((,(kbd "M-.") . nil)
;;                            (,(kbd "<tab>") . company-mode-map)))

;;; Code:

(defvar ironkey-mode)

(defcustom ironkey-iron-alist nil
  "List of (key . map) pairs for 'ironkey-mode'.
Key should be a proper key binding, and map should be
keymap or nil (for global map)."
  :group 'ironkey
  :type 'alist)

(defcustom ironkey-verbose t
  "How ironkey mode should emit messages.
Use 'warn for warnings, 'error for errors.
Set it to t so ironkey mode will use message,
or set to nil to suppress any messages."
  :group 'ironkey
  :type '(choice (const :tag "Warn" warn)
                 (const :tag "Error" error)
                 (const :tag "Mesesage" t)
                 (const :tag "No message" nil)))

(defun ironkey-msg (msg)
  "Prompt the user of MSG, according to 'ironkey-verbose'."
  (cond ((eq ironkey-verbose 'warn)
         (warn msg))
        ((eq ironkey-verbose 'error)
         (error msg))
        (ironkey-verbose
         (message msg))))

(defun ironkey-update ()
  "Update 'ironkey-mode' status."
  (interactive)
  (when
      (not (minibufferp))
    (if ironkey-mode
        (progn
          ;; Temporarily remove advice to avoid infinite loop.
          (advice-remove 'define-key #'ironkey-define-key)
          (when (not minor-mode-overriding-map-alist)
            (setq-local minor-mode-overriding-map-alist '()))
          (setq-local minor-mode-overriding-map-alist
                      (assoc-delete-all 'ironkey-mode minor-mode-overriding-map-alist))
          (let ((map (make-sparse-keymap)))
            (dolist (check-bind ironkey-iron-alist)
              (let ((exist-def)
                    (check-key (car check-bind))
                    (check-map (cdr check-bind)))
                (when (not check-map)
                  (setq check-map 'global-map))
                (when (or (eq check-map 'global-map) (member (eval check-map) (current-active-maps)))
                  (setq exist-def (lookup-key (eval check-map) check-key))
                  (when (and (commandp exist-def) (command-remapping exist-def nil (eval check-map)))
                    (setq exist-def (command-remapping exist-def)))
                  (when (or (not exist-def) (numberp exist-def))
                    (setq exist-def nil))
                  (define-key map check-key exist-def))))
            (setq-local minor-mode-overriding-map-alist
                        (cons `(ironkey-mode . ,map)
                              minor-mode-overriding-map-alist)))
          (advice-add 'define-key :around #'ironkey-define-key))
      (ironkey-msg "Ironkey-mode not activated."))))

(defun ironkey-define-key (orig-fun keymap key def)
  "Function used to advice the ORIG-FUN 'define-key'.
The definitions of KEYMAP, KEY and DEF can be found in
function 'define-key'.  This function protects the key-bindings listed in
'ironkey-iron-alist' from getting changed by 'define-key'."
  (if (not ironkey-mode)
      (funcall orig-fun keymap key def)

    (let ((orig-def (lookup-key keymap key))
          (conflict-def)
          (conflict-key)
          (conflict-map))
      (dolist (check-bind ironkey-iron-alist)
        (when (not conflict-def)
          ;; first check whether the protected key-binding exists in the keymap
          (let ((exist-def)
                (new-def)
                (check-key (car check-bind))
                (check-map (cdr check-bind)))
            (when (not check-map)
              (setq check-map 'global-map))
            (setq exist-def (lookup-key (eval check-map) check-key))
            (when (and (commandp exist-def) (command-remapping exist-def nil (eval check-map)))
              (setq exist-def (command-remapping exist-def)))
            ;; if exists such protected key-binding, check whether it is changed if we do this define-key
            (when (and exist-def (not (numberp exist-def)))
              (funcall orig-fun keymap key def)
              (setq new-def (lookup-key (eval check-map) check-key))
              (when (and (commandp new-def) (command-remapping new-def nil (eval check-map)))
                (setq exist-def (command-remapping exist-def)))
              (funcall orig-fun keymap key orig-def)
              (when (not (equal new-def exist-def))
                (setq conflict-def exist-def)
                (setq conflict-key check-key)
                (setq conflict-map check-map))))))

      (if (not conflict-def)
          (funcall orig-fun keymap key def)
        (let ((str (format "Could not set key. Ironkey detected conflicts with \"%s\" in %s!"
                           (key-description conflict-key)
                           (if conflict-map
                               (symbol-name conflict-map)
                             "global-map"))))
          (ironkey-msg str))))
    (ironkey-update)))

(define-minor-mode ironkey-mode
  "Enable ironkey mode."
  :group 'ironkey
  :global t
  (if ironkey-mode
      (progn
        (ironkey-update)
        (add-hook 'after-change-major-mode-hook 'ironkey-update)
        (dolist (check-bind ironkey-iron-alist)
          (let ((check-map (cdr check-bind))
                (this-mode))
            (when check-map
              (setq this-mode (car (rassoc (eval check-map) minor-mode-map-alist)))
              (when this-mode
                (add-hook (intern (concat (symbol-name this-mode) "-hook"))
                          #'ironkey-update))))))
    (remove-hook 'after-change-major-mode-hook 'ironkey-update)
    (dolist (check-bind ironkey-iron-alist)
      (let ((check-map (cdr check-bind))
            (this-mode))
        (when check-map
          (setq this-mode (car (rassoc (eval check-map) minor-mode-map-alist)))
          (when this-mode
            (remove-hook (intern (concat (symbol-name this-mode) "-hook"))
                         'ironkey-update)))))))

(advice-add 'define-key :around #'ironkey-define-key)

;; TODO: add functions to add/remove bindings from ironkey-iron-alist.
;; TODO: add a function to forcefully update a key-binding that we protect
;;       (currently need to temporarily turn off ironkey-mode).
;; TODO: add use-package support for such a function too.
;; TODO: add commands to add/remove iron keys with completing-read.

(provide 'ironkey)
;;; ironkey.el ends here
