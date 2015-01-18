;;; flycheck-java.el --- flycheck for Java -*- lexical-binding: t; -*-

;; Copyright (C) 2015 by Yuta Yamada

;; Author: Yuta Yamada <cokesboy"at"gmail.com>
;; URL: https://github.com/yuutayamada/
;; Version: 0.0.1
;; Package-Requires: ((package "version-number"))
;; Keywords: keyword

;;; License:
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;; Commentary:
;; Note this project is still work in progress.
;; Usage
;;  (add-to-list 'java-mode-hook '(lambda () (require 'flycheck-java))
;;; Code:

(require 'flycheck)

(defvar flycheck-java-info nil)
(defvar flycheck-java-default-android-sdk-version)

(flycheck-define-checker java
  "Java syntax checker using javac."
  :command ("javac" "-Xlint" "-encoding" "utf-8"
            (eval (flycheck-java-compute-lint-options))
            (eval (flycheck-java-find "R.java"
                    (lambda (file) (not (string-match "/android/support/" file)))))
            (eval (cl-loop for file in (directory-files default-directory)
                           if (and (file-exists-p file)
                                   (string-match "\\.java$" file))
                           collect file))
            source)
  :error-patterns
  ((warning line-start (file-name) ":" line ": warning:"
            (message (one-or-more (not (any "^")))
                     (any "^"))
            line-end)
   (error line-start (file-name) ":" line ": error:"
          (message (one-or-more (not (any "^")))
                   (any "^"))
          line-end))
  :modes java-mode)

(defun flycheck-java-compute-lint-options ()
  "Get adequate lint options for Java."
  (let* ((android-dev-home
          (locate-dominating-file buffer-file-name "AndroidManifest.xml"))
         (dev-home
          (or android-dev-home
              (locate-dominating-file buffer-file-name "src"))))
    (delq nil (when (and dev-home (not (equal dev-home "~/")))
                (flycheck-java-get-lint-options)))))

(defun flycheck-java-get-info ()
  ""
  (cl-loop for (dir . info) in flycheck-java-info
           if (equal dir (flycheck-java-android-root))
           do (cl-return info)))

(defun flycheck-java-make-info ()
  ""
  (let* ((root (flycheck-java-android-root))
         (android-jars (append `(,(flycheck-java-get-android-jar-file-info))
                               (flycheck-java-find "*\\.jar")))
         (classpath (apply `(flycheck-java-formatter ,root ,@android-jars)))
         (sourcepath (flycheck-java-formatter
                      default-directory
                      (concat root "src")
                      ;; (concat root "gen")
                      )))
    (list (cons 'classpath classpath)
          (cons 'sourcepath sourcepath))))

(defun flycheck-java-android-root ()
  "Return directory of android development.

I'm pretty Java and android newbie...
Please please please! give me pull request!"
  (let ((root-dir
         (or
          ;; android studio
          (locate-dominating-file buffer-file-name "gradlew")
          ;; Mevan?
          ;;   TODO: ...Do something...
          ;; Eclipse?
          ;;   TODO: ...Do something...
          ;; Default(ant)
          (locate-dominating-file buffer-file-name "AndroidManifest.xml"))))
    (when (and (bound-and-true-p android-mode)
               (not (equal "~/" root-dir)))
      root-dir)))

(defun flycheck-java-get-lint-options ()
  ""
  (let* ((info (flycheck-java-get-info)))
    (unless info
      (setq info (flycheck-java-make-info))
      (push (cons (flycheck-java-android-root) info) flycheck-java-info))
    (delq nil
          (let-alist info
            (list "-cp" .classpath "-sourcepath" .sourcepath)))))

(defun flycheck-java-find (filename &optional predicate)
  ""
  (cl-loop with d = (locate-dominating-file default-directory "src")
           with files = (shell-command-to-string
                         (format "find %s -name \"%s\"" d filename))
           for file in (split-string files "\n")
           if (and (string< "" file)
                   (or (not predicate)
                       (apply `(,predicate ,file))))
           collect file))
(put 'flycheck-java-find 'lisp-indent-function 1)

(defun flycheck-java-get-android-jar-file-info ()
  ""
  (file-truename
   (format "%s/platforms/android-%s/android.jar"
           (getenv "ANDROID_SDK_HOME")
           (or (let ((files (flycheck-java-android-project-p)))
                 (flycheck-java-get-android-version-from
                  (caar files) (cdar files)))
               flycheck-java-default-android-sdk-version))))

(defun flycheck-java-android-project-p ()
  "Return version string if this function can find project directory."
  (cl-loop with src-dir = (locate-dominating-file default-directory "src")
           with gradle = (cons (format "%sbuild.gradle" src-dir)
                               "targetSdkVersion \\([0-9]*\\)")
           with pproperties = (cons (format "%sproject.properties" src-dir)
                                    "target=[^\n]*:\\([0-9]+\\)")
           for (f . p) in (list gradle pproperties)
           if (file-exists-p f)
           collect (cons f p)))

(defun flycheck-java-formatter (&rest files)
  ""
  (cl-loop for file in files
           if (file-exists-p file)
           collect file into result
           finally return (mapconcat 'identity result ":")))

(defun flycheck-java-get-android-version-from (file regex)
  "Get android SDK version as string from FILE by using REGEX."
  (let ((buffer (find-file-noselect file))
        (origin (current-buffer))
        (func `((lambda ()
                  (re-search-forward ,regex)
                  (match-string 1))))
        version)
    (with-temp-buffer
      (switch-to-buffer buffer)
      (goto-char (point-min))
      (setq version (apply func))
      (switch-to-buffer origin))
    version))

(add-to-list 'flycheck-checkers 'java)

(defun flycheck-java-print-options ()
  "Print lint options."
  (interactive)
  (print (flycheck-java-compute-lint-options)))

(provide 'flycheck-java)

;; Local Variables:
;; coding: utf-8
;; mode: emacs-lisp
;; End:

;;; flycheck-java.el ends here
