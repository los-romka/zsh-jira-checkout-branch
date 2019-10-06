jco() {
  # global JIRA_API_URL
  # global JIRA_CREDENTIALS_PATH

  JIRA_CREDENTIALS_PATH=${JIRA_CREDENTIALS_PATH:-~/.jira-credentials}

  [ "$(git symbolic-ref --short HEAD)" ] || return

  local GIT_REPOSITORY_HASH=$(git remote -v | shasum -p | cut -d' ' -f1)

  local JIRA_ISSUES_CACHE_PATH=/tmp/.jira_issues.$GIT_REPOSITORY_HASH.cache
  local JIRA_ISSUES_CACHE_TTL=60
  local JIRA_BRANCHES_CACHE_PATH=/tmp/.jira_branches.$GIT_REPOSITORY_HASH.cache
  local JIRA_BRANCHES_CACHE_TTL=60
  local JIRA_CREDENTIALS

  [ -f "$JIRA_CREDENTIALS_PATH" ] && [ -z $JIRA_CREDENTIALS ] && JIRA_CREDENTIALS=$(cat "$JIRA_CREDENTIALS_PATH" | xargs)
  [ -z $JIRA_CREDENTIALS ] && echo 'Put "$JIRA_USER:$JIRA_PASS" into '$JIRA_CREDENTIALS_PATH && return
  [ -z $JIRA_API_URL ] && echo 'Define $JIRA_API_URL (Example: "https://jira.mysite.com/rest/api/2/")' && return

  git_branches() {
    local branches=$(
      git --no-pager branch --all \
            --sort=-committerdate \
            --format='%(refname:short)|%(committerdate:relative)|%(authorname)' \
            --color=always \
          | grep --color=never -vE "$(git --no-pager branch --format='%(refname:short)' | sed 's/^/origin\//g' | xargs | tr ' ' '|')" \
          | sed '/^$/d'
    )
    echo "$branches"
  }

  jira_issues() {
    local CACHE_FILE="$JIRA_ISSUES_CACHE_PATH"

    [ -f "$CACHE_FILE" ] && find "$CACHE_FILE" -type f -mmin +"$JIRA_ISSUES_CACHE_TTL" -print0 | xargs -0 rm -f
    [ -f "$CACHE_FILE" ] && (( $(du -k "$CACHE_FILE" | cut -f1) > 10 )) && cat "$CACHE_FILE" && return

    local issueKeys=$(git_branches | sed 's/origin\///g' | cut -d"|" -f1 | grep --color=never -iE '^[A-Z]+-[0-9]+$' ) || return
    local maxResults=$(echo $issueKeys | wc -l | xargs)

    if [ "$issueKeys" = "" ]; then
      >&2 echo "There aren't git branches associated with JIRA!"
      return
    fi

    local searchUrl=$(echo "${JIRA_API_URL}search?fields=summary&maxResults=${maxResults}&jql=issueKey%20in%20($(echo -e $issueKeys | xargs | tr ' ' ','))") || return

    >&2 echo "Requesting JIRA issues: $searchUrl"

    local issues=$(curl --fail -L -u "$JIRA_CREDENTIALS" "$searchUrl" | jq -r '.issues | map(.key + "|" + .fields.summary) | join("\n")') || return

    echo "$issues" > "$CACHE_FILE"
    cat "$CACHE_FILE"
  }

  jira_branches() {
    local CACHE_FILE="$JIRA_BRANCHES_CACHE_PATH"

    [ -f "$CACHE_FILE" ] && find "$CACHE_FILE" -type f -mmin +"$JIRA_BRANCHES_CACHE_TTL" -print0 | xargs -0 rm -f
    [ -f "$CACHE_FILE" ] && (( $(du -k "$CACHE_FILE" | cut -f1) > 10 )) && cat "$CACHE_FILE" && return

    local branches=$(git_branches) || return
    local issues=$(jira_issues) || return

    (( $(echo "$branches" | wc -c) < 2 )) && return
    (( $(echo "$issues" | wc -c) < 2 )) && return

    local choices=$(
      echo "$branches" | while read branchInfo ; do
        local branch=$(echo $branchInfo | cut -d"|" -f1)
        local issueInfo=$(echo $issues | grep --color=never -iE $(echo "^$branch" | sed 's/origin\///g' ) )

        if [ "$issueInfo" != '' ]; then
          local title=$(echo $issueInfo | cut -d"|" -f2-)
          echo "$branchInfo|$title"
        fi
      done 
    ) || return

    (( $(echo "$choices" | wc -c) < 2 )) && return

    local branches=$(
      echo "$choices" | while read choice ; do
        local branch=$(echo $choice | cut -d"|" -f1)
        local timeAgo=$(echo $choice | cut -d"|" -f2)
        local author=$(echo $choice | cut -d"|" -f3)
        local title=$(echo $choice | cut -d"|" -f4)

        echo "$(tput setaf 3)$branch|$(tput setaf 5)$author|$(tput setaf 2)$timeAgo|$(tput sgr0)$title"
      done | column -ts'|'
    ) || return

    echo "$branches" > "$CACHE_FILE"
    cat "$CACHE_FILE"
  }

  local branches=$(jira_branches) || return

  [ "$branches" = "" ] && return

  local target=$(
    (echo "$branches";) |
    fzf --no-hscroll --no-multi \
        --preview-window up:10 \
        --ansi --preview="git --no-pager log -10 --pretty=format:%s '..{1}'") || return

  git checkout $(awk '{print $1}' <<<"$target" | sed 's/origin\///g' )
}

# Set $?.
true
