# Distro shell defaults for fish: prompt, smarter cd, ls and search.
# Linked into ~/.config/fish/conf.d by `@DISTRO_ID@ shell set fish`.
status is-interactive; or return

if type -q eza
    alias ls 'eza --group-directories-first'
    alias ll 'eza -l --git --group-directories-first'
    alias la 'eza -la --git --group-directories-first'
    alias lt 'eza --tree --level=2 --group-directories-first'
end
if type -q fzf
    set -gx FZF_DEFAULT_OPTS "--color=16 --height=40% --layout=reverse --border"
    if type -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
        set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
    end
    fzf --fish | source
end
set -gx BAT_THEME ansi
type -q zoxide; and zoxide init fish | source
type -q mise; and mise activate fish | source
type -q starship; and starship init fish | source
