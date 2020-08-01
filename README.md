# My "git for Windows" and Linux Bash (and Perl) scripts

## Why

Modern (4.x) Bash + common linux/unix'ish cmdline utilities [(GNU coreutils](https://en.wikipedia.org/wiki/List_of_GNU_Core_Utilities_commands), Perl 5) which are a default part of both Linux and "git for Windows" (hereinafter: "git bash") bash environments provide me with a time-proven least common denominator toolkit for getting things done robustly with minimal lines of code.

## What

* These scripts are expected to run on both Linux and "git bash" bash shells.
* The worktree for this repo is expected to be added to PATH.
* Perl scripts (i.e. shebang == `#!/usr/bin/perl -w`) ARE ALLOWED herein.

## Essential Tools & Inspirational Reference Material

* [This answer](https://stackoverflow.com/a/45386798) to a SO question about "Bash utility script library" took my bash scripting "game" to a new level.  Use of lexical scope (in C, Perl, Lua, etc.) has always been a primary facilitator for me to write code that adheres to the rule that each program object (variable, function) should be minimally visible WRT overall program.  The revelation that functions can be defined as intrinsically embodying subshells (by surrounding the function's definition with `()` rather than the typical `{}`), and those functions are "hermetically sealed" from the calling environment, as explained in this SO answer, allows me to write bash code in the same style as I've long written Lua code (including plentiful use of nested function which that resemble *closures*).
* [Shellcheck](https://github.com/koalaman/shellcheck)  ([releases](https://github.com/koalaman/shellcheck/releases/)) is an essential tool for linting your bash scripts.
   * Shellcheck is available on Windows as well as the usual nix'ish platforms
     * NB: Windows Defender identified Shellcheck 0.7.1 as a virus and deleted it; this took at least a few weeks (months?) to be fixed: thanks for nothing, Microsoft!).
   * `schk` script herein eases use of Shellcheck.
* `perl`: I've been programming Perl 5 since the mid 90's, and it's as good as ever; I'm still learning new things that it can do, especially one-liners.
* `curl`: unlocks "the TCP/IP network" to bash programming.  I've standardized on curl (vs. `wget`).

## non-Git-for-Windows Essential Tools
* [`ffmpeg`](https://ffmpeg.org/ffmpeg.html) the audio-/video-file "swiss army knife" [Windows builds by Zeranoe](https://ffmpeg.zeranoe.com/builds/)
* [`jq` (jsonquery?)](https://stedolan.github.io/jq/download/): combine with `curl` to enable bidirectional http JSON API scripting.  I've barely scratched the surface of this tool and its DSL.
* [`xml` (xmlstarlet)](https://en.wikipedia.org/wiki/XMLStarlet): seems to be "jq for XML" (although xmlstarlet is the far older tool).
* [`tidy` (htmltidy)](https://en.wikipedia.org/wiki/HTML_Tidy): [binary releases](http://binaries.html-tidy.org/) an longstanding tool that I use to clean HTML input for processing by xmlstarlet.
* [`rg` (ripgrep)](https://github.com/BurntSushi/ripgrep/releases): a more featureful modern implementation of `grep` which is handy for certain purposes (I certainly also use `grep` extensively).

* Availability of non-default externalcmds shall be verified before use with `command -v externalcmd || die` or similar.

[Markdown ref](https://markdown-guide.readthedocs.io/en/latest/basics.html#lists-simple)

## Notes
* using `set -x` as the next-to-last-command of a subshell allows one the display the exact command line executed to accomplish a critical operation, without needing to code any extra (or duplicate) lines of code for logging such info.
