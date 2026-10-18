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

# `@DISTRO_ID@ security watch on`: install commands that bypass the package
# manager (a script piped into a shell, npm -g, pip, cargo install, ...) are
# noted in a private log on this computer, never sent anywhere.
set -l __settings (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo $HOME/.config)/@DISTRO_ID@/settings
if grep -qsx 'security.watch = on' $__settings
    function __install_watch --on-event fish_preexec
        if string match -qr -- '(^|[\s;|&(])(curl|wget|npm|pnpm|yarn|bun|pip3?|pipx|uv|cargo|go|gem|make)\s|\.[Aa]pp[Ii]mage' $argv[1]
            @DISTRO_ID@ security noted -- $argv[1] >/dev/null 2>&1 &
            disown 2>/dev/null
        end
    end
end
