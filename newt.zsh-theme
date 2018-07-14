zmodload zsh/datetime
zmodload zsh/parameter
zmodload zsh/mathfunc

# Prompt Segments {{{1

# + context: user@host {{{1
__newt+context+precmd () {
    local u=;
    local h="${(%):-%m}"

    # Only show user if it's other than DEFAULT_USER. Treat root as
    # another default user, since prompt color shows we're privileged.
    [[ $+DEFAULT_USER -eq 1 && $USER != $DEFAULT_USER && $USER != root ]] \
      && u=$USER

    # Hide hostname if on local host (not SSH) or inside tmux (let TMUX
    # status show host info)
    [[ -z $SSH_CLIENT || -n $TMUX ]] && h=
    if [[ -n $h ]]; then
      [[ -n $u ]] && u=${u}@
      u=${u}${h}
    fi

    __newt[+context+]=$u
}

# + dir: Current directory {{{1
__newt+dir+precmd () {
    __newt[+dir+]=$(__newt_zstyle -d '%4~' dir default)

    [[ $EUID = 0 ]] \
        && __newt[+dir+state]=root \
        || __newt[+dir+state]=
}

# + exec_time: Execution time of last command {{{1
__newt+exec_time+setup () {
    __newt_default exec_time long $'\u9593%t'  # 間
    __newt_default exec_time threshold 5
}

__newt+exec_time+preexec () {
    __newt[+exec_time+start]=$EPOCHREALTIME
}

__newt+exec_time+precmd () {
    local state

    local stop=$EPOCHREALTIME
    local start=${__newt[+exec_time+start]:-$stop}

    local threshold="$(__newt_zstyle exec_time threshold)"
    local -F elapsed=$((stop - start))
    if (( $elapsed >= $threshold )); then
        state=long
    else
        state=default
    fi

    local precision="$(__newt_zstyle exec_time precision)"
    if [[ -z $precision ]]; then
        (( elapsed < 10 )) && precision=1 || precision=0
    fi

    __newt[+exec_time+state]=$state
    zformat -f '__newt[+exec_time+]' \
        "$(__newt_zstyle exec_time $state)" \
        t:"$(__newt_human_time $elapsed $precision)" \
        s:"$(printf '%.*f' $precision $elapsed)"

    __newt[+exec_time+start]=
}

__newt_human_time () {
    local s t=$1
    local -i m h d precision=${2:-3}
    ((
        s = t % 60, t = floor(t) / 60,
        m = t % 60, t = t / 60,
        h = t % 24, t = t / 24,
        d = t
    ))

    t=
    ((d)) && t+=${d}d
    ((h)) && t+=${h}h
    ((m)) && t+=${m}m

    printf -v s '%.*fs' $precision $s
    t+=$s

    print -rn $t
}

# + history: Current history {{{1
__newt+history+precmd () {
    __newt[+history+]=$(__newt_zstyle -d '%!' history default)
}

# + jobs: Background jobs {{{1
__newt+jobs+setup () {
    __newt_default jobs default $'\u2699'' %1(j:%2(j,%j,):-)'
}

__newt+jobs+precmd () {
    # \u2699 is ⚙
    (( ${(%):-%j} )) \
        && __newt[+jobs+]=$(__newt_zstyle jobs default) \
        || __newt[+jobs+]=$(__newt_zstyle jobs zero)
}

# + none: Placeholder to do nothing {{{1
__newt+none+setup () {
}

# + notice: Generic info display {{{1
__newt+notice+add-note () {
    __newt[+notice+notes]+=" $*"
}

__newt+notice+precmd () {
    __newt[+notice+]=$__newt[+notice+notes]
    unset '__newt[+notice+notes]'
}

# + prompt_time: How long the prompt takes to draw {{{1

# Install this precmd function specially so it gets called first
__newt_prompt_time_precmd () {
    __newt[+prompt_time+start]=$EPOCHREALTIME
}

