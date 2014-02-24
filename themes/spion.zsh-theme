# wunjo prompt theme

#autoload -U zgitinit

##
## Load with `autoload -U zgitinit; zgitinit'
##

typeset -gA zgit_info
zgit_info=()

zgit_chpwd_hook() {
	zgit_info_update
}

zgit_preexec_hook() {
	if [[ $2 == git\ * ]] || [[ $2 == *\ git\ * ]]; then
		zgit_precmd_do_update=1
	fi
}

zgit_precmd_hook() {
	if [ $zgit_precmd_do_update ]; then
		unset zgit_precmd_do_update
		zgit_info_update
	fi
}

zgit_info_update() {
	zgit_info=()

	local gitdir="$(git rev-parse --git-dir 2>/dev/null)"
	if [ $? -ne 0 ] || [ -z "$gitdir" ]; then
		return
	fi

	zgit_info[dir]=$gitdir
	zgit_info[bare]=$(git rev-parse --is-bare-repository)
	zgit_info[inwork]=$(git rev-parse --is-inside-work-tree)
}

zgit_isgit() {
	if [ -z "$zgit_info[dir]" ]; then
		return 1
	else
		return 0
	fi
}

zgit_inworktree() {
	zgit_isgit || return
	if [ "$zgit_info[inwork]" = "true" ]; then
		return 0
	else
		return 1
	fi
}

zgit_isbare() {
	zgit_isgit || return
	if [ "$zgit_info[bare]" = "true" ]; then
		return 0
	else
		return 1
	fi
}

