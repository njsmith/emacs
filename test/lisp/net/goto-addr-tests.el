;;; goto-addr-tests.el --- Tests for goto-addr.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Code:

(require 'goto-addr)
(require 'ert)

(ert-deftest goto-addr-tests-url-overlay ()
  (with-temp-buffer
    (insert "see https://example.com/x for details\n")
    (goto-address-fontify)
    (goto-char (point-min))
    (search-forward "https")
    (should (get-char-property (match-beginning 0) 'goto-address))
    (should (equal (get-char-property (match-beginning 0) 'browse-url-data)
                   "https://example.com/x"))))

(ert-deftest goto-addr-tests-mail-overlay ()
  (with-temp-buffer
    (insert "mail foo@example.org about it\n")
    (goto-address-fontify)
    (goto-char (point-min))
    (search-forward "foo")
    (should (get-char-property (match-beginning 0) 'goto-address))
    ;; Addresses are matched bare; the emitted link must be a URI.
    (should (equal (get-char-property (match-beginning 0) 'browse-url-data)
                   "mailto:foo@example.org"))))

(ert-deftest goto-addr-tests-prog-mode-match-data ()
  "Overlay properties survive match-data clobbering by `syntax-ppss'.
In `goto-address-prog-mode', fontification consults `syntax-ppss'
between matching an address and decorating it; a mode's
`syntax-propertize-function' may run its own searches then."
  (with-temp-buffer
    (emacs-lisp-mode)
    (setq-local syntax-propertize-function
                (lambda (_start _end)
                  (string-match "clobber" "clobber")))
    (insert ";; see https://example.com/prog here\n"
            "(ignore)\n")
    (let ((goto-address-prog-mode t))
      (goto-address-fontify))
    (goto-char (point-min))
    (search-forward "https")
    (should (equal (get-char-property (match-beginning 0) 'browse-url-data)
                   "https://example.com/prog"))))

(provide 'goto-addr-tests)
;;; goto-addr-tests.el ends here