__newt+prompt_time+setup () {
    precmd_functions[1,0]=(__newt_prompt_time_precmd)
    local i=2
    while (( i <= $#precmd_functions )); do
        if [[ $precmd_functions[$i] = __newt_prompt_time_precmd ]]; then
            # Remove it
            precmd_functions[$i]=()
        else
            i=$((i+1))
        fi
    done
}

__newt+prompt_time+zle-line-init () {
    local now=$EPOCHREALTIME
    local elapsed=$((now - __newt[+prompt_time+start]))
    printf -v '__newt[+prompt_time+]' '%.*f' \
        $(__newt_zstyle -d 6 prompt_time precision) $elapsed
}


# + status: Exit status of last command {{{1

# NB Special case precmd func
__newt_precmd_save_status () {
    # This should be first, to save status from user's command
    __newt[save_status]=$?
}

__newt+status+setup () {
    __newt[save_status]=0
    __newt_default status error        $'\u2718 %?'  # ✘
    __newt_default status error     bg "$__newt[color5]"
    __newt_default status error     fg "$__newt[color6]"
    #__newt_default status ok           $'\u2713'  # ✓
    __newt_default status ok        fg "$__newt[color-green]"
    #__newt_default status suspended    $'\u25c6'  # ◆
    __newt_default status suspended fg "$__newt[color-yellow]"
}

__newt+status+preexec () {
    # A command is being run, so clear flag
    unset '__newt[+status+done]'
}

__newt+status+precmd () {
    local state
    case $__newt[save_status] in
        0)      state=ok ;;
        20|148) state=suspended ;;
        *)      state=error ;;
    esac

    # Ignore if no new command has been run since last status was shown
    (( $+__newt[+status+done] )) && state=nocommand

    __newt[+status+state]=$state
    zformat -f '__newt[+status+]' "$(__newt_zstyle status $state)" \
        '?':$__newt[save_status]

    __newt[+status+done]=1
}

# + time: Current time {{{1
__newt+time+precmd () {
    __newt[+time+]=$(__newt_zstyle -d %T time default)
}

# + vcs: Version control {{{1
__newt+vcs+setup () {
    local green=$(__newt_fg_color $__newt[color-green])
    local yellow=$(__newt_fg_color $__newt[color-yellow])
    local red=$(__newt_fg_color $__newt[color-red])
    #zstyle :vcs_info:'*+*:*' debug true
    zstyle :vcs_info:\* check-for-changes true
    zstyle :vcs_info:\* stagedstr     $green$'\u25cf'       # ●
    zstyle :vcs_info:\* untrackedstr  $yellow$'\u25cf'      # ●
    zstyle :vcs_info:\* unstagedstr   $red$'\u25cf'         # ●
    zstyle :vcs_info:\* formats       $'\ue0a0%m%u%c %f%b'  # 
    zstyle :vcs_info:\* actionformats $'\ue0a0 %b|%a%f'     # 

    zstyle :vcs_info:git\*+post-backend:\* hooks \
        newt-show-gitdir \
        newt-remotebranch \
        newt-upstream \
        # ∴

    zstyle :vcs_info:git\*+set-message:\* hooks \
        newt-untracked \
        newt-finalize \
        # ∴
}

__newt+vcs+precmd () {
    vcs_info

    if (( $+__newt[+vcs+clobber] )); then
        __newt[+vcs+state]=clobbered
    elif [[ ${EUID} = 0 ]]; then
        # Generally it's a mistake to use a VCS as root
        __newt[+vcs+state]=root
    elif (( $+__newt[+vcs+action] )); then
        __newt[+vcs+state]=action
    elif (( $+__newt[+vcs+dirty] )); then
        __newt[+vcs+state]=dirty
    else
        unset '__newt[+vcs+state]'
    fi

    __newt[+vcs+]=$vcs_info_msg_0_

    unset '__newt[+vcs+clobber]'
    unset '__newt[+vcs+action]'
    unset '__newt[+vcs+dirty]'
}


# + vi_mode: Line editing mode {{{1
__newt+vi_mode+setup () {
    __newt_default vi_mode viins   ''
    __newt_default vi_mode vicmd   NORMAL
    __newt_default vi_mode replace REPLACE
    __newt_default vi_mode isearch SEARCH
    __newt_default vi_mode visual  VISUAL
    __newt_default vi_mode vline   V-LINE

    local vary const const_color
    [[ $__newt[color1] = '' ]] \
        && vary=fg const=bg const_color='' \
        || vary=bg const=fg const_color='bg:'

    __newt_default vi_mode \*      $const "$const_color"
    __newt_default vi_mode viins   $vary  "$__newt[color-yellow]"
    __newt_default vi_mode vicmd   $vary  "$__newt[color-green]"
    __newt_default vi_mode replace $vary  "$__newt[color-cyan]"
    __newt_default vi_mode isearch $vary  "$__newt[color-magenta]"
    __newt_default vi_mode visual  $vary  "$__newt[color-blue]"
    __newt_default vi_mode vline   $vary  "$__newt[color-blue]"
}

