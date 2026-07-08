;;; term-tests.el --- tests for term.c functions -*- lexical-binding: t -*-

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

(require 'ert)
(require 'ert-x)

(defun term-tests--osc8-termscript (enable value)
  "Return the termscript of a child \"emacs -nw\" displaying VALUE.
The child shows a buffer with a span whose `browse-url-data'
property is the string VALUE; ENABLE non-nil sets the
`tty-hyperlinks' terminal parameter first.  Skip the running test
if the child cannot be run at all."
  (when (memq system-type '(windows-nt ms-dos))
    (ert-skip "Needs a pty"))
  (let ((emacs (expand-file-name invocation-name invocation-directory)))
    (unless (file-executable-p emacs)
      (ert-skip "Cannot find the running Emacs executable"))
    (ert-with-temp-file script :suffix ".termscript"
      (let* ((process-connection-type t) ; the child must get a pty
             (process-environment (cons "TERM=xterm" process-environment))
             (proc
              (start-process
               "tty-hyperlink" nil emacs "-nw" "-Q" "--eval"
               (format
                "%S"
                `(progn
                   ,@(if enable
                         '((set-terminal-parameter nil 'tty-hyperlinks t)))
                   (open-termscript ,script)
                   (switch-to-buffer "*tty-href*")
                   (insert (propertize "LINK" 'browse-url-data ,value))
                   (redisplay t)
                   (kill-emacs 0))))))
        (unwind-protect
            (progn
              (with-timeout (10)
                (while (process-live-p proc)
                  (accept-process-output proc 0.1)))
              ;; A child that cannot bring up a tty frame (say, no
              ;; terminfo entry for TERM) is an environment problem,
              ;; not a term.c regression.
              (unless (and (eq (process-status proc) 'exit)
                           (eql (process-exit-status proc) 0))
                (ert-skip "Child \"emacs -nw\" did not run"))
              (with-temp-buffer
                (insert-file-contents-literally script)
                (buffer-string)))
          (when (process-live-p proc)
            (delete-process proc)))))))

(defun term-tests--count-matches (regexp string)
  (let ((count 0) (start 0))
    (while (string-match regexp string start)
      (setq count (1+ count) start (match-end 0)))
    count))

(ert-deftest term-tests-tty-hyperlink-emitted ()
  "`browse-url-data' spans are bracketed in OSC 8 sequences on a tty."
  (should (string-match-p
           "\e]8;id=[0-9]+;https://example\\.com/x\e\\\\"
           (term-tests--osc8-termscript t "https://example.com/x"))))

(ert-deftest term-tests-tty-hyperlink-disabled ()
  "No OSC 8 output without the `tty-hyperlinks' terminal parameter."
  (should-not (string-match-p
               "\e]8;"
               (term-tests--osc8-termscript nil "https://example.com/x"))))

(ert-deftest term-tests-tty-hyperlink-non-uri ()
  "Values not shaped like a URI produce no OSC 8 output.
`browse-url-data' values are not formally typed, so anything
without an RFC 3986 scheme prefix must never reach escape output."
  (should-not (string-match-p
               "\e]8;"
               (term-tests--osc8-termscript t "not a url"))))

(ert-deftest term-tests-tty-hyperlink-escape-injection ()
  "Control bytes in a URI cannot inject escape sequences.
An embedded ESC (here starting an OSC 0 title sequence) and BEL
(the OSC terminator) must reach the terminal only percent-encoded,
leaving the OSC 8 structure intact."
  (let ((output (term-tests--osc8-termscript
                 t "http://x\e]0;pwned\ay")))
    (should (string-match-p "\e]8;id=[0-9]+;http://x%1B]0;pwned%07y\e\\\\"
                            output))
    ;; The injected title sequence must not appear un-encoded.
    (should-not (string-match-p "\e]0;" output))
    ;; Every emitted hyperlink is opened and closed in pairs.
    (should (> (term-tests--count-matches "\e]8;id=" output) 0))
    (should (= (term-tests--count-matches "\e]8;id=" output)
               (term-tests--count-matches "\e]8;;\e\\\\" output)))))

(ert-deftest term-tests-tty-hyperlink-bel-injection ()
  "A bare BEL in a URI is percent-encoded, not emitted."
  (let ((output (term-tests--osc8-termscript t "http://x\a;y")))
    (should (string-match-p "\e]8;id=[0-9]+;http://x%07;y\e\\\\" output))
    (should-not (string-match-p "\a" output))))

(ert-deftest term-tests-tty-hyperlink-any-scheme ()
  "Any RFC 3986 scheme is emitted; there is no scheme allowlist.
Emacs only emits the link; the terminal emulator applies its own
policy when the user activates it, so allowlisting here would break
legitimate exotic schemes for no security gain."
  (should (string-match-p
           "\e]8;id=[0-9]+;javascript:alert(1)\e\\\\"
           (term-tests--osc8-termscript t "javascript:alert(1)"))))

(provide 'term-tests)
;;; term-tests.el ends here
