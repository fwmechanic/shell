# My "git for Windows" and Linux Bash (and Perl) scripts

## What

* These scripts are expected to run on both Linux and "git for Windows" (hereinafter: "git bash") bash shell.
* Bash version 4+ is assumed.
* The worktree for this repo is expected to be added to PATH.

## Dependencies on non-default externalcmds

Dependencies on non-default externalcmds are to be avoided.

Git bash tends to offer a severely restricted default externalcmd environment compared to Linux bash, but
git bash (and any Linux environment) includes Perl (and `curl`, GNU `grep`, `sed`, `cut` ...) so most beyond-bash custom text processing is done using `perl` one-liners if `grep` is insufficient.

## Notes

* Prefer `curl` over `wget`.
* Perl scripts (i.e. shebang == `#!/usr/bin/perl -w`) ARE ALLOWED herein.
* `jq`, `rg` (ripgrep), `xml[starlet]`, `[html]tidy` are among the few worthy non-default externalcmds which these scripts are allowed to use.
* Availability of non-default externalcmds shall be verified before use with `command -v externalcmd || die` or similar.

[Markdown ref](https://markdown-guide.readthedocs.io/en/latest/basics.html#lists-simple)
