;;; counsel-itunes.el - Itunes interaction with `ivy'.
;;
;; Copyright (c) 2012-2017 Jacob Chaffin
;;
;; Author:  Jacob Chaffin <jchaffin@ucla.edu>
;; Keywords: itunes, macOS, counsel, ivy
;; Homepage: https://github.com/jchaffin/dotemacs
;; Package-Requires: ((emacs "25") (ivy "0.10.0"))
;;
;; This file is not part of GNU Emacs.
;;
;;; License: GPLv3

;;; Commentary:
;; An Emacs interface to Itunes, using ivy and counsel.
;; Based off of itunes.el
;; https://www.emacswiki.org/emacs/itunes.el
;;; End Commentary

;;; Code:

(require 'ivy)
(defvar counsel-itunes--text-item-delimiter ",,," )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Current Track Information

(defun counsel-itunes//current-track-info ()
  (do-applescript
   (concat
    "local trackInfo\n"
    "tell application \"iTunes\"\n"
    "  set trackInfo to get {name,artist,time,album} of current track\n"
    "end tell\n"
    "set text item delimiters to \"" counsel-itunes--text-item-delimiter "\"\n"
    "get trackInfo as text")))

(defun counsel-itunes//current-track-time ()
  (interactive)
  (destructuring-bind (timeLeft trackDuration)
      (split-string
       (do-applescript
        (concat
         "tell application \"iTunes\"\n"
         "  set timeLeft to player position\n"
         "  set totalDuration to time of current track\n"
         "end tell\n"
         "set text item delimiters to \"" counsel-itunes--text-item-delimiter "\"\n"
         "get {timeLeft,totalDuration} as text"))
       counsel-itunes--text-item-delimiter
       t)
    (if (interactive-p)
        (if (= (string-to-number timeLeft) 0.0)
            (message "%s" trackDuration)
          (message "%s of %s"
                   (format-seconds "%m:%.2s"
                                   (string-to-number timeLeft))
                   trackDuration))
      (list timeLeft trackDuration))))

;;;###autoload
(defun counsel-itunes-current-track ()
  "Reports the name, artists, time, and album (if available)
to the mini-buffer. "
  (interactive)
  (destructuring-bind (name artist time &optional album)
      (split-string
       (counsel-itunes//current-track-info)
       counsel-itunes--text-item-delimiter
       t)
    (if (interactive-p)
        (message "%s by %s -- %s %s" name artist (or album "")
                 (funcall-interactively 'counsel-itunes//current-track-time))
      (list name artist album time))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Playlists

(defun counsel-itunes//playlists-list ()
  ;; (interactive)
  (do-applescript
   (concat
    "local itunesPlaylists\n"
    "tell application \"iTunes\"\n"
    "  set itunesPlaylists to get name of playlists\n"
    "end tell\n"
    "set text item delimiters to \"" counsel-itunes--text-item-delimiter "\"\n"
    "get itunesPlaylists as text")) )

(defun counsel-itunes//select-playlist (playlist-name)
  ;;(interactive)
  (do-applescript
   (concat
    "tell application \"iTunes\"\n"
    "  play playlist \"" playlist-name "\"\n"
    "end tell")))


(defun counsel-itunes//playlist-menu (&optional display-track-menu)
  ;; (interactive)
  (ivy-read
   "iTunes Playlists: "
   (split-string
    (counsel-itunes//playlists-list)
    counsel-itunes--text-item-delimiter
    t)
   :action (lambda (playlist-name)
             (if display-track-menu
                 (counsel-itunes//tracklist-menu playlist-name)
               (counsel-itunes//select-playlist playlist-name))
             (funcall-interactively 'counsel-itunes-current-track))))

;;;###autoload
(defun counsel-itunes-playlist ()
  "Constructs an ivy selection menu consisting
 of iTunes playlists."
  (interactive)
  (counsel-itunes//playlist-menu nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tracklist

(defun counsel-itunes//get-tracklist (playlist-name)
  (do-applescript
   (concat
    "local trackList\n"
    "tell application \"iTunes\"\n"
    "  set trackList to get name of tracks in playlist \"" playlist-name "\"\n"
    "end tell\n"
    "set text item delimiters to \"" counsel-itunes--text-item-delimiter "\"\n"
    "get trackList as text")))

(defun counsel-itunes//tracklist-from-playlist (playlist-name track-name)
  (do-applescript
   (concat
    "tell application \"iTunes\"\n"
    "  play track \"" track-name "\" in playlist \"" playlist-name "\"\n"
    "end tell")))


(defun counsel-itunes//tracklist-menu (playlist-name)
    (interactive)
    (ivy-read
     (concat "Playlist '" playlist-name "' Tracklist: ")
     (split-string
      (counsel-itunes//get-tracklist playlist-name)
      counsel-itunes--text-item-delimiter
      t)
     :action (lambda (track-name)
               (counsel-itunes//tracklist-from-playlist playlist-name track-name))))

;;;###autoload
(defun counsel-itunes-tracklist ()
  "Constructs an ivy menu for interactively selecting
a track to play from a given playlist."
  (interactive)
  (counsel-itunes//playlist-menu t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;; Actions and State

;;;###autoload
(defun counsel-itunes-play-pause ()
  "Toggles the play/paused state of the current track in iTunes."
  (interactive)
  (do-applescript
   "tell application \"iTunes\" to playpause"))

;; Volume Adjustment
(defun counsel-itunes//adjust-volume-by (decinc n)
  (do-applescript
   (concat
    "tell application \"iTunes\"\n"
    "  set sound volume to sound volume" decinc " " (number-to-string n) "\n"
    "end tell")))

;;;###autoload
(defun counsel-itunes-volume-down (&optional n)
  "Decrement the iTunes.app volume by 10.
If the optional prefix argument N is specified, then
the volume will be decreased by that amount instead."
  (interactive "P")
  (if (number-or-marker-p n)
      (counsel-itunes//adjust-volume-by "-" n)
    (counsel-itunes//adjust-volume-by "-" 10)))

;;;###autoload
(defun counsel-itunes-volume-up (&optional n)
  "Increment the volume in Itunes.app by 10.
If the optional prefix argument N is specified, then
the volume will be increased by that amount instead."
  (interactive "P")
  (if (number-or-marker-p n)
      (counsel-itunes//adjust-volume-by "+" n)
    (counsel-itunes//adjust-volume-by "+" 10)))

;; Track Traversal

;;;###autoload
(defun counsel-itunes-next-track (&optional n)
  "Go to the next track in the current playlist.
If the optional prefix argument N is specified, then
go the Nth next."
  (interactive "P")
  (do-applescript
   (format
    (concat
     "tell application \"iTunes\"\n"
     "  repeat %d times\n"
     "    next track\n"
     "  end repeat\n"
     "end tell")
    (or n 1)))
  (funcall-interactively 'counsel-itunes-current-track))

;;;###autoload
(defun counsel-itunes-previous-track (&optional n)
  "Go to the previous track in the current playlist.
If the optional prefix argument N is specified, then
go to the Nth previous."
  (interactive "P")
  (do-applescript
   (format
    (concat
     "tell application \"iTunes\"\n"
     "  repeat %d times\n"
     "    back track\n"
     "  end repeat\n"
     "end tell")
    (or n 1)))
  (funcall-interactively 'counsel-itunes-current-track))

;;;###autoload
(defun counsel-itunes-shuffle ()
  "Toggle shuffle mode of the current playlist."
  (interactive)
  (let ((toggle (do-applescript
                 (concat
                  "local shuffleMode\n"
                  "tell application \"iTunes\"\n"
                  "  if shuffle enabled then\n"
                  "    set shuffle enabled to false\n"
                  "  else\n"
                  "    set shuffle enabled to true\n"
                  "  end if\n"
                  "set shuffleMode to shuffle enabled\n"
                  "end tell\n"
                  "get shuffleMode as text"))))
    (message "Shuffle mode %s."
             (if (string= toggle "true")
                 "enabled" "disabled"))))




(provide 'counsel-itunes)

;;; counsel-itunes.el ends here.