zgit_head() {
	zgit_isgit || return 1

	if [ -z "$zgit_info[head]" ]; then
		local name=''
		name=$(git symbolic-ref -q HEAD)
		if [ $? -eq 0 ]; then
			if [[ $name == refs/(heads|tags)/* ]]; then
				name=${name#refs/(heads|tags)/}
			fi
		else
			name=$(git name-rev --name-only --no-undefined --always HEAD)
			if [ $? -ne 0 ]; then
				return 1
			elif [[ $name == remotes/* ]]; then
				name=${name#remotes/}
			fi
		fi
		zgit_info[head]=$name
	fi

	echo $zgit_info[head]
}

zgit_branch() {
	zgit_isgit || return 1
	zgit_isbare && return 1

	if [ -z "$zgit_info[branch]" ]; then
		local branch=$(git symbolic-ref HEAD 2>/dev/null)
		if [ $? -eq 0 ]; then
			branch=${branch##*/}
		else
			branch=$(git name-rev --name-only --always HEAD)
		fi
		zgit_info[branch]=$branch
	fi

	echo $zgit_info[branch]
	return 0
}

zgit_tracking_remote() {
	zgit_isgit || return 1
	zgit_isbare && return 1

	local branch
	if [ -n "$1" ]; then
		branch=$1
	elif [ -z "$zgit_info[branch]" ]; then
		branch=$(zgit_branch)
		[ $? -ne 0 ] && return 1
	else
		branch=$zgit_info[branch]
	fi

	local k="tracking_$branch"
	local remote
	if [ -z "$zgit_info[$k]" ]; then
		remote=$(git config branch.$branch.remote)
		zgit_info[$k]=$remote
	fi

	echo $zgit_info[$k]
	return 0
}

zgit_tracking_merge() {
	zgit_isgit || return 1
	zgit_isbare && return 1

	local branch
	if [ -z "$zgit_info[branch]" ]; then
		branch=$(zgit_branch)
		[ $? -ne 0 ] && return 1
	else
		branch=$zgit_info[branch]
	fi

	local remote=$(zgit_tracking_remote $branch)
	[ $? -ne 0 ] && return 1
	if [ -n "$remote" ]; then # tracking branch
		local merge=$(git config branch.$branch.merge)
		if [ $remote != "." ]; then
			merge=$remote/$(basename $merge)
		fi
		echo $merge
		return 0
	else
		return 1
	fi
}

zgit_isindexclean() {
	zgit_isgit || return 1
	if git diff --quiet --cached 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

zgit_isworktreeclean() {
	zgit_isgit || return 1
	if [ -z "$(git ls-files $zgit_info[dir]:h --modified)" ]; then
		return 0
	else
		return 1
	fi
}

zgit_hasuntracked() {
	zgit_isgit || return 1
	local -a flist
	flist=($(git ls-files --others --exclude-standard))
	if [ $#flist -gt 0 ]; then
		return 0
	else
		return 1
	fi
}

zgit_hasunmerged() {
	zgit_isgit || return 1
	local -a flist
	flist=($(git ls-files -u))
	if [ $#flist -gt 0 ]; then
		return 0
	else
		return 1
	fi
}

zgit_svnhead() {
	zgit_isgit || return 1

	local commit=$1
	if [ -z "$commit" ]; then
		commit='HEAD'
	fi

	git svn find-rev $commit
}

zgit_rebaseinfo() {
	zgit_isgit || return 1
	if [ -d $zgit_info[dir]/rebase-merge ]; then
		dotest=$zgit_info[dir]/rebase-merge
	elif [ -d $zgit_info[dir]/.dotest-merge ]; then
		dotest=$zgit_info[dir]/.dotest-merge
	elif [ -d .dotest ]; then
		dotest=.dotest
	else
		return 1
	fi

	zgit_info[dotest]=$dotest

	zgit_info[rb_onto]=$(cat "$dotest/onto")
	if [ -f "$dotest/upstream" ]; then
		zgit_info[rb_upstream]=$(cat "$dotest/upstream")
	else
		zgit_info[rb_upstream]=
	fi
	if [ -f "$dotest/orig-head" ]; then
		zgit_info[rb_head]=$(cat "$dotest/orig-head")
	elif [ -f "$dotest/head" ]; then
		zgit_info[rb_head]=$(cat "$dotest/head")
	fi
	zgit_info[rb_head_name]=$(cat "$dotest/head-name")

	return 0
}

add-zsh-hook chpwd zgit_chpwd_hook
add-zsh-hook preexec zgit_preexec_hook
add-zsh-hook precmd zgit_precmd_hook

zgit_info_update

#




#zgitinit

prompt_wunjo_help () {
  cat <<'EOF'

  prompt wunjo

EOF
}

revstring() {
    git describe --tags --always $1 2>/dev/null ||
    git rev-parse --short $1 2>/dev/null
}

coloratom() {
    local off=$1 atom=$2
    if [[ $atom[1] == [[:upper:]] ]]; then
        off=$(( $off + 60 ))
    fi
    echo $(( $off + $colorcode[${(L)atom}] ))
}
colorword() {
    local fg=$1 bg=$2 att=$3
    local -a s

    if [ -n "$fg" ]; then
        s+=$(coloratom 30 $fg)
    fi
    if [ -n "$bg" ]; then
        s+=$(coloratom 40 $bg)
    fi
    if [ -n "$att" ]; then
        s+=$attcode[$att]
    fi

    echo "%{"$'\e['${(j:;:)s}m"%}"
}

prompt_wunjo_setup() {
    local verbose
    if [[ $TERM == screen* ]] && [ -n "$STY" ]; then
        verbose=0 
    else
        verbose=1
    fi

    typeset -A colorcode
    colorcode[black]=0
    colorcode[red]=1
    colorcode[green]=2
    colorcode[yellow]=3
    colorcode[blue]=4
    colorcode[magenta]=5
    colorcode[cyan]=6
    colorcode[white]=7
    colorcode[default]=9
    colorcode[k]=$colorcode[black]
    colorcode[r]=$colorcode[red]
    colorcode[g]=$colorcode[green]
    colorcode[y]=$colorcode[yellow]
    colorcode[b]=$colorcode[blue]
    colorcode[m]=$colorcode[magenta]
    colorcode[c]=$colorcode[cyan]
    colorcode[w]=$colorcode[white]
    colorcode[.]=$colorcode[default]

    typeset -A attcode
    attcode[none]=00
    attcode[bold]=01
    attcode[faint]=02
    attcode[standout]=03
    attcode[underline]=04
    attcode[blink]=05
    attcode[reverse]=07
    attcode[conceal]=08
    attcode[normal]=22
    attcode[no-standout]=23
    attcode[no-underline]=24
    attcode[no-blink]=25
    attcode[no-reverse]=27
    attcode[no-conceal]=28

    local -A pc
    pc[default]='default'
    pc[date]='cyan'
    #pc[time]='Blue'
    pc[time]='blue'
    #pc[host]='Green'
    pc[host]='green'
    pc[user]='cyan'
    #pc[punc]='yellow'
    pc[punc]='Yellow'
    pc[line]='magenta'
    pc[hist]='green'
    #pc[path]='Cyan'
    pc[path]='blue'
    pc[shortpath]='default'
    pc[rc]='red'
    #pc[scm_branch]='Cyan'
    pc[scm_branch]='cyan'
    #pc[scm_commitid]='Yellow'
    pc[scm_commitid]='yellow'
    pc[scm_status_dirty]='Red'
    #pc[scm_status_staged]='Green'
    pc[scm_status_staged]='green'
    #pc[#]='Yellow'
    pc[#]='yellow'
    for cn in ${(k)pc}; do
        pc[${cn}]=$(colorword $pc[$cn])
    done
    pc[reset]=$(colorword . . 00)

    typeset -Ag wunjo_prompt_colors
    wunjo_prompt_colors=(${(kv)pc})

    local p_date p_line p_rc

    p_date="$pc[date]%D{%Y-%m-%d} $pc[time]%D{%T}$pc[reset]"

    p_line="$pc[line]%y$pc[reset]"

   PROMPT=
   #PROMPT+=%{$(echo -n "\a")%}
    if [ $verbose ]; then
        PROMPT+="$pc[user]%n$pc[reset]@$pc[host]%m$pc[reset] "
    fi
    PROMPT+="$pc[path]%(2~.%~.%/)$pc[reset]"
    PROMPT+="\$(prompt_wunjo_scm_status)"
    #PROMPT+="\$(svn_prompt_wunjo)"
    PROMPT+="%(?.. $pc[rc]exited %1v$pc[reset])"
    PROMPT+="
"
    PROMPT+="$pc[hist]%h$pc[reset] "
    #PROMPT+="$pc[shortpath]%1~$pc[reset]"
    #PROMPT+="\$(prompt_wunjo_scm_branch)"
    PROMPT+="$pc[#]%#$pc[reset] "

    RPROMPT=
    if [ $verbose ]; then
        RPROMPT+="$p_date "
    fi
    #RPROMPT+="$pc[user]%n$pc[reset]"
    RPROMPT+=" $p_line"

    RPROMPT=
    export PROMPT RPROMPT
    add-zsh-hook precmd prompt_wunjo_precmd
}

prompt_wunjo_precmd() {
    local ex=$?
    psvar=()

    echo -n "\a"
    if [[ $ex -ge 128 ]]; then
        sig=$signals[$ex-127]
        psvar[1]="sig${(L)sig}"
    else
        psvar[1]="$ex"
    fi
}

svn_prompt_wunjo() {
    local -A pc
    pc=(${(kv)wunjo_prompt_colors})
    local svn_p_wun
    svn_p_wun=
    if [ $(in_svn) ]; then
        ZSH_SVN_INFO_CACHED=$(svn info)
        svn_p_wun+="$pc[reset] on $pc[scm_branch]$(svn_get_repo_root)$pc[reset]"
        svn_p_wun+="/"
        svn_p_wun+="$pc[scm_branch]$(svn_get_repo_name)$pc[reset]"
        svn_p_wun+="$pc[punc]($pc[scm_commitid]$(svn_get_rev_nr)$pc[punc])$pc[reset]"
        ZSH_THEME_REPO_NAME_COLOR="$pc[scm_branch]"
        ZSH_THEME_SVN_PROMPT_DIRTY="$pc[scm_status_dirty]!$pc[reset]"
        ZSH_THEME_SVN_PROMPT_CLEAN=""
        svn_p_wun+="$(svn_dirty)"
        ZSH_SVN_INFO_CACHED=""
    fi
    echo "$svn_p_wun"
}


prompt_wunjo_scm_status() {
    zgit_isgit || return
    local -A pc
    pc=(${(kv)wunjo_prompt_colors})

    head=$(zgit_head)
    gitcommit=$(revstring $head)

    local -a commits

    if zgit_rebaseinfo; then
        orig_commit=$(revstring $zgit_info[rb_head])
        orig_name=$(git name-rev --name-only $zgit_info[rb_head])
        orig="$pc[scm_branch]$orig_name$pc[punc]($pc[scm_commitid]$orig_commit$pc[punc])"
        onto_commit=$(revstring $zgit_info[rb_onto])
        onto_name=$(git name-rev --name-only $zgit_info[rb_onto])
        onto="$pc[scm_branch]$onto_name$pc[punc]($pc[scm_commitid]$onto_commit$pc[punc])"

        if [ -n "$zgit_info[rb_upstream]" ] && [ $zgit_info[rb_upstream] != $zgit_info[rb_onto] ]; then
            upstream_commit=$(revstring $zgit_info[rb_upstream])
            upstream_name=$(git name-rev --name-only $zgit_info[rb_upstream])
            upstream="$pc[scm_branch]$upstream_name$pc[punc]($pc[scm_commitid]$upstream_commit$pc[punc])"
            commits+="rebasing $upstream$pc[reset]..$orig$pc[reset] onto $onto$pc[reset]"
        else
            commits+="rebasing $onto$pc[reset]..$orig$pc[reset]"
        fi

        local -a revs
        revs=($(git rev-list $zgit_info[rb_onto]..HEAD))
        if [ $#revs -gt 0 ]; then
            commits+="\n$#revs commits in"
        fi

        if [ -f $zgit_info[dotest]/message ]; then
            mess=$(head -n1 $zgit_info[dotest]/message)
            commits+="on $mess"
        fi
    elif [ -n "$gitcommit" ]; then
        commits+="on $pc[scm_branch]$head$pc[punc]($pc[scm_commitid]$gitcommit$pc[punc])$pc[reset]"
        local track_merge=$(zgit_tracking_merge)
        if [ -n "$track_merge" ]; then
            if git rev-parse --verify -q $track_merge >/dev/null; then
                local track_remote=$(zgit_tracking_remote)
                local tracked=$(revstring $track_merge 2>/dev/null)

                local -a revs
                revs=($(git rev-list --reverse $track_merge..HEAD))
                if [ $#revs -gt 0 ]; then
                    local base=$(revstring $revs[1]~1)
                    local base_name=$(git name-rev --name-only $base)
                    local base_short=$(revstring $base)
                    local word_commits
                    if [ $#revs -gt 1 ]; then
                        word_commits='commits'
                    else
                        word_commits='commit'
                    fi

                    local conj="since"
                    if [[ "$base" == "$tracked" ]]; then
                        conj+=" tracked"
                        tracked=
                    fi
                    commits+="$#revs $word_commits $conj $pc[scm_branch]$base_name$pc[punc]($pc[scm_commitid]$base_short$pc[punc])$pc[reset]"
                fi

                if [ -n "$tracked" ]; then
                    local track_name=$track_merge
                    if [[ $track_remote == "." ]]; then
                        track_name=${track_name##*/}
                    fi
                    tracked=$(revstring $tracked)
                    commits+="tracking $pc[scm_branch]$track_name$pc[punc]"
                    if [[ "$tracked" != "$gitcommit" ]]; then
                        commits[$#commits]+="($pc[scm_commitid]$tracked$pc[punc])"
                    fi
                    commits[$#commits]+="$pc[reset]"
                fi
            fi
        fi
    fi

    gitsvn=$(git rev-parse --verify -q --short git-svn)
    if [ $? -eq 0 ]; then
        gitsvnrev=$(zgit_svnhead $gitsvn)
        gitsvn=$(revstring $gitsvn)
        if [ -n "$gitsvnrev" ]; then
            local svninfo=''
            local -a revs
            svninfo+="$pc[default]svn$pc[punc]:$pc[scm_branch]r$gitsvnrev"
            revs=($(git rev-list git-svn..HEAD))
            if [ $#revs -gt 0 ]; then
                svninfo+="$pc[punc]@$pc[default]HEAD~$#revs"
                svninfo+="$pc[punc]($pc[scm_commitid]$gitsvn$pc[punc])"
            fi
            commits+=$svninfo
        fi
    fi

    if [ $#commits -gt 0 ]; then
        echo -n " ${(j: :)commits}"
    fi
}

prompt_wunjo_scm_branch() {
    zgit_isgit || return
    local -A pc
    pc=(${(kv)wunjo_prompt_colors})

    echo -n "$pc[punc]:$pc[scm_branch]$(zgit_head)"

    if zgit_inworktree; then
        if ! zgit_isindexclean; then
            echo -n "$pc[scm_status_staged]+"
        fi

        local -a dirty
        if ! zgit_isworktreeclean; then
            dirty+='!'
        fi

        if zgit_hasunmerged; then
            dirty+='*'
        fi

        if zgit_hasuntracked; then
            dirty+='?'
        fi

        if [ $#dirty -gt 0 ]; then
            echo -n "$pc[scm_status_dirty]${(j::)dirty}"
        fi
    fi

    echo $pc[reset]
}

prompt_wunjo_setup "$@"

# vim:set ft=zsh:

