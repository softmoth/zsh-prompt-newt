Newt ZSH Theme
==============

>   “She turned me into a newt!”  
>   “A newt?”  
>   “… I got better.”  

![Newt Theme Demo][demo]

[demo]: https://gist.githubusercontent.com/softmoth/2910577d28970c80b58f8b55c34d58c1/raw/newt-demo.png

Styles
------

Newt comes with these pre-defined styles:
*default, denver, forest, meadow, mono*.

Use a style with `prompt newt meadow`.

Create a `bespoke` style with `prompt newt blue white magenta`, giving
a list of colors. Each color can be

- `''`, meaning the terminal's default background / foreground, or
- *black, red, yellow, green, blue, magenta, cyan, white*, or
- a color number supported by your terminal, or
- a truecolor specification as described in **Truecolor support** below.

![Newt Theme Preview][preview]

[preview]: https://gist.githubusercontent.com/softmoth/2910577d28970c80b58f8b55c34d58c1/raw/newt-preview.png

These styles are simply shorthand for the `zstyle` configuration, as
described in **Styling** below. So the style can be used to get most
things as you like, and then individual elements can be refined further.

Colors indexes are

1.  Primary background
2.  Primary foreground
3.  Secondary background
4.  Secondary foreground
5.  Alert background
6.  Alert foreground
7.  Red
8.  Green
9.  Yellow
10. Blue
11. Magenta
12. Cyan
13. Black
14. White

Since the *forest* style specifies 4 colors, the following will
change the Alert (colors 5 & 6) to pale yellow on a hot pink
background:

    prompt newt forest 161 227

Styling
-------

Segments can be configured with the context
`:prompt-theme:newt:STYLE:SEGMENT:STATE`. *Style* can be
anything you like, and you can call `prompt newt STYLE` to
use a particular style. If just `prompt newt` is run, the
style is `default`. *Segment* is the name of the segment, e.g.,
`vcs` or `dir`. *State* is segment-specific, and is `default`
for most segments most of the time.

Run `prompt_newt_defaults` to show the built-in settings.
Your custom overrides can be shown with `zstyle -L ':prompt-theme:newt:*'`.
To remove an override, run
`zstyle -d ':prompt-theme:newt:*:the:pattern' [style]`.

### Examples

    zstyle ':prompt-theme:newt:*:vcs:*'          bg blue
    zstyle ':prompt-theme:newt:*:vcs:*'          fg yellow
    zstyle ':prompt-theme:newt:*:vcs:clobbered'  bg yellow
    zstyle ':prompt-theme:newt:*:vcs:clobbered'  fg red
    # Revert the first two changes
    zstyle -d ':prompt-theme:newt:*:vcs:*'

    zstyle ':prompt-theme:newt:forest:dir:*'     bg green
    zstyle ':prompt-theme:newt:forest:dir:*'     fg blue

    # Only use the left prompt
    zstyle ':prompt-theme:newt:*' left time context status jobs vcs dir
    zstyle ':prompt-theme:newt:*' right none

Segments
--------

The segments used for left and right prompts can be set with:

    zstyle ':prompt-theme:newt:*' left time context dir
    zstyle ':prompt-theme:newt:*' right vi_mode status exec_time jobs vcs

This change requires the prompt to be set up again. Run `prompt newt`
for the change to take effect.

### Execution time

The `exec_time` segment states are `long` and `default`.

The threshold from `default` to `long` can be set with
`zstyle ':prompt-theme:newt:*:exec_time' threshold 30`.
The default is 5 seconds. It can be fractional, for example `0.75`.

The precision can be set with
`zstyle ':prompt-theme:newt:*:exec_time' precision 3`.
The default is 1 if the execution time is below 10 seconds,
and 0 otherwise.

By default, the `long` state shows times in a human-friendly format
like `間1h22m33s`. The `default` state is empty (so times below the
threshold are not shown). The format can be set with:

    # %s: seconds
    zstyle ':prompt-theme:newt:*:exec_time' long    '🕑%s'
    # %t: human-friendly
    zstyle ':prompt-theme:newt:*:exec_time' default '🕑%t'

### Exit status

The `status` segment states are `ok`, `error` and `suspended`. By default
only `error` status is shown. To always show a status, set:

    zstyle ':prompt-theme:newt:*:status' ok        $'\u2713' # ✓
    zstyle ':prompt-theme:newt:*:status' suspended $'\u25c6' # ◆

### Prompt time (dev)

The `prompt_time` segment displays how long it takes for the prompt
itself to be drawn. This segment is off by default. The precision can be
set with `zstyle ':prompt-theme:newt:*:prompt_time' precision 3`.

### Version control

The `vcs` segment states are `clobbered`, `root`, `action`, `dirty`
and `default`. Most of the display is controlled by `VCS_Info`:

    # See zshcontrib(1) for more options related to version control
    zstyle ':vcs_info:*' enable git cvs svn bzr hg
    zstyle -L ':vcs_info:*'

### Vi mode

The `vi_mode` segment has settings to configure the colors and
text of the mode indicator. The recognized states are `viins`,
`vicmd`, `replace`, `isearch`, `visual` and `vline`. For example,
the `vicmd` mode can be styled with:

    zstyle ':prompt-theme:newt:*:vi_mode' vicmd NORMAL
    zstyle ':prompt-theme:newt:*:vi_mode:vicmd' bg 202
    zstyle ':prompt-theme:newt:*:vi_mode:vicmd' fg 235

NOTE: Only `viins` and `vicmd` states are available by default.
The others require the [zsh-vim-mode][] plugin.

[zsh-vim-mode]: https://github.com/softmoth/zsh-vim-mode

Truecolor support
-----------------

If your terminal [supports Truecolor escape sequences][truecolor],
then you can use them anywhere a color can be specified. That is,
either in a `zstyle` to set a color, or directly in a `%K{...}` or
`%F{...}` escape in the prompt text. The color must be given as
`rrr;ggg;bbb`. For example:

    zstyle ':vcs_info:*' stagedstr '%F{250;128;114}+'
    zstyle ':prompt-theme:newt:*:vi_mode:search' bg '199;21;133'

[truecolor]: https://gist.github.com/XVilka/8346728

Miscellaneous settings
----------------------

    # Remove spacing around segments
    zstyle ':prompt-theme:newt:*' compact true

    # Tell newt what colors the terminal uses; background is used to
    # draw the arrow head of the segment separator when the default
    # background (bg '') is used. Also used for the default theme.
    zstyle ':prompt-theme' terminal-background 236
    zstyle ':prompt-theme' terminal-foreground 254

    # Keep only the latest the right-side prompt
    setopt TRANSIENT_RPROMPT
