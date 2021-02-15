_zsh_jira_checkout_branch_init() {
    # global JIRA_API_URL
    # global JIRA_CREDENTIALS_PATH

    local ERROR_CODE=127
    local GIT_REPOSITORY_HASH

    JIRA_CREDENTIALS_PATH=${JIRA_CREDENTIALS_PATH:-~/.jira-credentials}

    [ "$(git symbolic-ref --short HEAD)" ] || return $ERROR_CODE

    GIT_REPOSITORY_HASH=$(git remote -v | (shasum -p 2>/dev/null || shasum) | cut -d' ' -f1)

    _JIRA_ISSUES_CACHE_PATH=/tmp/.jira_issues.$GIT_REPOSITORY_HASH.cache
    _JIRA_ISSUES_CACHE_TTL=60

    [ -f "$JIRA_CREDENTIALS_PATH" ] && [ -z "$_JIRA_CREDENTIALS" ] && _JIRA_CREDENTIALS=$(cat "$JIRA_CREDENTIALS_PATH" | xargs)
    [ -z "$_JIRA_CREDENTIALS" ] && echo Put "$JIRA_USER:$JIRA_PASS" into "$JIRA_CREDENTIALS_PATH" && return $ERROR_CODE
    [ -z "$JIRA_API_URL" ] && echo Define \$JIRA_API_URL \(Example: "https://jira.mysite.com/rest/api/2/"\) && return $ERROR_CODE

    return 0
}

_zsh_jira_checkout_branch_git_all_branches() {
    git --no-pager branch --all \
          --sort=-committerdate \
          --format='%(refname:short)|%(committerdate:relative)|%(authorname)' \
          --color=always \
        | grep -a --color=never -vE "$(git --no-pager branch --format='%(refname:short)' | sed 's/^/origin\//g' | xargs | tr ' ' '|')" \
        | sed '/^$/d'
}

_zsh_jira_checkout_branch_jira_issues() {
    local CACHE_FILE="$_JIRA_ISSUES_CACHE_PATH"

    [ -f "$CACHE_FILE" ] && find "$CACHE_FILE" -type f -mmin +"$_JIRA_ISSUES_CACHE_TTL" -print0 | xargs -0 rm -f
    [ -f "$CACHE_FILE" ] && (( $(du -k "$CACHE_FILE" | cut -f1) > 3 )) && cat "$CACHE_FILE" && return

    local issueKeys maxResults searchUrl issues

    issueKeys=$(_zsh_jira_checkout_branch_git_all_branches | sed 's/origin\///g' | cut -d"|" -f1 | grep -a --color=never -iE '^[A-Z]+-[0-9]+$' ) || return
    maxResults=$(echo "$issueKeys" | wc -l | xargs)

    if [ "$issueKeys" = "" ]; then
      >&2 echo "There aren't git branches associated with JIRA!"
      return
    fi

    searchUrl=$(echo "${JIRA_API_URL}search?fields=summary&maxResults=${maxResults}&jql=issueKey%20in%20($(echo -e $issueKeys | xargs | tr ' ' ','))") || return

    >&2 echo "Requesting JIRA issues"

    curl --fail -L -u "$_JIRA_CREDENTIALS" "$searchUrl" | jq -r '.issues | map(.key + "|" + .fields.summary) | join("\n")' > "$CACHE_FILE" || return

    [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
}

_zsh_jira_checkout_branch_add_jira_titles() {
    local issues branch timeAgo author title branchName

    declare -A issues

    _zsh_jira_checkout_branch_jira_issues | while read issueInfo ; do
        branch=$(echo "$issueInfo" | cut -d"|" -f1)
        issues["$branch"]=$(echo "$issueInfo" | cut -d"|" -f2-)
    done

    while read choice; do
        branch=$(echo "$choice" | cut -d"|" -f1)
        branchName=$(echo "$branch" | sed 's/origin\///g')
        timeAgo=$(echo "$choice" | cut -d"|" -f2)
        author=$(echo "$choice" | cut -d"|" -f3)
        title=${issues["$branchName"]}

        printf "$(tput setaf 3)%-35s $(tput setaf 5)%-25s $(tput setaf 2)%-20s $(tput sgr0)%s\n" \
            "$branch" "$author" "$timeAgo" "$title"
    done
}

_zsh_jira_checkout_branch_add_jira_titles_only() {
    local issues branch timeAgo author title branchName

    declare -A issues

    _zsh_jira_checkout_branch_jira_issues | while read issueInfo ; do
        branch=$(echo "$issueInfo" | cut -d"|" -f1)
        issues["$branch"]=$(echo "$issueInfo" | cut -d"|" -f2-)
    done

    while read choice; do
        branch=$(echo "$choice" | cut -d"|" -f1)
        branchName=$(echo "$branch" | sed 's/origin\///g')
        title=${issues["$branchName"]}

        printf "$(tput setaf 3)%s $(tput sgr0)%s\n" \
            "$branch" "$title"
    done
}

jco() {
  local _JIRA_ISSUES_CACHE_PATH
  local _JIRA_ISSUES_CACHE_TTL
  local _JIRA_CREDENTIALS

  _zsh_jira_checkout_branch_init || return

  local target=$(
    _zsh_jira_checkout_branch_git_all_branches | _zsh_jira_checkout_branch_add_jira_titles |
    fzf --no-hscroll --no-multi \
        --preview-window up:10 \
        --no-sort \
        --ansi --preview="git --no-pager log -10 --pretty=format:%s '..{1}'") || return

  git checkout $(awk '{print $1}' <<<"$target" | sed 's/origin\///g' )
}

jb() {
  local _JIRA_ISSUES_CACHE_PATH
  local _JIRA_ISSUES_CACHE_TTL
  local _JIRA_CREDENTIALS

  _zsh_jira_checkout_branch_init || return

  git --no-pager branch \
    --sort=-committerdate \
    --format='%(refname:short)|%(committerdate:relative)|%(authorname)' \
    --color=always \
  | grep -vE '(master|develop)' \
  | grep -a --color=never -vE "$(git --no-pager branch --format='%(refname:short)' | sed 's/^/origin\//g' | xargs | tr ' ' '|')" \
  | sed '/^$/d' | _zsh_jira_checkout_branch_add_jira_titles_only
}

# Set $?.
true
