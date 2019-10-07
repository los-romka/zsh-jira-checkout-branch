# zsh-jira-checkout-branch
> Zsh plugin for easy navigation between git branches associated with JIRA issues

This is written as a zsh plugin, it also works with bash if you follow the [manual installation instructions](#manually).

## Installation

### As an [Oh My ZSH!](https://github.com/robbyrussell/oh-my-zsh) custom plugin

Clone `zsh-jira-checkout-branch` into your custom plugins repo

```shell
git clone https://github.com/los-romka/zsh-jira-checkout-branch ~/.oh-my-zsh/custom/plugins/zsh-jira-checkout-branch
```
Then load as a plugin in your `.zshrc`

```shell
plugins+=(zsh-jira-checkout-branch)
```

Keep in mind that plugins need to be added before `oh-my-zsh.sh` is sourced.

Then [define required JIRA variables](#Required)

### Manually
Clone this repository somewhere (`~/.zsh-jira-checkout-branch` for example)

```shell
git clone https://github.com/los-romka/zsh-jira-checkout-branch.git ~/.zsh-jira-checkout-branch
```
Then source it in your `.zshrc` (or `.bashrc`)

```shell
source ~/.zsh-jira-checkout-branch/zsh-jira-checkout-branch.plugin.zsh
```

Then [define required JIRA variables](#Required)

### Required

Put `$JIRA_USER:$JIRA_PASS` into `~/.jira-credentials`

```shell
echo "user:pass" > ~/.jira-credentials
```

Define `JIRA_API_URL` in your `.zshrc` (or `.bashrc`)

```shell
echo -e "JIRA_API_URL=https://jira.mysite.com/rest/api/2/" >> ~/.zshrc
```

## Usage

Type `jco` in your Git-repository to checkout between branches

## Options

### Custom Directory

You can specify a custom `JIRA_CREDENTIALS_PATH` in your `.zshrc` (or `.bashrc`)

```shell
echo -e "JIRA_CREDENTIALS_PATH=~/.jira-credentials" >> ~/.zshrc
```

## Dependencies

- [`JIRA-server`](https://www.atlassian.com/software/jira) - The #1 software development tool used by agile teams
- [`git`](https://www.git-scm.com/) - U know it
- [`fzf`](https://github.com/junegunn/fzf) - General-purpose command-line fuzzy finder.
- [`curl`](https://curl.haxx.se/) - Command line tool and library for transferring data with URLs
- [`jq`](https://stedolan.github.io/jq/) - Command-line JSON processor

## License

MIT © Roman Los
