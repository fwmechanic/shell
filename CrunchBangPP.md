Notes of a new CBPP (CrunchBang++) user (version 13)

Setup see %~dp0/CrunchBangPP-setup.md

https://www.crunchbangplusplus.org/
https://github.com/CBPP/cbpp
https://www.reddit.com/r/crunchbangplusplus/
https://distrowatch.com/table.php?distribution=cbpp

Global Key assignments  NB: "super" = Windows key (or "search" key on Chromebook)

Shortcut keys (listed as such on desktop bg)

   alt+f2   alt menu (seems to list every binary in PATH? at bottom of screen)
   alt+f3   alt menu (seems to list every binary in PATH? at bottom of screen)

   super+space   Main Menu (also by right clocking desktop)
   super+tab     Client Menu (menu list of all open windows)

   super+h       task manager (terminal running htop)
   super+f       file manager (Thunar)

   super+e       editor (GUI, Geany 2.0)
   super+m       media player (VLC)
   super+v       volume control
   super+w       web browser (Firefox)
   super+t       terminal

   super+l       lock screen
   super+x       logout

   PrtSc         print screen

Discovered

   alt+l    "Terminator Layout Launcher"

CrunchBang++ is built around the **Openbox** window manager, so **global** (desktop-wide) hotkeys are typically defined in Openbox's config. ([itch.io][1])

Global (Openbox) keybindings  $HOME/.config/openbox/rc.xml
                              $HOME/.config/openbox/menu.xml

## 1) Global (Openbox) keybindings  $HOME/.config/openbox/rc.xml

**Primary file (per-user):** `~/.config/openbox/rc.xml`
Keybinds live specifically inside the `<keyboard>` section. ([openbox.org][2])

**System default (if you don't have a per-user copy):** `/etc/xdg/openbox/rc.xml` (often copied into `~/.config/openbox/rc.xml` when you start customizing). ([openbox.org][2])

After editing, reload Openbox so changes take effect:

```bash
openbox --reconfigure
```

([openbox.org][3])

## 2) Your specific example: `Alt+L` -> "Terminator Layout Launcher"

That shortcut is **not** a CrunchBang++/Openbox hotkey. It's a **Terminator-internal** default shortcut: **Alt+L opens the Layout Launcher**. ([terminator-gtk3.readthedocs.io][4])

You can change it either:

* **GUI:** Terminator -> right-click -> *Preferences* -> *Keybindings* (find "layout launcher") ([Ask Ubuntu][5])
* **Config file:** `~/.config/terminator/config` (contains a `[keybindings]` section). ([SysTutorials][6])

## 3) Quick way to locate "who owns" a hotkey

If you want to hunt bindings fast:

```bash
# Openbox global hotkeys
grep -R --line-number '<keybind ' ~/.config/openbox

# Terminator keybindings
grep -R --line-number 'layout_launcher\|keybindings' ~/.config/terminator/config
```

If you tell me whether the hotkey works **on the desktop with no app focused** (global) or **only inside a specific app window** (app-level), I can point you to the exact config file category immediately.

[1]: https://computermouth.itch.io/crunchbangplusplus?utm_source=chatgpt.com "CrunchBangPlusPlus by computermouth"
[2]: https://openbox.org/help/Bindings "Help:Bindings - Openbox"
[3]: https://openbox.org/help/Upgrading_to_3.4?utm_source=chatgpt.com "Upgrading to 3.4 - Openbox"
[4]: https://terminator-gtk3.readthedocs.io/en/latest/layouts.html "Layouts and the Layout Launcher -- Terminator 2.0 alpha documentation"
[5]: https://askubuntu.com/questions/1510624/how-can-i-remove-the-shortcut-alt-l-in-terminator "neovim - How can I remove the shortcut 'Alt + L' in terminator - Ask Ubuntu"
[6]: https://www.systutorials.com/docs/linux/man/5-terminator_config/?utm_source=chatgpt.com "terminator_config: the config file for Terminator terminal emulator ..."

`Alt+L` -> "Terminator Layout Launcher" **is not a CBPP/Openbox "global hotkey."** It's an **in-application Terminator shortcut**.

What's happening is:

* **Terminator** (the terminal emulator CBPP ships/configures as default) has its own keybinding map.
* **Alt+L** is one of Terminator's built-in keybindings for the **Layout Launcher**.
* So it only fires when **a Terminator window has keyboard focus** (i.e., you're "in" Terminator). It is not an Openbox-level binding that works everywhere.

How to verify quickly:

1. Click your desktop/background (focus *not* on Terminator) and press **Alt+L**

* If nothing happens: that's consistent with an app-level binding.

2. Focus a Terminator window and press **Alt+L**

* If the Layout Launcher appears: that's Terminator's internal binding.

Where to change it:

* **GUI:** Terminator -> Preferences -> Keybindings -> "layout launcher"
* **File:** `~/.config/terminator/config` under a `[keybindings]` section.

If you want, name 2-3 other hotkeys you've found (and whether they work outside any app), and I'll tell you which subsystem likely owns each: Openbox (`rc.xml`), tint2, sxhkd, or an app's own config.


Main Menu
