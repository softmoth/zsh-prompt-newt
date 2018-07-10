emulate -L zsh

zmodload zsh/datetime
zmodload zsh/parameter
zmodload zsh/mathfunc

# Prompt Segments {{{1

# + context: user@host {{{1
function __newt+context+precmd () {
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
function __newt+dir+precmd () {
    __newt[+dir+]='%4~'

    [[ $EUID = 0 ]] \
        && __newt[+dir+state]=root \
        || __newt[+dir+state]=
}

# + exec_time: Execution time of last command {{{1
function __newt+exec_time+setup () {
    __newt_default $'\u9593%t' long exec_time  # 間
    __newt_default 5 threshold exec_time
}

function __newt+exec_time+preexec () {
    __newt[+exec_time+start]=$EPOCHREALTIME
}

function __newt+exec_time+precmd () {
    local state

    local stop=$EPOCHREALTIME
    local start=${__newt[+exec_time+start]:-$stop}

    local threshold="$(__newt_zstyle threshold exec_time)"
    local -F elapsed=$((stop - start))
    if (( $elapsed >= $threshold )); then
        state=long
    else
        state=default
    fi

    local precision="$(__newt_zstyle precision exec_time)"
    if [[ -z $precision ]]; then
        (( elapsed < 10 )) && precision=1 || precision=0
    fi

    __newt[+exec_time+state]=$state
    zformat -f '__newt[+exec_time+]' \
        "$(__newt_zstyle $state exec_time)" \
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

# + jobs: Background jobs {{{1
function __newt+jobs+precmd () {
    # \u2699 is ⚙
    (( ${(%):-%j} )) \
        && __newt[+jobs+]=$(__newt_zstyle -d $'\u2699 %j' jobs default) \
        || __newt[+jobs+]=$(__newt_zstyle jobs zero)
}

# + none: Placeholder to do nothing {{{1
function __newt+none+setup () {
}

# + notice: Generic info display {{{1
function __newt+notice+add-note () {
    __newt[+notice+notes]+=" $*"
}

function __newt+notice+precmd () {
    __newt[+notice+]=$__newt[+notice+notes]
    unset '__newt[+notice+notes]'
}

# + prompt_time: How long the prompt takes to draw {{{1

# Install this precmd function specially so it gets called first
function __newt_prompt_time_precmd {
    __newt[+prompt_time+start]=$EPOCHREALTIME
}

function __newt+prompt_time+setup () {
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

function __newt+prompt_time+zle-line-init () {
    local now=$EPOCHREALTIME
    local elapsed=$((now - __newt[+prompt_time+start]))
    printf -v '__newt[+prompt_time+]' '%.*f' \
        $(__newt_zstyle -d 6 precision prompt_time) $elapsed
}


# + status: Exit status of last command {{{1
function __newt+status+setup () {
    __newt[save_status]=0
    __newt_default $'\u2718 %?' status error      # ✘
    __newt_default "$__newt[color5]"        bg status  error
    __newt_default "$__newt[color6]"        fg status  error
    #__newt_default $'\u2713'    status ok         # ✓
    __newt_default "$__newt[color-green]"   fg status  ok
    #__newt_default $'\u25c6'    status suspended  # ◆
    __newt_default "$__newt[color-yellow]"  fg status  suspended
}

function __newt+status+preexec () {
    # A command is being run, so clear flag
    unset '__newt[+status+done]'
}

function __newt+status+precmd () {
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
function __newt+time+precmd () {
    __newt[+time+]='%T'
}

# + vcs: Version control {{{1
function __newt+vcs+setup () {
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

function __newt+vcs+precmd () {
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
function __newt+vi_mode+setup () {
    __newt_default ''      viins   vi_mode
    __newt_default NORMAL  vicmd   vi_mode
    __newt_default REPLACE replace vi_mode
    __newt_default SEARCH  isearch vi_mode
    __newt_default VISUAL  visual  vi_mode
    __newt_default V-LINE  vline   vi_mode

    local vary const const_color
    [[ $__newt[color1] = '' ]] \
        && vary=fg const=bg const_color='' \
        || vary=bg const=fg const_color='bg:'

    __newt_default "$const_color"                 $const vi_mode \*
    __newt_default "$__newt[color-yellow]"  $vary  vi_mode \*
    __newt_default "$__newt[color-green]"   $vary  vi_mode vicmd
    __newt_default "$__newt[color-cyan]"    $vary  vi_mode replace
    __newt_default "$__newt[color-magenta]" $vary  vi_mode isearch
    __newt_default "$__newt[color-blue]"    $vary  vi_mode visual
    __newt_default "$__newt[color-blue]"    $vary  vi_mode vline
}

function __newt+vi_mode+zle-keymap-select   () { __newt+vi_mode+hook "$@" }
function __newt+vi_mode+zle-isearch-update  () { __newt+vi_mode+hook "$@" }
function __newt+vi_mode+zle-isearch-exit    () { __newt+vi_mode+hook "$@" }
function __newt+vi_mode+zle-line-pre-redraw () { __newt+vi_mode+hook "$@" }

function __newt+vi_mode+hook () {
    local mode="${VIM_MODE_KEYMAP-$KEYMAP}"
    #__newt_debug "vi_mode: ${__newt[+vi_mode+state]} -> $mode [$@]"
    case $mode in
        viins|vicmd|replace|isearch|visual|vline) ;;
        main|*) mode=viins ;;
    esac
    [[ $mode = $__newt[+vi_mode+state] ]] && return 1
    #__newt_debug "       + ${__newt[+vi_mode+state]} -> $mode"
    __newt[+vi_mode+state]=$mode
    __newt[+vi_mode+]=$(__newt_zstyle $mode vi_mode)
}

# VCS_Info hooks for git {{{1

# + $GITDIR {{{1
function +vi-newt-show-gitdir () {
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
function +vi-newt-remotebranch () {
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
function +vi-newt-untracked () {
    if [[ $(${vcs_comm[cmd]} rev-parse --is-inside-work-tree 2> /dev/null) = 'true' ]] \
        && ${vcs_comm[cmd]} status --porcelain | command grep -m 1 '^??' &>/dev/null
    then
        local str; zstyle -s :vcs_info:\* untrackedstr str
        hook_com[unstaged]+=${str:-T}
    fi
}

function +vi-newt-finalize () {
    [[ -n $hook_com[unstaged] ]] && __newt[+vcs+dirty]=1
    [[ -n $hook_com[action] ]]   && __newt[+vcs+action]=1
}

# + Ahead / behind of upstream? {{{1
function +vi-newt-upstream () {
    local b; b="${hook_com[branch_orig]}@{upstream}"

    local ahead behind
    ahead=$( ${vcs_comm[cmd]} rev-list $b..HEAD 2>/dev/null | wc -l)
    behind=$(${vcs_comm[cmd]} rev-list HEAD..$b 2>/dev/null | wc -l)

    local -a gitstatus
    (( $ahead ))  && gitstatus+=( $'\u25b4'$ahead )   # ▴
    (( $behind )) && gitstatus+=( $'\u25be'$behind )  # ▾

    (( $#gitstatus )) && hook_com[misc]+="${(j:/:)gitstatus}"
}


# Drawing Powerline segments {{{1

# + Add a left segment {{{1
function __newt_lsegment () {
    local seg_separator
    __newt_set_lseg_separator "$1" "$2"

    local seg_content="$3"
    __newt_finalize_segment

    prompt_result=$seg_content$seg_separator$prompt_result
}

# ++ Determine how to draw the left segment separator {{{1
function __newt_set_lseg_separator () {
    typeset -g seg_separator prompt_b0 prompt_f0
    local b1="$1" f1="$2"

    local lthick_separator=$'\ue0b0'  # 
    local lthin_separator=$'\ue0b1'   # 

    [[ $b1 = none ]] && b1=$prompt_b0
    [[ $f1 = none ]] && f1=$prompt_f0

    seg_separator=
    if [[ $b1 = $prompt_b0 ]]; then
        seg_separator+=$lthin_separator
        [[ $f1 != $prompt_f0 ]] \
            && seg_separator+=$(__newt_fg_color $prompt_f0)
    else
        local sepfg="$(__newt_fg_color bg:$b1)"
        seg_separator+=$sepfg
        seg_separator+=$(__newt_bg_color $prompt_b0)
        seg_separator+=$lthick_separator
        local nextfg="$(__newt_fg_color $prompt_f0)"
        [[ $nextfg != $sepfg ]] && seg_separator+=$nextfg
    fi

    prompt_b0=$b1
    prompt_f0=$f1
}

# + Add a right segment {{{1
function __newt_rsegment () {
    local seg_separator
    __newt_set_rseg_separator "$1" "$2"

    local seg_content="$3"
    __newt_finalize_segment

    prompt_result+=$seg_separator$seg_content
}

# ++ Determine how to draw the separator for this segment {{{1
function __newt_set_rseg_separator () {
    typeset -g seg_separator prompt_b0 prompt_f0
    local b1="$1" f1="$2"

    local rthick_separator=$'\ue0b2' # 
    local rthin_separator=$'\ue0b3'  # 

    [[ $b1 = none ]] && b1=$prompt_b0
    [[ $f1 = none ]] && f1=$prompt_f0

    seg_separator=
    if [[ $b1 = $prompt_b0 ]]; then
        [[ $f1 != $prompt_f0 ]] \
            && seg_separator+=$(__newt_fg_color $f1)
        seg_separator+=$rthin_separator
    else
        local sepfg=$(__newt_fg_color bg:$b1)
        seg_separator+=$sepfg
        seg_separator+=$rthick_separator
        seg_separator+=$(__newt_bg_color $b1)
        local nextfg=$(__newt_fg_color $f1)
        [[ $nextfg != $sepfg ]] && seg_separator+=$nextfg
    fi

    prompt_b0=$b1
    prompt_f0=$f1
}

# + Resolve color to prompt format escape {{{1
function __newt_bg_color () {
    local c
    case $1 in
        none) c="%K{1}[none-bg]%k" ;;  # Shouldn't happen
        '')
            c="%k"
            ;;
        fg:*)
            c=${1#*:}
            [[ -z $c ]] && c=$(get_terminal_foreground)
            c="%K{$c}"
            ;;
        *)
            c="%K{$1}"
            ;;
    esac
    print -rn $c
}

function __newt_fg_color () {
    local c
    case $1 in
        none) c="%F{1}[none-fg]%f" ;;  # Shouldn't happen
        '')
            c="%f"
            ;;
        bg:*)
            c=${1#*:}
            [[ -z $c ]] && c=$(get_terminal_background)
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

function get_terminal_background () {
    local color

    zstyle -s :prompt-theme terminal-background color
    : ${color:=${COLORFGBG#*;}}
    : ${color:=black}
    print -n $color
}

function get_terminal_foreground () {
    local color

    zstyle -s :prompt-theme terminal-foreground color
    : ${color:=${COLORFGBG%%;*}}
    : ${color:=white}
    print -n $color
}

# + Finalize a segment's formatting escapes {{{1
function __newt_finalize_segment () {
    setopt local_options extended_glob
    typeset -g prompt_b0 prompt_f0 seg_separator seg_content

    zformat -f seg_content "$seg_content" \
        k:$(__newt_bg_color $prompt_b0) \
        f:$(__newt_fg_color $prompt_f0)

    # Trim whitespace
    seg_content=${${seg_content##[[:space:]]##}%%[[:space:]]##}

    zstyle -t $__newt[ctx] compact \
        || [ -z $seg_content ] || seg_content=" $seg_content "

    function make_truecolor_escape () {
        local n
        [[ $1 = F ]] && n=38 || n=48
        shift;
        printf '%%{\x1b[%d;2;%d;%d;%dm%%}' $n "$@"
    }

    # Change %F{RRR;GGG;BBB} to TrueColor escapes
    seg_separator="${seg_separator//(#bm)%(K|F)\{([0-9]#)\;([0-9]#)\;([0-9]#)\}/$(
            make_truecolor_escape $match[@])}"
    seg_content="${seg_content//(#bm)%(K|F)\{([0-9]#)\;([0-9]#)\;([0-9]#)\}/$(
            make_truecolor_escape $match[@])}"
}

# Styling: setting defaults, getting values {{{1

# Print the defaults, using zstyle format so it is easy to copy and
# modify to create a zstyle override.
function prompt_newt_defaults () {
    local -a z
    local -i m1 m2
    local a b
    for k v in "${(kv)__newt_defaults[@]}"; do
        a=${${=k}[2,-1]}
        b=${${=k}[1]}
        (( m1 < $#a )) && m1=$#a
        (( m2 < $#b )) && m2=$#b
    done

    local ctx=':prompt-theme:newt:*:'
    for k v in "${(kv)__newt_defaults[@]}"; do
        z[$#z+1]=$(printf \
                'zstyle   %-*s %-*s %s' \
                $(($#ctx + m1 + 4)) ${(qq):-$ctx${(j.:.)${=k}[2,-1]}} \
                $((m2 + 2)) "${(q)${=k}[1]}" \
                ${(q)v})
    done

    LANG=C print -o -lr $z
}

function __newt_default () {
    local -A opts
    zparseopts -A opts -D - d
    (( $+opts[-d] )) \
        && unset "__newt_defaults[$*]" \
        || __newt_defaults+=(["${@[2,-1]}"]=$1)
}

function __newt_zstyle () {
    local -A opts
    zparseopts -A opts -D - d: x
    local style="$1"
    local ctx=('' ${@[2,-1]})

    typeset -g -A __newt_defaults
    local val; unset val
    # See if a setting is defined
    zstyle -t ${__newt[ctx]}${(j.:.)ctx} "$style"
    if [[ $? -ne 2 ]]; then
        zstyle -s ${__newt[ctx]}${(j.:.)ctx} "$style" val
    else
        # If -x option, then do a simplified wildcard search through
        # the defaults. Say context is a b c, then this will check for
        # "a b c", "a b *", "a * *", "* * *", and use the first match.
        # If not -x option, then only look for a full "a b c" match.
        ctx[1,1]=()
        local i
        (( $+opts[-x] )) && i=$#ctx || i=0
        while true; do
            if (( ${+__newt_defaults[$style $ctx]} )); then
                val=${__newt_defaults[$style $ctx]}
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

# Update prompt strings {{{1

function __newt_update_prompt () {
    local hook="$1"; shift
    local side="$1"; shift

    #__newt_debug "update_prompt: $hook $side $@"
    __newt_do_segments $hook "$@" || return
    __newt_assemble_segments $side "$@"
}

function __newt_do_segments () {
    local hook="$1"; shift
    local changed=0
    local func segment
    for segment in "$@"; do
        func="__newt+$segment+$hook"
        (( ${+functions[$func]} )) || continue
        $func $hook && changed=1
    done

    (( $changed )) || return 1
    return 0
}

function __newt_assemble_segments () {
    local side="$1"; shift

    # These are state variables used in segment funcs
    # The prompt string being built inside __newt_?segment
    local prompt_result= prompt_b0= prompt_f0=

    local func
    [[ $side = left ]] \
        && func=__newt_lsegment \
        || func=__newt_rsegment

    local segment str state
    for segment in "$@"; do
        str=${__newt[+${segment}+]}

        [[ -n $str || $__newt[+${segment}+show_empty] = 1 ]] || continue

        state=${__newt[+${segment}+state]:-default}

        $func \
            "$(__newt_zstyle -x bg "$segment" "$state")" \
            "$(__newt_zstyle -x fg "$segment" "$state")" \
            $str
    done

    if [[ $side = left ]]; then
        [[ -n $prompt_b0 ]] && prompt_result="$(__newt_bg_color $prompt_b0)$prompt_result"
        [[ -n $prompt_f0 ]] && prompt_result="$(__newt_fg_color $prompt_f0)$prompt_result"

        PS1="${prompt_result} "
    else
        # Remove a final space, due to ZLE_RPROMPT_INDENT=1
        [[ ${ZLE_RPROMPT_INDENT:-1} -ge 1 ]] \
            && prompt_result="${prompt_result% }%E"

        # Using $reset_color ensures everything is off, and avoids some
        # display problems that may show up with %E%b & truecolor escape
        local reset_color=$'\e[00m'
        RPS1="${prompt_result}%{${reset_color}%}"
    fi
}

function __newt_precmd_save_status () {
    # This should be first, to save status from user's command
    __newt[save_status]=$?
}


# Hook function manipulations {{{1

function __newt_list_zsh_hooks () {
    print \
        chpwd precmd preexec periodic \
        zshaddhistory zshexit zsh_directory_name
}

function __newt_list_zle_hooks () {
    print \
        isearch-exit isearch-update line-pre-redraw \
        line-init line-finish history-line-set keymap-select
}

function __newt_add_hooks () {
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

function __newt_hook () {
    local hook="$1"
    __newt_update_prompt $hook left ${(Oa)=__newt[left]}
    __newt_update_prompt $hook right ${=__newt[right]}

    if [[ $hook = zle-* ]]; then
        zle reset-prompt
    fi
}

function __newt_delete_hooks () {
    local delete_func="$1"; shift

    # Both use -D to delete based on a pattern
    for hook in "$@"; do
        ${delete_func} -D $hook 'prompt_newt_*'
        ${delete_func} -D $hook '__newt_*'
    done
}


# Cleanup {{{1
function prompt_newt_cleanup () {
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
    unset __newt_style
    unset PROMPT_NEWT_STYLE

    autoload prompt_newt_setup
}

# Preview {{{1

function prompt_newt_preview () {
    local _zsh_theme_preview_euid
    local _zsh_theme_preview_hostname
    local count=0

    if (( $#* )); then
        set -- "$*"
    else
        set -- default ${(ok)__newt_style//#%default} \
            'cyan green yellow black red white'
    fi

    function __newt_preview_show () {
        __newt_assemble_segments left ${(Oa)=__newt[left]}
        __newt_assemble_segments right ${=__newt[right]}
        [[ -o promptcr ]] && print -n $'\r'; :
        print -P "${PS1}$*%-1<<${(l:COLUMNS:: :)}${RPS1}"
    }

    function __newt_preview_style () {
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

    for style in "$@"; do
        __newt_preview_style $=style
    done

    unfunction __newt_preview_show __newt_preview_style
    prompt_newt_cleanup
}


# Help {{{1

function prompt_newt_help () {
    local br='  '  # Markdown line break
    local styles='default, '${(j., .)${(ok)__newt_style//#%default}}

    local pager
    if [[ -t 1 ]]; then
        pager=$PAGER
        [[ -n $pager && -x $pager ]] || pager=$(which less)
        [[ -n $pager && -x $pager ]] || pager=$(which more)
    else
        pager=$(which cat)
    fi

    {
        cat <<EOF
Newt ZSH Theme
==============

>   “She turned me into a newt!”$br
>   “A newt?”$br
>   “… I got better.”$br
EOF

        (( $+PROMPT_NEWT_README )) && cat <<'EOF'

![Newt Theme Demo][demo]

[demo]: https://gist.githubusercontent.com/softmoth/2910577d28970c80b58f8b55c34d58c1/raw/newt-demo.png
EOF

        cat <<EOF

Styles
------

Newt comes with these pre-defined styles:
*${styles}*.
EOF

        cat <<'EOF'

Use a style with `prompt newt meadow`.

Create a `bespoke` style with `prompt newt blue white magenta`, giving
a list of colors. Each color can be

- `''`, meaning the terminal's default background / foreground, or
- *black, red, yellow, green, blue, magenta, cyan, white*, or
- a color number supported by your terminal, or
- a truecolor specification as described in **Truecolor support** below.
EOF

        (( $+PROMPT_NEWT_README )) && cat <<'EOF'

![Newt Theme Preview][preview]

[preview]: https://gist.githubusercontent.com/softmoth/2910577d28970c80b58f8b55c34d58c1/raw/newt-preview.png
EOF

        cat <<'EOF'

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
EOF
    } 2>&1 | "$pager"

    # promptinit doesn't handle cleanup
    [[ $prompt_theme[1] = newt ]] || prompt_newt_cleanup
}


# Main Prompt Setup {{{1

function __newt_debug () { print -r "$(date) $@" >> /tmp/zsh-debug-newt.log 2>&1 }

function prompt_newt_setup () {
    autoload -Uz add-zsh-hook
    autoload -Uz add-zle-hook-widget
    autoload -Uz vcs_info

    typeset -g -A -H __newt=()
    typeset -g -A -H __newt_defaults=()
    PS1=
    RPS1=

    add-zsh-hook precmd __newt_precmd_save_status

    # + Styling {{{1

    local -a colorbgfg

    # Inverse colors for defaults
    colorbgfg=( $(get_terminal_foreground) $(get_terminal_background) )

    typeset -g -A __newt_style
    __newt_style[default]=$colorbgfg
    __newt_style[denver]="'' 202 '' 33 '' 196"
    __newt_style[forest]='22 229 24 229'
    __newt_style[meadow]='149 235 81 235'
    __newt_style[mono]='235 242 238 250 235 197'

    # Env variable can be used in .zshrc, etc.
    export PROMPT_NEWT_STYLE=${(j. .)${(qq)@}}

    if [[ -n $1 && $+__newt_style[$1] > 0 ]]; then
        __newt[style]=$1
        shift
    else
        if [[ $#@ > 1 ]]; then
            __newt[style]=bespoke
        else
            __newt[style]=default
        fi
    fi

    __newt[ctx]=:prompt-theme:newt:$__newt[style]

    function $0-set-colors () {
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

    local -a style=( ${(z)__newt_style[${__newt[style]}]} )
    $0-set-colors "${(Q)style[@]}" "$@"

    unfunction $0-set-colors

    __newt[left]=$(__newt_zstyle -d 'time context notice dir' left)
    __newt[right]=$(__newt_zstyle -d 'vi_mode status exec_time jobs vcs' right)

    __newt_default "$__newt[color-yellow]"  bg vi_mode \*
    __newt_default "$__newt[color1]"        bg \*      \*
    __newt_default "$__newt[color2]"        fg \*      \*
    __newt_default "$__newt[color3]"        bg dir     \*
    __newt_default "$__newt[color4]"        fg dir     \*
    __newt_default "$__newt[color5]"        bg dir     root
    __newt_default "$__newt[color6]"        fg dir     root

    #__newt_default "$__newt[color3]"        bg jobs    \*
    #__newt_default "$__newt[color4]"        fg jobs    \*
    __newt_default "$__newt[color3]"        bg vcs     \*
    __newt_default "$__newt[color4]"        fg vcs     \*
    __newt_default "$__newt[color5]"        bg vcs     clobbered
    __newt_default "$__newt[color6]"        fg vcs     clobbered
    __newt_default "$__newt[color5]"        bg vcs     root
    __newt_default "$__newt[color6]"        fg vcs     root

    #__newt_default "$__newt[color-cyan]"    bg vcs     action
    #__newt_default "$__newt[color-black]"   fg vcs     action
    #__newt_default "$__newt[color-magenta]" bg vcs     dirty
    #__newt_default "$__newt[color-black]"   fg vcs     dirty

    __newt_do_segments setup ${=__newt[left]}
    __newt_do_segments setup ${=__newt[right]}

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

[[ -o kshautoload ]] || prompt_newt_setup "$@"

# vim:set sw=4 et ft=zsh fdm=marker:
