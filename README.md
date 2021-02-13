# My "git for Windows" and Linux Bash (and Perl) scripts

## Why

Modern (4.x) Bash + common linux/unix'ish cmdline utilities [(GNU coreutils](https://en.wikipedia.org/wiki/List_of_GNU_Core_Utilities_commands), Perl 5) which are a default part of both Linux and "git for Windows" (hereinafter: "git bash") environments provide me with a time-proven least common denominator toolkit for getting things done **robustly with minimal lines of code.**

Compared to programming with separately provisioned source code libraries e.g. Python's `pip`, Perl's `mcpan`, node's `npm`, I find using these (mostly very mature) binary tools

* maintain backward compatability.
* are very reliable, having been continuously intensively used and actively maintained _for decades_.
* are (typically being binaries written in C) _performant_ and lightweight in resource consumption.
* have no or bare-minimum dependencies: binary presence implies full/normal capability.
* offer interfaces that are readily composable via bash scripting.
* naturally preserve state in (text) files, which can be operated on by all the other tools in the toolset, and viewed/edited/diff'd by humans as needed.
* invariably _already have_ any feature I seek, usually a mere option-addition away.
* bash cli can be used to provide any type of REPL I need.

I never would have predicted, but my primary development language at work is exactly this toolset (on Windows, no less!); it helps that the one absolute provisioning requirement for any host my code might run on (for reasons independent of my code) is that Git For Windows is already installed.  Some folks seem to think of bash scripting as indicative of dodgy practice by crazy people, but for my current needs, it is close to ideal; bad code can be written in any language, but today's bash supports creating good code.

## What

* These scripts are expected to run on both Linux and "git bash" bash shells.
* The worktree for this repo is expected to be added to PATH.
* Perl scripts (i.e. shebang == `#!/usr/bin/perl -w`) ARE ALLOWED herein.

## Essential Tools & Inspirational Reference Material

* [This answer](https://stackoverflow.com/a/45386798) to a SO question about "Bash utility script library" took my bash scripting "game" to a new level.  Use of lexical scope (in C, Perl, Lua, etc.) has always been a primary facilitator for me to write code that adheres to the rule that each program object (variable, function) should be minimally scoped.  The revelation that functions can be defined as intrinsically embodying subshells (by surrounding the function's definition with `()` rather than the typical `{}`), and those functions are "hermetically sealed" from the calling environment, as explained in this SO answer, allows me to write bash code in the same style as I've long written Lua code (including plentiful use of nested functions which resemble *closures*).
* *[Shellcheck](https://github.com/koalaman/shellcheck)*  ([releases](https://github.com/koalaman/shellcheck/releases/)) *an awesome bash code reviewer*, is probably **the most important tool listed herein.**  Don't program bash without it!
   * Shellcheck is available on Windows as well as the usual nix'ish platforms
     * NB: Windows Defender identified Shellcheck 0.7.1 as a virus and deleted it; this took at least a few weeks (months?) to be fixed: thanks for nothing, Microsoft!
   * `schk` script herein streamlines my use of Shellcheck.

Included in git bash:
   * `perl`: I've been programming Perl 5 since the mid 90's, and the language and its standard library are better than ever; I'm still learning new things that perl can do, especially one-liners.
   * `curl`: unlocks "the TCP/IP network" to bash programming.  I've standardized on curl (vs. `wget`) without regret.

## Essential Functions
I have only a few of these, and it so happens they're all short one-liners, but I use them often:
* `die [errmsg]`: display optional error message and `exit 1`.  Stolen from Perl, the idiom `command || die "$errmsg"` facilitates concise error-checking of any/every command without increasing the # of lines of code (which `if command; then echo "errmsg" ; exit 1 ; fi` typically does).  When `die` (or `exit`) is executed in a `( subshell )`, the subshell (not the whole script) is exited (w/exit status 1).  Contrast to `set -e` mode which silently terminates subshell/script execution w/no indication of the causing command; I used to use `set -e`, but have stopped that practice in lieu of pervasive use of `die`.  It's more labor intensive, but handling all errors explicitly is the hallmark of good software, which can be written in bash just as well as in any other language.
   * `die() { printf %s "${@+$@$'\n'}" 1>&2 ; exit 1 ; }`
   * Parameter expansion mechanism to check for e.g. missing arguments: `: "${1:?missing filename param}"`.  Note this prints the source file and line # as well as the coded message to stderr, which may not be desirable.
* `see command`: `see` prefixing a `command` runs `command` in a noiseless `set -x` environment which displays the (fully expanded) `command` to stdout (prefixed with `+ `) just before executing it.  `see` is most useful for pinpoint debugging or displaying consequential or time-consuming commands, removing all ambiguity regarding what command is actually running while a script's forward progress _appears_ stalled.  Use of `see` avoids the frustrating practice of writing `echo "command X" ; command X` where the echo parameter and the executed `command X` are (supposed to be) tracking copies of one another (but because they're _copies_, are prone to divergence during the script's lifetime); recoded as `see command X`, no divergence is possible.
   * `see() ( { set -x; } 2>/dev/null ; "$@" ) ;`

## [Shell Expansions](https://www.gnu.org/software/bash/manual/html_node/Shell-Expansions.html)
I usually forget the proper names for these magical expressions...
* [Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html):
   * There are a large number of parameter expansions to do most of the operations you might need.
   * EX: default variable value `${var:-dflt}`, assignment `${var:=dflt}`, expand to word iff var is non-null `${var:+word}`
      * the "right-hand side" values (`dflt`, `word`) can be arbitrary/nested expressions/expansions.
* [Process Substitution](https://www.gnu.org/software/bash/manual/html_node/Process-Substitution.html): `<(list)` and `>(list)`
* [Arithmetic Expansion](https://www.gnu.org/software/bash/manual/html_node/Arithmetic-Expansion.html): `$(( expression ))`; closely related to [Shell Arithmetic](https://www.gnu.org/software/bash/manual/html_node/Shell-Arithmetic.html).


## non-Git-for-Windows Essential Tools
* [`ffmpeg`](https://ffmpeg.org/ffmpeg.html) the audio-/video-file "swiss army knife" [Windows builds](https://ffmpeg.org/download.html#build-windows)
* [`jq` (jsonquery?)](https://stedolan.github.io/jq/download/): combine with `curl` to enable bidirectional http JSON API scripting.  I've barely scratched the surface of this tool and its DSL.
* [`xml` (xmlstarlet)](https://en.wikipedia.org/wiki/XMLStarlet): seems to be "jq for XML" (although xmlstarlet is the far older tool).
* [`tidy` (htmltidy)](https://en.wikipedia.org/wiki/HTML_Tidy): [binary releases](http://binaries.html-tidy.org/) a longstanding tool that I use to clean HTML input for processing by xmlstarlet.
* [`rg` (ripgrep)](https://github.com/BurntSushi/ripgrep/releases): a more featureful, modern implementation of `grep` which is handy for certain purposes (I certainly also use `grep` extensively).

* Availability of non-default externalcmds shall be verified before use with `command -v externalcmd || die` or similar.

## Note: using bash on hybrid Linux/Windows Jenkins cluster

Goal

* on Jenkins agents running on Linux hosts, and
* on Jenkins agents running on Windows hosts
* be able to run bash scripts stored in Jenkins Freestyle Job **Execute Shell** code blocks

How

* **caveat**: Freestyle Jobs following this note can run on _either_ Linux or Windows Jenkins hosts, _but not both_.
* on Jenkins Master, under **Manage Jenkins** / **Configure System** set **Shell Executable** to `c:\Program Files\Git\bin\bash.exe`
* in Jenkins Freestyle Job **Execute Shell** code blocks...
   * intended to run on Windows hosts, **provide NO shebang line**.
   * intended to run on Linux hosts, **provide shebang line `#!/usr/bin/bash`**.
      * Note: similarly, with Jenkins Master configured as above, Jenkins Groovy Pipeline `sh` function `script` parameter (containing shell script text) should (to execute on Linux) be given an initial line containing `#!/usr/bin/bash` or `#!/usr/bin/env bash`

[Markdown ref](https://markdown-guide.readthedocs.io/en/latest/basics.html#lists-simple)
