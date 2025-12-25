(see also %~dp0/CrunchBangPP-setup.md)

# running a laptop (1080p) with HDMI-display (4K TV) as primary

Two problems need to be solved:

## prevent laptop from shutting down (suspending/hibernating) when its lid is closed

I poked around in CBPP and discovered a "main menu" which let to "Power Management" which opened a small dialog-looking app entitled "Power Management Preferences".

(Typical processes: `xfce4-power-manager`, `mate-power-manager`, `powerdevil`, etc., the CBPP one seems to be `mate-power-manager`)

Minimal approach: Configure lid close action = "Nothing / Do nothing" in that power manager.

## as soon as possible, switch display operation to mirror laptop screen to 4K TV (with 4K resolution)

tl;dr: run `sudo /home/kg/my/repos/shell/mirror4k-install-systemd` once to install %~dp0/mirror4k

Why:

  1. Running a (big) 4K TV in 1080p mode is unacceptable/ridiculous.
  2. Running 2 displays as independent, with the "primary" (laptop) display
     being (almost) always hidden, dooms you to frustration: CBPP 13 and
     Lubuntu 24.04 display management SW will default to showing the primary
     DM UI stuff on the "primary" (laptop) display (making it invisible,
     which makes the DM/GUI environment practically unusable) AND dynamically
     switching the primary-display role to the HDMI display will run afoul of
     handlers for display-off events, both those of the laptop screen (when
     it is closed/opened) AND those of the HDMI TV (when it is powered
     off/on).  The only sane solution is to *mirror* the displays, and do so
     in 4K resolution, which is what %~dp0/mirror4k does.

The intended configuration: a 4K framebuffer on HDMI with the laptop panel mirroring via scaling:

   * eDP connected 3840x2160+0+0 ... but with 1920x1080 ... *current +preferred and a Transform of 2.000000 on X and Y, indicating the internal panel is being driven at 1920x1080 and scaled to match the framebuffer.
   * HDMI-A-0 connected primary 3840x2160+0+0 ... shows the TV is the primary output at 3840x2160.

### "as soon as possible"

%~dp0/mirror4k *can* be run from the laptop post-CBPP-GUI-login, but that's
unpleasant (you have to open the laptop to use its screen, mouse and
keyboard, then close it).

The ideal would be to run %~dp0/mirror4k "as soon as possible" in the boot
sequence, however since %~dp0/mirror4k accomplishes its task using the
`xrandr` program (which operates in the X.org realm only), the best we can
hope for is to run it *just before* the CBPP (etc.) GUI login screen is
displayed.  This is what %~dp0/mirror4k-install-systemd accomplishes.
If "installed" that way, the mirror4k logfile will be /var/log/mirror4k.log
