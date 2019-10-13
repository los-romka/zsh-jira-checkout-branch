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

  [ -f "$JIRA_CREDENTIALS_PATH" ] && [ -z "$JIRA_CREDENTIALS" ] && JIRA_CREDENTIALS=$(cat "$JIRA_CREDENTIALS_PATH" | xargs)
  [ -z "$JIRA_CREDENTIALS" ] && echo Put "$JIRA_USER:$JIRA_PASS" into "$JIRA_CREDENTIALS_PATH" && return
  [ -z "$JIRA_API_URL" ] && echo Define \$JIRA_API_URL \(Example: "https://jira.mysite.com/rest/api/2/"\) && return

  git_branches() {
      git --no-pager branch --all \
            --sort=-committerdate \
            --format='%(refname:short)|%(committerdate:relative)|%(authorname)' \
            --color=always \
          | grep -a --color=never -vE "$(git --no-pager branch --format='%(refname:short)' | sed 's/^/origin\//g' | xargs | tr ' ' '|')" \
          | sed '/^$/d'
  }

  jira_issues() {
    local CACHE_FILE="$JIRA_ISSUES_CACHE_PATH"

    [ -f "$CACHE_FILE" ] && find "$CACHE_FILE" -type f -mmin +"$JIRA_ISSUES_CACHE_TTL" -print0 | xargs -0 rm -f
    [ -f "$CACHE_FILE" ] && (( $(du -k "$CACHE_FILE" | cut -f1) > 10 )) && cat "$CACHE_FILE" && return

    local issueKeys maxResults searchUrl issues

    issueKeys=$(git_branches | sed 's/origin\///g' | cut -d"|" -f1 | grep -a --color=never -iE '^[A-Z]+-[0-9]+$' ) || return
    maxResults=$(echo "$issueKeys" | wc -l | xargs -0)

    if [ "$issueKeys" = "" ]; then
      >&2 echo "There aren't git branches associated with JIRA!"
      return
    fi

    searchUrl=$(echo "${JIRA_API_URL}search?fields=summary&maxResults=${maxResults}&jql=issueKey%20in%20($(echo -e $issueKeys | xargs | tr ' ' ','))") || return

    >&2 echo "Requesting JIRA issues"

    issues=$(curl --fail -L -u "$JIRA_CREDENTIALS" "$searchUrl" | jq -r '.issues | map(.key + "|" + .fields.summary) | join("\n")') || return

    echo "$issues" > "$CACHE_FILE"
    cat "$CACHE_FILE"
  }

  jira_branches() {
    local issues branch timeAgo author title branchName

    declare -A issues

    jira_issues | while read issueInfo ; do
        branch=$(echo "$issueInfo" | cut -d"|" -f1)
        issues["$branch"]=$(echo "$issueInfo" | cut -d"|" -f2-)
    done

    git_branches | while read choice ; do
        branch=$(echo "$choice" | cut -d"|" -f1)
        branchName=$(echo "$branch" | sed 's/origin\///g')
        timeAgo=$(echo "$choice" | cut -d"|" -f2)
        author=$(echo "$choice" | cut -d"|" -f3)
        title=${issues["$branchName"]}

        printf "$(tput setaf 3)%-35s%15s$(tput setaf 5)%-25s%15s$(tput setaf 2)%-20s%15s$(tput sgr0)%s\n" \
            "$branch" " " "$author" " " "$timeAgo" " " "$title"
      done
  }

  local target=$(
    jira_branches |
    fzf --no-hscroll --no-multi \
        --preview-window up:10 \
        --no-sort \
        --ansi --preview="git --no-pager log -10 --pretty=format:%s '..{1}'") || return

  git checkout $(awk '{print $1}' <<<"$target" | sed 's/origin\///g' )
}

# Set $?.
true