__newt+vi_mode+zle-keymap-select   () { __newt+vi_mode+hook "$@" }
__newt+vi_mode+zle-isearch-update  () { __newt+vi_mode+hook "$@" }
__newt+vi_mode+zle-isearch-exit    () { __newt+vi_mode+hook "$@" }
__newt+vi_mode+zle-line-pre-redraw () { __newt+vi_mode+hook "$@" }

__newt+vi_mode+hook () {
    local mode="${VIM_MODE_KEYMAP-$KEYMAP}"
    #__newt_debug "vi_mode: ${__newt[+vi_mode+state]} -> $mode [$@]"
    case $mode in
        viins|vicmd|replace|isearch|visual|vline) ;;
        main|*) mode=viins ;;
    esac
    [[ $mode = $__newt[+vi_mode+state] ]] && return 1
    #__newt_debug "       + ${__newt[+vi_mode+state]} -> $mode"
    __newt[+vi_mode+state]=$mode
    __newt[+vi_mode+]=$(__newt_zstyle vi_mode $mode)
}

# VCS_Info hooks for git {{{1

# + $GITDIR {{{1
+vi-newt-show-gitdir () {
    local inner
    if (( $+GIT_DIR )); then
        () {
            # See if we're in a shadowed repository
            local GIT_DIR GIT_WORK_TREE
            inner=$(${vcs_comm[cmd]} rev-parse --verify HEAD 2> /dev/null)
        }

        if [[ -n $inner && $inner != $hook_com[revision] ]]; then
            # GIT_DIR is shadowing a different repo. This can be
            # very confusing! Set a flag to trigger an alert.
            __newt[+vcs+clobber]=1
        fi

        local gdir; print -v gdir -D $GIT_DIR
        gdir="$(__newt_fg_color "$__newt[color-cyan]")$gdir"$'\u2261'"%f"  # ≡
        hook_com[branch]="$gdir${hook_com[branch]}"
    fi
}

