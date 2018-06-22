Newt ZSH Theme
==============

>   “She turned me into a newt!”

>   “A newt?”

>   “… I got better.”

Segments
--------

The segments used for left and right prompts can be set with:

    zstyle ":prompt-theme:newt:*" left time context dir
    zstyle ":prompt-theme:newt:*" right vi_mode status jobs vcs

Segments can be configured with the context
`:prompt-theme:newt:STYLE:SEGMENT:STATE`. *Style* can be
anything you like, and you can call `prompt newt STYLE` to
use a particular style. If just `prompt newt` is run, the
style is `default`. *Segment* is the name of the segment, e.g.,
`vcs` or `dir`. *State* is segment-specific, and is `default`
for most segments most of the time.

The settings in use can be shown with `zstyle -L | grep newt`.

Example
-------

    zstyle ":prompt-theme:newt:*:vcs:*"          bg blue
    zstyle ":prompt-theme:newt:*:vcs:*"          fg yellow
    zstyle ":prompt-theme:newt:*:vcs:clobbered"  bg yellow
    zstyle ":prompt-theme:newt:*:vcs:clobbered"  fg red

    zstyle ":prompt-theme:newt:forest:dir:*"     bg green
    zstyle ":prompt-theme:newt:forest:dir:*"     fg blue

    # Only use the left prompt
    zstyle ':prompt-theme:newt:*' left time context status jobs vcs dir
    zstyle ":prompt-theme:newt:*" right none

Vi-mode settings
----------------

The `vi_mode` segment has settings to configure the colors and
text of the mode indicator. The recognized states are `viins`,
`vicmd`, `replace`, `isearch`, `visual` and `vline`. For example,
the `vicmd` mode can be styled with:

    zstyle ':prompt-theme:newt:*:vi_mode' vicmd NORMAL
    zstyle ':prompt-theme:newt:*:vi_mode:vicmd' bg 202
    zstyle ':prompt-theme:newt:*:vi_mode:vicmd' fg 235

Truecolor support
-----------------

If your terminal [supports Truecolor escape sequences][truecolor],
then you can use them anywhere a color can be specified. That is,
either in a `zstyle` to set a color, or directly in a `%K{...}` or
`%F{...}` escape in the prompt text. The color must be given as
`rrr;ggg;bbb`. For example:

    zstyle ':vcs_info:*' stagedstr '%F{250;128;114}+'
    zstyle ':prompt-theme:nwet:*:vi_mode:search' bg '199;21;133'

[truecolor]: https://gist.github.com/XVilka/8346728

Miscellaneous settings
----------------------

    # Remove spacing around segments
    zstyle ":prompt-theme:newt:*" compact true

    # Tell newt what color the terminal background is; this is only
    # used to draw the arrow head of the segment separator when the
    # default background (`bg ''`) is used.
    zstyle ":prompt-theme" terminal-background 236

Other settings
--------------

    # See zshcontrib(1) for more options related to version control
    zstyle ':vcs_info:*' enable git cvs svn bzr hg
    zstyle -L ':vcs_info:*'

    # You may want to keep only the latest the right-side prompt
    setopt TRANSIENT_RPROMPT