# + Tracking remote branch? {{{1
+vi-newt-remotebranch () {
    local remote

    # Are we on a remote-tracking branch?
    remote=${$(${vcs_comm[cmd]} rev-parse --verify ${hook_com[branch_orig]}@{upstream} \
        --symbolic-full-name 2>/dev/null)#refs/remotes/}

    # The first test will show a tracking branch whenever there is one. The
    # second test, however, will only show the remote branch's name if it
    # differs from the local one.
    #if [[ -n ${remote} ]] ; then
    if [[ -n ${remote} && ${remote#*/} != ${hook_com[branch_orig]} ]] ; then
        hook_com[branch]+="$(__newt_fg_color "$__newt[color-cyan]")"$'\u00a4'"${remote}"  # ¤
    fi
}

# + New untracked files? {{{1
+vi-newt-untracked () {
    if [[ $(${vcs_comm[cmd]} rev-parse --is-inside-work-tree 2> /dev/null) = 'true' ]] \
        && ${vcs_comm[cmd]} status --porcelain | command grep -m 1 '^??' &>/dev/null
    then
        local str; zstyle -s :vcs_info:\* untrackedstr str
        hook_com[unstaged]+=${str:-T}
    fi
}

+vi-newt-finalize () {
    [[ -n $hook_com[unstaged] ]] && __newt[+vcs+dirty]=1
    [[ -n $hook_com[action] ]]   && __newt[+vcs+action]=1
}

# + Ahead / behind of upstream? {{{1
+vi-newt-upstream () {
    local b; b="${hook_com[branch_orig]}@{upstream}"

    local ahead behind
    ahead=$( ${vcs_comm[cmd]} rev-list $b..HEAD 2>/dev/null | wc -l)
    behind=$(${vcs_comm[cmd]} rev-list HEAD..$b 2>/dev/null | wc -l)

    local -a gitstatus
    (( $ahead ))  && gitstatus+=( $'\u25b4'$ahead )   # ▴
    (( $behind )) && gitstatus+=( $'\u25be'$behind )  # ▾

    (( $#gitstatus )) && hook_com[misc]+="${(j:/:)gitstatus}"
}

# Styling: setting defaults, getting values {{{1

# Print the defaults, using zstyle format so it is easy to copy and
# modify to create a zstyle override.
prompt_newt_defaults () {
    local -a z
    local -i m1 m2
    local a b
    for k v in "${(kv)__newt_defaults[@]}"; do
        a=${${=k}[1,-2]}
        b=${${=k}[-1]}
        (( m1 < $#a )) && m1=$#a
        (( m2 < $#b )) && m2=$#b
    done

    local ctx=':prompt-theme:newt:*:'
    for k v in "${(kv)__newt_defaults[@]}"; do
        z[$#z+1]=$(printf \
                'zstyle   %-*s %-*s %s' \
                $(($#ctx + m1 + 4)) ${(qq):-$ctx${(j.:.)${=k}[1,-2]}} \
                $((m2 + 2)) "${(q)${=k}[-1]}" \
                ${(q)v})
    done

    LANG=C print -o -lr $z
}

__newt_default () {
    local -A opts
    zparseopts -A opts -D - d
    (( $+opts[-d] )) \
        && unset "__newt_defaults[$*]" \
        || __newt_defaults+=(["${*[1,-2]}"]="${*[-1]}")
}

__newt_zstyle () {
    local -A opts
    zparseopts -A opts -D - d: x
    local look="${@[-1]}"
    local ctx=($__newt[ctx] "${@[1,-2]}")

    local val; unset val
    # See if a setting is defined
    zstyle -t ${(j.:.)ctx} "$look"
    if [[ $? -ne 2 ]]; then
        zstyle -s ${(j.:.)ctx} "$look" val
    else
        # If -x option, then do a simplified wildcard search through
        # the defaults. Say context is a b c, then this will check for
        # "a b c", "a b *", "a * *", "* * *", and use the first match.
        # If not -x option, then only look for a full "a b c" match.
        ctx=( $ctx[2,-1] $look )
        local i
        (( $+opts[-x] )) && i=$(($#ctx - 1)) || i=0
        while true; do
            if (( ${+__newt_defaults[$ctx]} )); then
                val=${__newt_defaults[$ctx]}
                break
            fi

            (( i < 1 )) && break
            ctx[$i]='*'
            i=$((i - 1))
        done
        (( $+val )) || val=$opts[-d]
    fi
    print -rn $val
}


# Colors handling {{{1

# + Resolve color to prompt format sequence {{{1
__newt_bg_color () {
    local c
    case $1 in
        none)
            c=
            ;;
        '' | _ )
            c="%k"
            ;;
        fg:*)
            c=${1#*:}
            [[ -z $c ]] && c=$(__newt_terminal_fg)
            c="%K{$c}"
            ;;
        *)
            c="%K{$1}"
            ;;
    esac
    print -rn $c
}

__newt_fg_color () {
    local c
    case $1 in
        none)
            c=
            ;;
        '' | _ )
            c="%f"
            ;;
        bg:*)
            c=${1#*:}
            [[ -z $c ]] && c=$(__newt_terminal_bg)
            c="%F{$c}"
            ;;
        *)
            c="%F{$1}"
            ;;
    esac
    print -rn $c
}

# + Get bg/fg color of terminal {{{1
#   - TODO Use escape sequence to query terminal for color, see
#     http://thrysoee.dk/xtermcontrol/
#     https://github.com/JessThrysoee/xtermcontrol
#     https://superuser.com/questions/157563/programmatic-access-to-current-xterm-background-color
#     Maybe it can be implemented with the zsh/zpty module?

__newt_terminal_bg () {
    local color

    zstyle -s :prompt-theme terminal-background color
    : ${color:=${COLORFGBG#*;}}
    : ${color:=black}
    print -n $color
}

__newt_terminal_fg () {
    local color

    zstyle -s :prompt-theme terminal-foreground color
    : ${color:=${COLORFGBG%%;*}}
    : ${color:=white}
    print -n $color
}

# + Convert truecolor formats into escape codes {{{1
__newt_truecolor_escape () {
    __newt_truecolor_escape_format () {
        local n
        [[ $1 = F ]] && n=38 || n=48
        shift;
        printf '%%{\x1b[%d;2;%d;%d;%dm%%}' $n "$@"
    }

    print -nr "${1//(#bm)%(K|F)\{([0-9]#)\;([0-9]#)\;([0-9]#)\}/$(
            __newt_truecolor_escape_format $match[@])}"
}


# Update prompt strings {{{1

__newt_update_prompt () {
    local side="$1"
    local hook="$2"

    #__newt_debug "update_prompt: $hook $side $@"
    __newt_do_segments $side $hook || return
    __newt_assemble_segments $side
}

__newt_do_segments () {
    local side="$1"
    local hook="$2"
    local changed=0
    local func segment
    for segment in "${=__newt[$side]}"; do
        func="__newt+$segment+$hook"
        (( ${+functions[$func]} )) || continue
        $func $hook && changed=1
    done

    (( $changed )) || return 1
    return 0
}

# + Assemble pre-calculated segments into a prompt string {{{1
__newt_assemble_segments () {
    setopt local_options extended_glob
    local side="$1"

    local direction
    [[ $side = left ]] && direction=0 || direction=1

    # For future use, this is how many lines up from the input this prompt
    # should be drawn. stack == 0 is the input line.
    local stack=0

    # TODO Make this configurable, and add more separators to it
    separators=(
        # Powerline
        $'\ue0b0'  #  Left-to-right, solid (when new background)
        $'\ue0b2'  #  Right-to-left, solid
        $'\ue0b1'  #  Left-to-right, thin (when same background)
        $'\ue0b3'  #  Right-to-left, thin
    )

    # ++ Fill in arrays holding values for active segments {{{1
    local -a segment content bg fg sep

    local padding
    zstyle -t $__newt[ctx] compact && padding= || padding=' '

    local seg state
    for seg in "${=__newt[$side]}"; do
        [[ -n ${__newt[+${seg}+]} || $__newt[+${seg}+show_empty] = 1 ]] \
            || continue

        segment+=$seg

        state=${__newt[+${seg}+state]:-default}
        bg+=$(__newt_zstyle -x "$seg" "$state" bg)
        fg+=$(__newt_zstyle -x "$seg" "$state" fg)

        sep+=0  # For now, all user segments are normal

        # Pre-process the content a bit to add spacing, etc.
        local tmp="${__newt[+${seg}+]}"

        # Replace %k and %f with segment bg and fg colors
        # NB: This doesn't use zformat because that will gobble up other formats
        # in the content, like %(X,...), which the user specified. This simple
        # substitution will do the wrong thing with something like '%%killed',
        # but that should be rare and *could* be worked around.
        local tmp2=$(__newt_bg_color "$bg[-1]")
        tmp=${tmp:gs/%k/${tmp2}}
        local tmp2=$(__newt_fg_color "$fg[-1]")
        tmp=${tmp:gs/%f/${tmp2}}

        # Trim whitespace
        tmp=${padding}${${tmp##[[:space:]]##}%%[[:space:]]##}${padding}

        content+=$tmp
    done

    # ++ Handle beginning & end of prompt for left/right side {{{1
    if [[ $direction = 0 ]]; then
        # This is a left-to-right prompt
        if (( !stack )); then
            # Add on a segment to prepare for user input
            segment+=ready-for-input
            content+=' '
            bg+=
            fg+=
            sep+=-1
        fi
    else
        # This is a right-to-left prompt, so the separator precedes the
        # segment.

        # First, insert an empty segment at the front to effectively
        # shift all the prompts left
        segment[1,0]=beginning-of-line
        content[1,0]=''
        bg[1,0]=
        fg[1,0]=

        # Then add a null separator at the end, to finish the last segment
        sep+=-1

        # Remove a trailing space to account for $ZLE_RPROMPT_INDENT, and
        # extend the current background color to the end of the line
        content[-1]="${content[-1]/% /%E}"

        # Add a segment to reset colors at end of line
        segment+=end-of-line
        content+=$'%{\e[0m%}'
        bg+=
        fg+=
        sep+=-1
    fi

    # ++ Gather the arrays into a prompt string {{{1
    local result=

    local i=0
    local b0=%k f0=%f
    local b1 f1
    while ((i < $#content)); do
        i=$((i+1))
        __newt_debug "$i:$segment[i] - (${(q)content[i]}) b(${(q)bg[i]}) f(${(q)fg[$i]}) s(${(q)sep[$i]})"

        # +++ Colors for the segment body {{{1
        b1=$(__newt_bg_color "$bg[$i]")
        [[ $b0 = $b1 ]] || result+=$b1
        b0=$b1
        f1=$(__newt_fg_color "$fg[$i]")
        [[ $f0 = $f1 ]] || result+=$f1
        f0=$f1

        # +++ The segment content proper {{{1
        result+=$content[$i]

        # +++ The separator {{{1
        if (( ${sep[$i]} >= 0 )); then
            if (( $i >= $#content )); then
                print "IMPOSSIBLE, index $i has a separator (${(qq)sep[$i]}) off the end ($#content)" >&2
                bg[$i+1]=196
                fg[$i+1]=220
            fi

            # The sep[i] is 0 for "normal" direction (points right on a left-
            # hand prompt, and points left on a right-hand prompt). It is 1
            # for a reversed separator. So XOR of prompt direction and sep[i]
            # gives the direction of the separator itself.
            local sep_direction=$((direction ^ ${sep[$i]}))
            if [[ $bg[$i] = $bg[$i+1] ]]; then
                local thin=1
                b1=$(__newt_bg_color "$bg[$i]")
                # When direction=1 (right prompt), the separator precedes its
                # segment, so look there for the color
                f1=$(__newt_fg_color "$fg[$i+$direction]")
            else
                thin=0
                # Solid separator uses the background color of the dominant
                # segment as its foreground. When sep_direction=1 ("points
                # to the left"), the dominant segment is to the right,
                # otherwise it is this segment. Background is from the
                # opposite.
                f1=$(__newt_fg_color "bg:$bg[$i+$sep_direction]")
                b1=$(__newt_bg_color "$bg[$i+$((sep_direction ^ 1))]")
            fi
            [[ $b0 == $b1 ]] || result+=$b1
            b0=$b1
            [[ $f0 == $f1 ]] || result+=$f1
            f0=$f1
            local index=$(( 1 + 2 * thin + sep_direction ))
            __newt_debug "+ sep index $index thin($thin) sep_dir($sep_direction)"
            result+=${separators[$index]}
        fi
    done

    # ++ Store the prompt string {{{1

    # Change %F{RRR;GGG;BBB} to TrueColor escapes
    result=$(__newt_truecolor_escape "$result")

    __newt_debug "$side = [${(q)result}]"

    [[ $side = left ]] && PS1=$result || RPS1=$result
}


# Hook function manipulations {{{1

__newt_list_zsh_hooks () {
    print \
        chpwd precmd preexec periodic \
        zshaddhistory zshexit zsh_directory_name
}

__newt_list_zle_hooks () {
    print \
        isearch-exit isearch-update line-pre-redraw \
        line-init line-finish history-line-set keymap-select
}

__newt_add_hooks () {
    local add_func="$1"; shift
    local tag="$1"; shift

    [[ -n $tag ]] && tag="${tag}-"

    local hook func segment
    local -a funcs

    for hook in "$@"; do
        funcs=()
        for segment in ${=__newt[left]} ${=__newt[right]}; do
            func="__newt+$segment+$tag$hook"
            (( ${+functions[$func]} )) || continue
            funcs+=$func
        done

        (( $#funcs )) || continue

        __newt[hooks+$tag$hook]="$funcs"

        func=__newt_hook_$tag$hook
        eval "$func () { __newt_hook $tag$hook \$@ }"
        $add_func $hook $func
    done
}

__newt_hook () {
    local hook="$1"
    __newt_update_prompt left  $hook
    __newt_update_prompt right $hook

    if [[ $hook = zle-* ]]; then
        zle reset-prompt
    fi
}

__newt_delete_hooks () {
    local delete_func="$1"; shift

    # Both use -D to delete based on a pattern
    for hook in "$@"; do
        ${delete_func} -D $hook 'prompt_newt_*'
        ${delete_func} -D $hook '__newt_*'
    done
}


# Cleanup {{{1
prompt_newt_cleanup () {
    __newt_delete_hooks add-zsh-hook \
        ${=$(__newt_list_zsh_hooks)}

    __newt_delete_hooks add-zle-hook-widget \
        ${=$(__newt_list_zle_hooks)}

    local func
    for func in ${(kM)functions:#prompt_newt[[:punct:]]*}; do
        unset "functions[$func]"
    done
    for func in ${(kM)functions:#__newt[[:punct:]]*}; do
        unset "functions[$func]"
    done
    for func in ${(kM)functions:#+vi-newt-*}; do
        unset "functions[$func]"
    done

    local -a vcs_hooks
    vcs_hooks=("${${(f)$(zstyle -L ':vcs_info:*' hooks)}[@]}")
    local hook a
    for hook in $vcs_hooks; do
        # a=(zstyle :vcs_info:\*+whatever:\* hooks hook-func-1 ...)
        a=("${(Qz)hook[@]}")

        local i=$#a
        while ((i > 3)); do
            [[ $a[$i] = newt-* ]] && a[$i]=()
            i=$((i-1))
        done

        # If just (zstyle ':vcs_info:*' hooks), delete the style
        (( $#a <= 3 )) && a[2,0]=(-d)

        # It is this already. But it makes me feel better to run a
        # hard-coded command rather than accept outside text
        a[1]=zstyle

        # Actually run the command
        $a
    done

    unset __newt
    unset __newt_defaults
    unset __newt_look
    unset PROMPT_NEWT_LOOK

    autoload -Uz prompt_newt_setup
}

# Preview {{{1

prompt_newt_preview () {
    local _zsh_theme_preview_euid
    local _zsh_theme_preview_hostname
    local count=0

    if (( $#* )); then
        set -- "$*"
    else
        set -- default ${(ok)__newt_look:#default} \
            'example black 5 white 4 red 3'
    fi

    __newt_preview_show () {
        __newt_assemble_segments left
        __newt_assemble_segments right
        [[ -o promptcr ]] && print -n $'\r'; :
        print -P "${PS1}$*%-1<<${(l:COLUMNS:: :)}${RPS1}"
    }

    __newt_preview_look () {
        count=$((count+1))
        (( count > 1 )) && print ""
        print -n "newt theme"
        (( $#* )) && print -n " with parameters \`$*'"
        print ":"

        prompt_newt_setup "$@"
        __newt_hook precmd

        # Fake vcs info if $PWD isn't
        if [[ -z $__newt[+vcs+] ]]; then
            local formats; zstyle -s :vcs_info:\* formats     formats
            local str_c;   zstyle -s :vcs_info:\* stagedstr   str_c
            local str_u;   zstyle -s :vcs_info:\* unstagedstr str_u
            zformat -f '__newt[+vcs+]' "$formats" \
                m: \
                u:$str_u \
                c:$str_c \
                b:master
            __newt[+dir+]='~/code'
        fi
        __newt[+jobs+]=$'\u2699 2'
        local msg='vi README.txt'
        (( ${COLUMNS:-80} > 78)) && msg+='   # jobs, git'
        __newt_preview_show $msg

        __newt[+dir+]=/etc
        __newt[+dir+state]=root
        __newt[+jobs+]=
        __newt[+context+]=daffy
        __newt[+vcs+]=
        __newt[+vi_mode+]=$fake_vi[2]
        __newt[+vi_mode+state]=$fake_vi[1]
        local msg='rm -rf /  # root'
        (( ${COLUMNS:-80} > 78)) && msg+=', remote host, vi-mode'
        __newt_preview_show $msg

        fake_vi[1,2]=()
    }

    local -a fake_vi=( vicmd  NORMAL  isearch SEARCH  replace REPLACE
                       visual VISUAL  vline   V-LINE  viins   '' )

    for look in "$@"; do
        __newt_preview_look $=look
    done

    unfunction __newt_preview_show __newt_preview_look
    prompt_newt_cleanup
}


# Help {{{1

prompt_newt_help () {
    local looks='default, '${(j., .)${(ok)__newt_look//#%default}}
    cat <<EOF
>   “She turned me into a newt!”
>   “A newt?”
>   “… I got better.”

Newt comes with these pre-defined looks:

${looks}
EOF
    cat <<'EOF'

Use a look with `prompt newt meadow`.

Create a `bespoke` look with `prompt newt bespoke blue white magenta`,
giving a name and a list of colors. Each color can be

Every part of the prompt can be configured individually. See the full
documentation for details:

        https://github.com/softmoth/zsh-prompt-newt/#readme
EOF

    # promptinit doesn't handle cleanup
    [[ $prompt_theme[1] = newt ]] || prompt_newt_cleanup
}


# Main Prompt Setup {{{1

prompt_newt_setup () {
    autoload -Uz add-zsh-hook
    autoload -Uz add-zle-hook-widget
    autoload -Uz vcs_info

    setopt local_options noaliases

    typeset -g -A -H __newt=()
    typeset -g -A -H __newt_defaults=()
    PS1=
    RPS1=

    add-zsh-hook precmd __newt_precmd_save_status

    # + Styling {{{1

    # Inverse colors for defaults
    local -a colorbgfg=( $(__newt_terminal_fg) $(__newt_terminal_bg) )

    typeset -g -A __newt_look
    __newt_look[default]=$colorbgfg
    __newt_look[denver]="'' 202 '' 33 '' 196"
    __newt_look[forest]='22 229 24 229'
    __newt_look[meadow]='149 235 81 235'
    __newt_look[mono]='235 242 238 250 235 197'

    local -a look

    if [[ $#@ == 0 || $1 = '--' ]]; then
        look[1]=( "${${(z)${PROMPT_NEWT_LOOK:-${1-default}}}[@]}" )
        (( $#@ )) && shift
    fi
    look+=("${(qq)@}")

    (( $#look )) && case ${(Q)look[1]} in
        '' | _ | none | fg:* | bg:* | [0-9]* \
        | black | red | green | yellow | blue | magenta | cyan | white )
            print "$0: ERROR: Color found where look name expected." \
                "Did you intend: \`$0 ${USER:-'pretty'} ${(q)@}\`?"
            look[1,0]='--'
            ;;
    esac

    look[1]=${(Q)look[1]}

    # Env variable can be used in .zshrc, etc.
    export PROMPT_NEWT_LOOK="${look[*]}"
    __newt[look]=$look[1]

    if (( $+__newt_look[$look[1]] )); then
        # Splice in the predefined colors for this look
        look[2,0]=("${${(z)${__newt_look[$look[1]]}}[@]}")
    fi

    __newt[ctx]=:prompt-theme:newt:$__newt[look]

    $0-set-colors () {
        # Primary segment
        __newt[color1]=${1-$colorbgfg[1]}
        __newt[color2]=${2-$colorbgfg[2]}
        # Secondary segment
        __newt[color3]=${3-blue}
        __newt[color4]=${4-$__newt[color2]}
        # Alert segment
        __newt[color5]=${5-''}
        __newt[color6]=${6-red}

        __newt[color-red]=${7-red}
        __newt[color-green]=${8-green}
        __newt[color-yellow]=${9-yellow}
        __newt[color-blue]=${10-blue}
        __newt[color-magenta]=${11-magenta}
        __newt[color-cyan]=${12-cyan}
        __newt[color-black]=${13-black}
        __newt[color-white]=${14-white}
    }

    $0-set-colors "${(Q)look[2,-1][@]}"

    unfunction $0-set-colors

    __newt_default left  'history time context notice dir'
    __newt_default right 'vi_mode status exec_time jobs vcs'

    __newt[left]=$(__newt_zstyle  left)
    __newt[right]=$(__newt_zstyle right)

    __newt_default vi_mode \*        bg "$__newt[color-yellow]"
    __newt_default \*      \*        bg "$__newt[color1]"
    __newt_default \*      \*        fg "$__newt[color2]"
    __newt_default dir     \*        bg "$__newt[color3]"
    __newt_default dir     \*        fg "$__newt[color4]"
    __newt_default dir     root      bg "$__newt[color5]"
    __newt_default dir     root      fg "$__newt[color6]"

    __newt_default vcs     \*        bg "$__newt[color3]"
    __newt_default vcs     \*        fg "$__newt[color4]"
    __newt_default vcs     clobbered bg "$__newt[color5]"
    __newt_default vcs     clobbered fg "$__newt[color6]"
    __newt_default vcs     root      bg "$__newt[color5]"
    __newt_default vcs     root      fg "$__newt[color6]"

    #__newt_default vcs     action    bg "$__newt[color-cyan]"
    #__newt_default vcs     action    fg "$__newt[color-black]"
    #__newt_default vcs     dirty     bg "$__newt[color-magenta]"
    #__newt_default vcs     dirty     fg "$__newt[color-black]"

    __newt_do_segments left  setup
    __newt_do_segments right setup

    # + Finalization {{{1

    __newt_add_hooks add-zsh-hook '' \
        ${=$(__newt_list_zsh_hooks)}

    __newt_add_hooks add-zle-hook-widget zle \
        ${=$(__newt_list_zle_hooks)}

    prompt_cleanup '(( ${+functions[prompt_newt_cleanup]} )) && prompt_newt_cleanup'

    # Shouldn't need this if everything is put in precmd properly
    #prompt_opts=(cr subst percent)

    return 0
}

#__newt_debug () { print -r "$(date) $@" >> /tmp/zsh-debug-newt.log 2>&1 }
__newt_debug () { :; }

[[ -o kshautoload ]] || prompt_newt_setup "$@"

# vim:set sw=4 et ft=zsh fdm=marker fmr={{{,}}}}}:
